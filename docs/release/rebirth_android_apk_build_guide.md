# Rebirth Android APK 构建说明

> 适用项目：Rebirth  
> 适用平台：Windows 开发机  
> 目标产物：Android Release APK  
> 推荐命令：`flutter build apk --release --split-per-abi`

---

## 1. 构建前提

在构建 Android APK 前，请确认当前机器已经具备：

- Flutter SDK 已安装
- Android Studio 已安装
- Android SDK 已安装
- Android NDK 已安装
- JDK 可用
- Rebirth 项目依赖已拉取
- 当前仓库位于英文路径，例如：

```powershell
E:\Projects\Rebirth
```

不建议在包含中文、空格或特殊字符的路径下构建 Android Release 包。

---

## 2. 推荐目录

项目目录：

```powershell
E:\Projects\Rebirth
```

Android 子目录：

```powershell
E:\Projects\Rebirth\android
```

APK 输出目录：

```powershell
E:\Projects\Rebirth\build\app\outputs\flutter-apk\
```

---

## 3. 确认 Java / JDK

当前机器推荐使用 Android Studio 自带 JBR。

本项目当前可用路径示例：

```powershell
D:\Android Studio\jbr
```

每次新开 PowerShell 后，如需手动指定 Java，可执行：

```powershell
$env:JAVA_HOME="D:\Android Studio\jbr"
$env:Path="$env:JAVA_HOME\bin;$env:Path"

java -version
```

如果 `java -version` 正常输出 OpenJDK 版本，说明 Java 可用。

也可以通过 Flutter 查看 Java 路径：

```powershell
flutter doctor -v | Select-String -Pattern "Java binary|Java version|Android Studio"
```

---

## 4. 确认 Flutter 环境

在项目根目录执行：

```powershell
cd E:\Projects\Rebirth

flutter doctor -v
flutter devices
```

至少需要确认：

- Flutter 正常
- Android toolchain 正常
- Android SDK 正常
- Java 可用

---

## 5. 首次构建前准备

在项目根目录执行：

```powershell
cd E:\Projects\Rebirth

flutter clean
flutter pub get
flutter analyze
flutter test
```

建议只有在：

```text
flutter analyze
flutter test
```

均通过后，再构建 release APK。

---

## 6. 推荐构建命令

推荐使用 `split-per-abi`，生成不同 CPU 架构的 APK：

```powershell
cd E:\Projects\Rebirth

flutter build apk --release --split-per-abi
```

成功后一般会生成：

```text
build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk
build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
build\app\outputs\flutter-apk\app-x86_64-release.apk
```

其中现代 Android 手机通常安装：

```text
app-arm64-v8a-release.apk
```

完整路径：

```powershell
E:\Projects\Rebirth\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

---

## 7. 生成详细日志

如果构建失败，建议使用 `-v` 并保存完整日志：

```powershell
cd E:\Projects\Rebirth

flutter build apk --release --split-per-abi -v 2>&1 | Tee-Object -FilePath .\build-apk-verbose.log
```

查看最后 120 行：

```powershell
Get-Content .\build-apk-verbose.log -Tail 120
```

---

## 8. 代理设置

构建过程中可能需要访问：

- pub.dev
- GitHub Release
- Android SDK / NDK 下载源

如果需要使用 FLClash 或本地代理，先确认端口可用：

```powershell
Test-NetConnection 127.0.0.1 -Port 7890
```

如果返回：

```text
TcpTestSucceeded : True
```

则可以设置代理：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:7890"
$env:HTTPS_PROXY="http://127.0.0.1:7890"
```

测试 GitHub：

```powershell
curl.exe -x http://127.0.0.1:7890 -I https://github.com
```

如果关闭代理软件，则应清理环境变量：

```powershell
Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:all_proxy -ErrorAction SilentlyContinue

Get-ChildItem Env:*proxy*
```

如果最后一行没有输出，说明当前 PowerShell 没有代理环境变量。

---

## 9. 常见问题：Gradle 锁占用

如果出现类似：

```text
Timeout waiting to lock build logic queue.
Lock file: E:\Projects\Rebirth\android\.gradle\noVersion\buildLogic.lock
```

说明有 Gradle / Java 进程占用锁。

处理：

```powershell
tasklist | findstr /i "java gradle dart flutter"
```

根据 PID 结束占用进程：

```powershell
taskkill /PID <PID> /F
```

然后清理缓存：

```powershell
cd E:\Projects\Rebirth\android
.\gradlew --stop

cd E:\Projects\Rebirth
Remove-Item -Recurse -Force .\android\.gradle -ErrorAction SilentlyContinue
```

再重新构建：

```powershell
flutter build apk --release --split-per-abi
```

---

## 10. 常见问题：JAVA_HOME 无效

如果出现：

```text
ERROR: JAVA_HOME is set to an invalid directory
```

说明当前 `JAVA_HOME` 指向了不存在的路径。

重新指定：

```powershell
$env:JAVA_HOME="D:\Android Studio\jbr"
$env:Path="$env:JAVA_HOME\bin;$env:Path"

java -version
```

如果仍失败，查看 Flutter 识别到的 Java：

