# Settings & Profile Feedback

## 当前设计决策

- Settings 是全局入口，放在主界面右上角。
- Profile 不作为主导航一级入口。
- Profile 入口放在 Settings 内部。
- 当前仍为本地模式（本地优先），可连接本机开发后端进行开发登录与设备注册。
- 不提供真实微信登录或跨端同步。
- 后续移动端与 PC 端互联需要 Auth / Cloud Sync 支持。

## 模板

- 问题：
- 触发场景：
- 原因分析：
- 短期方案：
- 长期方案：
- 状态：

## 当前记录

### 账号互联需求

- 问题：用户希望移动端和 PC 端未来可以通过账号互联，共享数据。
- 触发场景：Android APK 构建成功后，用户开始考虑跨端使用。
- 原因分析：当前所有端都是本地 SQLite 独立数据库，没有账号体系和云同步。
- 短期方案：Settings / Profile 保持本地优先，并提供隔离的开发登录、后端检查和设备注册入口。
- 长期方案：后续设计 Auth、Cloud Sync、Conflict Resolution、Device Management 和跨端同步。
- 状态：Sprint 6C 已连接 Flutter 开发账号与设备注册；业务同步仍未启用。
