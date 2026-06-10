# ADR 0009：App 采用原生技术栈并保持 Online first

- 日期：2026-06-08
- 状态：已接受

## 背景

HDX 已经确定 Web、后端和 Desktop 第一阶段技术路线。下一步需要让 `apps/mobile` 从占位进入可实施设计，明确 Android 与 HarmonyOS NEXT 的平台范围、技术栈、与 Desktop 的关系，以及移动端是否规划 all-in-one 离线包。

当前用户确认：

- 暂定平台包含 Android 与 HarmonyOS NEXT。
- HarmonyOS NEXT 需要考虑 PC、平板、手机等多设备形态。
- 移动端不规划第三阶段完整离线版，只保留首版 Online only 与第二阶段离线缓存/离线草稿。

## 决策

App 第一阶段采用原生路线，不混入 Desktop Online，也不复用 Desktop Tauri shell：

- Android：采用 Kotlin + Jetpack Compose，工程后续位于 `apps/mobile/android/`。
- HarmonyOS NEXT：采用 ArkTS + ArkUI，工程后续位于 `apps/mobile/harmony/`。
- `apps/mobile` 可以依赖 `packages/shared` 中稳定的契约、错误码、权限枚举、OpenAPI 生成类型原型和跨端协议，但不得依赖 `apps/web` 或 `apps/desktop` 的实现细节。
- Desktop Online 与 App Online 共享后端公开契约、登录语义、权限模型和设计规范，不共享 Tauri shell、窗口能力或 Windows-only capability。
- App 首版只做 Online only，连接远端 `backend-auth-service` 与 `backend-gateway`。
- App 第二阶段只规划离线缓存和离线草稿：允许最近数据只读缓存、草稿本地保存、联网后同步提交。
- 移动端不规划 `backend-all-in-one`、本机 HTTP 后端服务、移动端 Spring Boot 进程或完整离线业务引擎。

移动端敏感信息边界：

- access token、refresh token、远端地址、离线草稿和本地缓存都必须使用平台原生安全存储、加密存储或明确的边界解析。
- App 浏览器/WebView 若后续用于低频页面，只能作为受控展示面，不承载核心认证态、系统权限、离线队列或本地数据主存储。

## 备选方案

- 复用 Desktop Online/Tauri shell：可以短期减少 UI 重写，但无法覆盖 HarmonyOS NEXT 原生生态，且容易把 Desktop 的窗口、托盘、Win32、sidecar 等边界带入移动端。
- 使用跨端 WebView/H5 App：前期速度快，但核心登录、通知、文件、权限、离线缓存、后台同步和多设备适配都会被平台限制放大。
- 移动端集成 `backend-all-in-one`：可以复用后端业务，但 Android 与 HarmonyOS NEXT 都不适合长期运行本机后端服务；生命周期、电量、后台限制、签名、体积和安全边界都不适合作为首版路线。
- 规划完整移动端离线业务引擎：能力更强，但当前用户已明确不要第三阶段；保留离线缓存和离线草稿更符合首版风险控制。

## 影响范围

- `apps/mobile/` 后续拆分为 Android 与 HarmonyOS NEXT 原生工程占位。
- `docs/ARCHITECTURE.md` 更新 App 架构边界。
- `docs/CONSTRAINTS.md` 更新 App 技术栈已决策状态。
- `packages/shared/` 后续应优先沉淀移动端也能消费的契约、错误码、权限枚举和协议说明。
- 后续质量门禁需要在 Android/HarmonyOS NEXT 工程创建后补充各自原生命令入口。

## 验证方式

本 ADR 只固定技术路线，不创建工程骨架。通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。

本 ADR 特有检查：

- 不再保留 “App 当前阶段仍不绑定框架” 等旧状态作为当前事实。

后续创建工程骨架时，需要分别补充：

- Android：Gradle/Android Studio 工程、Kotlin 编译、Compose UI preview 或最小启动验证。
- HarmonyOS NEXT：DevEco Studio/Hvigor 工程、ArkTS 编译、ArkUI 多设备预览或最小启动验证。

## 回滚条件

满足以下任一情况时，需要重新评估或替换本 ADR：

- Android 或 HarmonyOS NEXT 平台范围发生变化，例如不再支持其中一个平台。
- 业务明确要求完整离线业务引擎，而离线缓存/草稿无法满足。
- HarmonyOS NEXT 的目标设备范围、发布渠道或企业分发要求导致 ArkTS/ArkUI 路线不可行。
- 后续出现统一跨端原生框架能同时满足 Android、HarmonyOS NEXT 多设备和项目边界要求，并能显著降低维护成本。

## 后续事项

- 创建 `apps/mobile/android/` 和 `apps/mobile/harmony/` 原生工程骨架前，需要单独计划并确认工具链版本、目录结构和质量门禁入口。
- 设计移动端 Online 登录态、token 安全存储、刷新策略和登出清理。
- 设计第二阶段离线缓存/离线草稿的数据范围、加密存储、同步队列、冲突处理和失败重试。
- 更新 `packages/shared` 的移动端消费方式，避免 Android/HarmonyOS NEXT 复制契约常量。

## 参考资料

- Android Developers：[`Android is Compose-first`](https://developer.android.com/develop/ui/compose/first)，用于确认 Android 新工程优先采用 Jetpack Compose。
- Android Developers：[`Background work`](https://developer.android.com/develop/background-work) 与 WorkManager 文档，用于判断移动端不适合长期运行本机后端服务。
- HUAWEI Developers：[`HarmonyOS NEXT Develop`](https://developer.huawei.com/consumer/en/harmonyos/develop/) 与 ArkUI 文档，用于确认 HarmonyOS NEXT 原生开发入口、ArkTS、ArkUI 和平台 Kit 方向。