```powershell
flutter doctor -v | Select-String -Pattern "Java binary|Java version|Android Studio"
```

---

## 11. 常见问题：NDK 下载损坏

如果出现类似：

```text
Archive is not a ZIP archive
Failed to install ndk;28.2.13676358
```

通常是 NDK 下载中断或代理导致安装包损坏。

处理：

```powershell
cd E:\Projects\Rebirth\android
.\gradlew --stop
```

清理损坏 NDK：

```powershell
$Sdk="$env:LOCALAPPDATA\Android\Sdk"

Remove-Item -Recurse -Force "$Sdk\ndk\28.2.13676358" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$Sdk\.temp" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$Sdk\temp" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "E:\Projects\Rebirth\android\.gradle" -ErrorAction SilentlyContinue
```

重新安装 NDK：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:7890"
$env:HTTPS_PROXY="http://127.0.0.1:7890"

$Sdk="$env:LOCALAPPDATA\Android\Sdk"

& "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --install "ndk;28.2.13676358"
& "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat" --licenses
```

然后重新构建：

```powershell
cd E:\Projects\Rebirth

flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

---

## 12. 常见问题：sqlite3 下载失败

如果出现类似：

```text
By default, this package downloads a pre-compiled SQLite library.
This failed attempting to download libsqlite3.arm.android.so
SocketException ... address = 127.0.0.1
```

通常原因是：

```text
PowerShell 里设置了 HTTP_PROXY / HTTPS_PROXY，
但本地代理软件没有开启或端口不可用。
```

确认代理：

```powershell
Test-NetConnection 127.0.0.1 -Port 7890
curl.exe -x http://127.0.0.1:7890 -I https://github.com
```

如果代理可用，重新设置并构建：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:7890"
$env:HTTPS_PROXY="http://127.0.0.1:7890"

cd E:\Projects\Rebirth
flutter build apk --release --split-per-abi
```

如果不使用代理，则清理代理环境变量：

```powershell
Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:all_proxy -ErrorAction SilentlyContinue
```

然后重试。

---

## 13. 安装 APK 到 Android 手机

推荐安装：

```powershell
E:\Projects\Rebirth\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

可以通过：

- 微信文件传输助手
- QQ
- 数据线
- 网盘
- adb

使用 adb 安装：

```powershell
adb install -r E:\Projects\Rebirth\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

如果手机提示禁止安装未知来源应用，需要在系统设置中允许当前文件管理器、微信、浏览器或安装器安装未知来源应用。

---

## 14. 安装后真机检查

安装后至少检查：

```text
1. App 能否启动
2. Today 页面能否打开
3. Journal 页面能否打开
4. Plan 页面能否打开
5. Health 页面能否打开
6. Settings 页面能否打开
7. Profile 是否能编辑并保存
8. 关闭 App 后重新打开，数据是否保留
9. 中文字体、输入法、键盘弹出是否正常
10. Settings 中开发后端连接状态是否符合预期
```

注意：

```text
Android 端和 Windows 端默认不是同一个本地 SQLite 数据库。
Android 第一次安装后，本地数据为空是正常现象。
```

跨端互通需要登录同一个开发账号并使用 Profile 同步功能。

---

## 15. Android 真机连接本机 server

如果需要 Android 真机连接 Windows 上的 FastAPI server，不能使用：

```text
http://127.0.0.1:8000
```

因为 Android 手机上的 `127.0.0.1` 指的是手机自己。

需要：

1. Windows 与手机连接同一个局域网。
2. server 使用：

```powershell
cd E:\Projects\Rebirth\server
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

3. 查 Windows 局域网 IP：

```powershell
ipconfig
```

找到类似：

```text
192.168.x.x
```

4. Android 端 API Base URL 使用：

```text
http://192.168.x.x:8000
```

如果 App 当前未提供 UI 编辑入口，可通过构建参数或后续 Settings 配置能力设置。

---

## 16. Release 构建标准流程

推荐标准流程如下：

```powershell
cd E:\Projects\Rebirth

$env:JAVA_HOME="D:\Android Studio\jbr"
$env:Path="$env:JAVA_HOME\bin;$env:Path"

flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

成功后安装：

```powershell
E:\Projects\Rebirth\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

---

## 17. 当前限制

当前 APK 构建说明仍处于 alpha 阶段，存在以下限制：

```text
1. 默认构建的是 release APK，不是正式商店发布 AAB。
2. 当前没有配置正式签名 keystore。
3. 当前 Android 真机访问本机 server 需要局域网 IP。
4. 当前 Profile 支持手动云同步，但 Today / Journal / Plan / Health 尚未同步。
5. 当前开发账号仍是 dev-login，不是真实微信登录或正式账号。
6. 当前 token 存储仍是开发级方案，后续需要安全存储。
```

---

## 18. 后续可扩展

后续可以新增：

```text
1. 正式 Android 签名配置
2. appbundle 构建说明
3. GitHub Actions 自动构建 APK
4. Android 真机局域网联调说明
5. Android 内测分发说明
6. 微信登录 Android 配置说明
7. Release 版本号管理规范
```
