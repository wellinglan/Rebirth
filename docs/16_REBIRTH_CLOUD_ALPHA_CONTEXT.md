# Rebirth Cloud Alpha Server Context

> 目的：让 Codex 在后续开发中准确理解当前 Rebirth 的实际运行环境、部署边界和发布流程。
>
> 当前状态：北京云端 Alpha 调试环境已接入 Windows 与 Android；Sprint 9B.2 功能复测已通过，最终文档门禁仅等待 Phone model 与 Android version 补录。
>
> 下一阶段：补齐 Sprint 9B.2 真机元数据后关闭 Release Gate；Sprint 9C 尚未开始。

## 1. 当前主架构

Rebirth 当前已经不再以本地 FastAPI Server 作为主要跨设备调试后端。

```text
Windows Rebirth ─┐
                  │ Tailscale 私有网络
Android Rebirth ─┤ 私有 HTTPS
                  ▼
https://rebirth-alpha-bj.taila61d27.ts.net
                  │
                  ▼
Tailscale Serve
                  │
                  ▼
127.0.0.1:8000
                  │
                  ▼
Docker: FastAPI / Uvicorn
                  │
                  ▼
Docker: PostgreSQL 17
```

Windows 与 Android 均已完成：

- `/health` 访问
- 云端 Endpoint 保存
- Development 登录
- AI Capabilities 获取

## 2. 云服务器信息

```text
云厂商：腾讯云
地域：中国大陆 · 北京
系统：Ubuntu 24.04 LTS
主机名：rebirth-alpha-bj
用途：Rebirth Cloud Alpha Debug Server
```

约束：

- 不在代码、日志或文档中写入公网 IP。
- 日常连接优先使用 Tailscale 主机名或私有 Endpoint。
- 当前 Rebirth API 不向公网开放。

## 3. 网络边界

当前使用 Tailscale 私网。

私有 HTTPS Endpoint：

```text
https://rebirth-alpha-bj.taila61d27.ts.net
```

代理关系：

```text
Tailscale Serve
→ http://127.0.0.1:8000
```

当前网络规则：

- FastAPI 仅绑定 `127.0.0.1:8000`
- PostgreSQL 不发布宿主机 `5432`
- 不开放公网 `8000`
- 不开放公网 `5432`
- 不使用 Tailscale Funnel
- 仅 Tailnet 内授权设备可访问

Windows 上开启其他梯子/VPN时，可能导致 Tailscale 无法直连并回退 DERP，造成高延迟。进行 Rebirth 调试时，应优先关闭会接管系统路由或 UDP 的其他 VPN。

## 4. Docker 与镜像供应链

北京服务器已安装 Docker Engine 与 Docker Compose v2。

北京服务器不能稳定访问 Docker Hub，因此不在服务器端直接从 Docker Hub 获取基础镜像。

当前镜像链路：

```text
GitHub Actions
→ 从 Docker Hub 获取基础镜像
→ 构建 Rebirth API
→ 同步 PostgreSQL 镜像
→ 推送到 GHCR

北京服务器
→ 仅从 GHCR 拉取镜像
→ Docker Compose 运行
```

当前镜像：

```text
ghcr.io/wellinglan/rebirth-api:alpha-latest
ghcr.io/wellinglan/rebirth-postgres:17-alpine
```

API 还发布：

```text
ghcr.io/wellinglan/rebirth-api:<full-commit-sha>
ghcr.io/wellinglan/rebirth-api:<short-commit-sha>
```

相关工作流：

```text
.github/workflows/publish-alpha-images.yml
```

Windows 本机不需要安装 Docker，也不参与镜像构建。

## 5. 当前 Server 模式

云端仍为开发环境：

```text
REBIRTH_ENV=development
REBIRTH_AI_PROVIDER=fake
REBIRTH_AI_FAKE_SCENARIO=success
```

原因：

- 当前 Alpha 仍需要 `/auth/dev-login`
- 需要 Fake Success / Fake Timeout
- 不应产生真实 OpenAI 费用
- 当前部署不是 Production

不得把当前 Development Server 直接暴露公网。

## 6. Secret 管理

服务器 Secret 文件：

```text
/opt/rebirth/secrets/rebirth-alpha.env
```

包含：

- PostgreSQL 密码
- JWT Secret
- AI Provider 配置
- Token 生命周期
- AI Ledger 保留策略

必须遵守：

- 不提交 Git
- 不复制到 Flutter
- 不输出到日志
- 不完整打印
- 不粘贴到 issue、聊天或截图
- 不使用会展开并打印全部 Secret 的命令输出

检查 Compose 语法时使用：

```bash
docker compose \
  --env-file /opt/rebirth/secrets/rebirth-alpha.env \
  -f /opt/rebirth/deploy/docker-compose.alpha.yml \
  config --quiet
```

## 7. Docker Compose

部署文件：

```text
/opt/rebirth/deploy/docker-compose.alpha.yml
```

服务：

```text
postgres
api
```

关键约束：

```yaml
api:
  ports:
    - "127.0.0.1:8000:8000"

postgres:
  # 不允许发布 ports
```

PostgreSQL 使用 Docker named volume 持久化。

禁止在正常开发和清理流程中执行：

```bash
docker compose down --volumes
```

该命令会删除 PostgreSQL 数据卷。

## 8. Alembic 与启动

API 容器启动时执行：

```text
alembic upgrade head
```

之后启动：

```text
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 2
```

因此：

- 新镜像包含 migration 时，容器启动会自动迁移
- migration 失败时，API 容器应启动失败
- 不允许跳过 migration 后强行启动 API

当前 `/health` 已验证：

```json
{
  "status": "ok",
  "service": "rebirth-api",
  "api_version": 1,
  "sync_protocol_version": 2,
  "environment": "development"
}
```

## 9. 日常发布流程

```text
Codex 修改代码
→ 本地测试
→ Git commit
→ Git push
→ GitHub Quality Workflow
→ Publish Alpha Images Workflow
→ GHCR 发布新镜像
→ 北京服务器 pull
→ 重建 API 容器
→ 验证 /health
```

服务器更新 API：

```bash
docker compose \
  --env-file /opt/rebirth/secrets/rebirth-alpha.env \
  -f /opt/rebirth/deploy/docker-compose.alpha.yml \
  pull api

docker compose \
  --env-file /opt/rebirth/secrets/rebirth-alpha.env \
  -f /opt/rebirth/deploy/docker-compose.alpha.yml \
  up -d --no-deps --force-recreate api
```

验证：

```bash
docker compose \
  --env-file /opt/rebirth/secrets/rebirth-alpha.env \
  -f /opt/rebirth/deploy/docker-compose.alpha.yml \
  ps

curl -s http://127.0.0.1:8000/health
```

## 10. 数据库备份

重大部署或 migration 前：

```bash
docker compose \
  --env-file /opt/rebirth/secrets/rebirth-alpha.env \
  -f /opt/rebirth/deploy/docker-compose.alpha.yml \
  exec -T postgres \
  pg_dump -U rebirth rebirth \
  | gzip > /opt/rebirth/backups/rebirth-before-update-$(date +%F-%H%M%S).sql.gz
```

不要把 named volume 当作备份。

## 11. 客户端 Endpoint

Flutter Endpoint 优先级：

1. Settings 保存的运行时 Endpoint
2. `--dart-define=REBIRTH_API_BASE_URL=...`
3. 默认本地地址

Windows 和 Android 当前均已保存：

```text
https://rebirth-alpha-bj.taila61d27.ts.net
```

后续不得硬编码云端 Endpoint，必须复用现有 Endpoint 配置机制。

## 12. 本地 Server 的角色

本地 Server 仍保留，用于：

- pytest
- SQLite 快速测试
- 本地断点调试
- migration 验证
- 云端故障排查
- 离线开发

正确定位：

```text
本地 Server：快速开发与自动测试
云端 Server：跨设备集成、长期在线、人工验收
```

不要删除本地 SQLite / FastAPI 开发能力。

## 13. 当前项目状态

已完成：

- 北京云服务器创建
- Ubuntu 与 Docker 安装
- GitHub Actions 构建并发布 GHCR 镜像
- PostgreSQL 容器部署
- FastAPI 容器部署
- Alembic migration
- `/health` 验证
- Tailscale Serve 私有 HTTPS
- Windows 云端 Endpoint 接入
- Android 云端 Endpoint 接入
- Windows / Android Development 登录
- Windows / Android AI Capabilities 验证
- Sprint 9B.1 Windows 人工矩阵：`25 PASS / 0 FAIL / 0 NOT EXECUTED`
- Sprint 9B.1 Android 人工矩阵：`14 PASS / 0 FAIL / 0 NOT EXECUTED`
- `DAILY-DETAIL-SOURCE-NAV-001` 已完成 Windows 与 Android 人工复测并标记为 `CLOSED`
- Sprint 9B.2 Flutter 代码、Plan 测试、完整 analyze/test、Windows release 与 Android split release 构建已通过
- Sprint 9B.2 Windows Plan smoke：`PASS`
- Sprint 9B.2 Android Item 12、13、14 真机复测：`PASS`
- `PLAN-ANDROID-LARGE-TEXT-FILTER-LAYOUT-001`：`CLOSED`
- APK ABI：`arm64-v8a`，使用重建的 `app-arm64-v8a-release.apk`

尚未正式完成：

- Phone model 补录
- Android version 补录
- Sprint 9B.1 最终文档 Release Gate：在上述两项补齐前保持 `BLOCKED`
- Sprint 9C：尚未开始

下一开发目标：

```text
补录 Sprint 9B.2 Phone model 与 Android version
```

Sprint 9B.2 功能复测和缺陷关闭已经完成。只有补齐 Phone model 与 Android version 并正式解除文档门禁后，才允许进入 Sprint 9C。

## 14. Sprint 9C 方向（尚未开始）

```text
Completed Daily Insight
→ 重新计算当前源数据 Hash
→ 与报告 inputHash 比较
→ 标记 Current / Stale
→ 数据变化时显示明确提示
→ 用户主动重新 Preview
→ 用户主动确认重新生成
```

Sprint 9C 不应自动：

- 后台生成
- 自动重新生成
- 自动产生 OpenAI 费用
- 自动修改 Plan
- 定时生成
- 扩展 Growth / Goals
- 引入聊天式 AI

## 15. 对 Codex 的强制要求

涉及 Server、部署、migration、API 或测试时：

1. 将云端 PostgreSQL 视为主要集成环境之一。
2. 不把 SQLite 专有行为当作唯一真实环境。
3. 保持 SQLite 与 PostgreSQL 兼容。
4. migration 必须通过 Alembic。
5. 不自动删除数据库或 volume。
6. 不硬编码 Endpoint、Token、密码或公网 IP。
7. 不把 Development/Fake 描述为 Production。
8. 不把工作流存在等同于实际 PASS。
9. 不把自动化测试通过等同于人工矩阵通过。
10. 部署变更必须说明是否需要：
    - 发布新镜像
    - 执行 migration
    - 重建 API
    - 重建 PostgreSQL
    - 备份数据库
    - 更新客户端 Endpoint
11. 默认只更新 API，不无故重建 PostgreSQL。
12. 不要求 Windows 安装 Docker。
13. 不恢复服务器从 Docker Hub 直接拉取基础镜像的旧路线。
14. 镜像供应链继续使用 GitHub Actions + GHCR。
15. 避免任何可能完整输出 Secret 的命令。

## 16. 禁止误判

以下说法均错误：

```text
“项目仍主要使用本地 FastAPI”
“Windows 需要 Docker Desktop”
“北京服务器从 Docker Hub 构建镜像”
“FastAPI 对公网开放 8000”
“PostgreSQL 对公网开放 5432”
“当前环境是 Production”
“当前已启用真实 OpenAI”
“Sprint 9B.1 Release Gate 已经通过”
“Sprint 9B.2 Phone model 与 Android version 已经完成补录”
```

正确理解：

```text
云端 Server 已成为 Windows / Android 的主要 Alpha 集成后端，
本地 Server 仍作为开发与测试后端保留；
Sprint 9B.2 功能复测已通过，当前只剩真机元数据补录与正式门禁关闭，
Sprint 9C 尚未开始。
```
