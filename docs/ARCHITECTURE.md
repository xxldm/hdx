# 暂定架构

本项目整体框架仍在逐步确定中。后端架构已由 `docs/adr/0002-backend-java-spring-cloud-alibaba-architecture.md` 确定第一阶段方案。

## 目标形态

HDX 暂定由以下部分组成：

- `services/backend/`：后台服务端 Maven 多模块工程，采用 Java 25（GraalVM）、Spring Boot 4.x、Spring Cloud Alibaba 2025.1.x。
- `apps/web/`：Web 端 Nuxt 应用，采用 Nuxt 4.x、Nuxt UI 4.x、`@nuxtjs/i18n`、Pinia、Zod 与 pnpm。
- `apps/desktop/`：Desktop 端 Tauri 应用，采用 Tauri + Rust + Vite + TypeScript，第一阶段 Windows + Linux 并列。
- `apps/mobile/`：App 端原生工程容器，第一阶段包含 Android 原生 Kotlin + Jetpack Compose 与 HarmonyOS NEXT 原生 ArkTS + ArkUI。
- `packages/shared/`：跨端共享契约、类型、工具和协议占位。
- `docs/`：项目事实源、计划、约束和决策记录。

## 依赖方向

允许的默认依赖方向：

- `apps/web/` 可以依赖 `packages/shared/`。
- `apps/desktop/` 可以依赖 `packages/shared/`。
- `apps/mobile/` 可以依赖 `packages/shared/`。
- `services/backend/` 可以依赖 `packages/shared/`。
- `packages/shared/` 不依赖任何具体端。
- `docs/` 不参与运行时依赖，但必须反映真实架构。

禁止的默认依赖方向：

- `services/backend/` 依赖 `apps/web/` 或 `apps/mobile/`。
- `services/backend/` 依赖 `apps/desktop/` 的实现细节。
- `apps/web/`、`apps/desktop/` 与 `apps/mobile/` 互相依赖实现细节。
- 任意模块绕过 `packages/shared/` 复制共享契约。

## 分层原则

具体框架确定后，每个业务域应按稳定层次组织。推荐方向如下：

1. 契约与类型。
2. 配置与环境解析。
3. 数据访问或外部适配。
4. 业务服务。
5. 运行时入口。
6. 用户界面或交付接口。

依赖只能从更靠近交付面的层指向更基础的层，不能反向穿透。

## 边界契约

- 后台对外暴露的 API 必须有契约文档或可生成契约。
- Web 与 App 调用后台时，必须通过契约或 SDK，不依赖后台源码或内部实现。
- 跨端共享的错误码、协议字段、权限枚举和基础类型应归入共享层。
- 端侧私有展示模型不得污染后台领域模型。

OpenAPI 与 shared 层边界见 ADR 0006 和 ADR 0007。

- OpenAPI spec 按外部入口拆分：测试期由后端认证入口生成认证中心契约，由后端业务入口生成服务端业务入口契约。
- 生产和 release native 运行时不暴露 `/v3/api-docs` 或 Swagger UI；后端内部实现入口和本机后端不作为外部 OpenAPI 事实源。
- 当前只从 OpenAPI 快照生成 TypeScript 类型原型，不生成完整 API client，不创建根 pnpm workspace。
- Web 仍通过 Nuxt server BFF 调用后端，浏览器不得使用生成物直连后端。

`packages/shared/` 当前保持轻量结构。

- `contracts/` 放跨端契约和 release manifest JSON Schema。
- `generated/openapi/` 放从 OpenAPI 快照生成的 TypeScript 类型原型。
- `constants/` 和 `tools/` 放可共享常量与仓库工具。
- Shared 当前不是可安装包，端侧或后端运行时逻辑不得提前进入 shared。

用户数据持久化与跨端同步边界见 ADR 0016。
Desktop Full/Online 备份导入导出边界见 ADR 0018。

- Web Online 和 Desktop Online 的登录用户数据以远端后端为事实源；接口不可用时显示不可用状态，不静默回退旧本地数据。
- App 保持 Online first，但第二阶段允许弱网、无网暂存草稿，联网后按后端版本、幂等和冲突规则同步。
- Desktop Full 使用本机后端和本机数据库保存业务数据、工作台布局、组件配置和模块数据；Tauri app config 只保存纯客户端配置。
- Desktop Full 与 Desktop Online 互相搬家只通过用户主动导入导出 `.hdxbak` 备份包；不做自动同步、迁移或合并。`.hdxbak` 是 zip 容器，内部使用 manifest、分领域 NDJSON、checksum 和预留附件目录；备份包不导出公开数据、token、会话、权限授予记录或治理记录。
- 计时器预设和组件配置可以作为用户数据同步；计时器运行状态属于设备级状态，不跨设备同步。

Desktop 第一阶段技术与打包策略见 ADR 0008。

- 技术栈为 Tauri + Rust + Vite + TypeScript，平台范围为 Windows + Linux 并列。
- `apps/desktop` 只维护一套代码，Full/Online 通过构建 flavor、Tauri 配置变体和安装包内容区分。
- `HDX Desktop Full` 后续包含本机后端 sidecar/native exe，仅离线本地模式，使用本机数据和固定本机身份。
- Desktop Full 的用户业务数据、工作台布局、组件配置和模块数据进入本机数据库，不进入 Tauri app config。
- Tauri app config 只保存开机自启、远端地址、窗口偏好、托盘偏好和本机 capability 开关等纯客户端配置。
- 本机 token 只能在 Tauri/Rust 主进程和 Rust BFF command 边界内流转，不得暴露给 WebView 浏览器代码。
- `HDX Desktop Online` 不包含本机后端，仅在线远程模式，连接远端认证入口与业务入口。
- 自启动、通知、deep link、托盘、配置目录和导入导出应抽象为 Windows/Linux 通用 desktop capability。
- 类似壁纸软件的桌面窗口嵌入定义为 Windows-only wallpaper mode，需要单独做 Win32 spike，不要求 Linux 提供等价能力。

App 第一阶段技术栈与离线路线见 ADR 0009。

- Android 后续采用 Kotlin + Jetpack Compose。
- HarmonyOS NEXT 后续采用 ArkTS + ArkUI，并面向 PC、平板、手机等多设备形态适配。
- App 不复用 Desktop Tauri shell，不混入 Desktop Online，也不规划移动端本机 HTTP 后端服务。
- App 首版只做 Online only，连接远端认证入口与业务入口。
- 第二阶段只规划离线缓存和离线草稿，联网后同步提交；冲突处理遵守 ADR 0016 的版本、幂等和显式冲突原则。

缓存、对象存储与队列基础设施边界见 ADR 0010。

- 服务端/云端模式使用 Redis、S3-compatible 对象存储和 RabbitMQ。
- 对象存储代码只使用 S3 核心子集，默认本地/私有化候选为 RustFS，后续可切换到云端 OSS/COS/OBS/S3。
- 业务代码不得直接散落对象存储或 RabbitMQ SDK 调用；后续通过 `ObjectStoragePort`、`MessageQueuePort`、transactional outbox、消息 envelope 和幂等 consumer 隔离基础设施差异。
- Local/Full 本机后端不内置 Redis 或 RabbitMQ；验证码、登录限流、JWT 撤销等服务端反滥用能力默认禁用或 no-op。
- 需要本地文件能力时可启动绑定 `127.0.0.1` 的 RustFS sidecar；本地异步任务使用 H2 outbox + local worker。

公开许可与后端私有边界见 ADR 0011。

- 公开主仓库采用 Apache-2.0。
- `services/backend` 后续维持私有仓库。
- 公开主仓库禁止提交后端源码快照、后端 Spring Boot JAR/WAR、`.class` 文件和后端构建中间产物。
- 后端 release 目标只允许 native executable archive，不发布 JAR/WAR。
- 用户可见的本地完整模式后续统一称为 Full；后端模块名和服务名不敏感，但用户可见产品文案优先使用 Full、Services、Standalone 等交付名称。

GitHub Releases 产物边界见 ADR 0012、ADR 0013、ADR 0014。日常 tag-only 发布操作见 `docs/RELEASE_RUNBOOK.md`。
后端 native 交付、Local/Standalone/Services 边界见 ADR 0017。

发布边界：

- 公开主仓库 GitHub Releases 是唯一公开发布入口，但不负责自动部署。
- 每次发布以主仓库 release tag 或 root commit 作为事实源，Web、Desktop、shared/OpenAPI 和后续 App 均使用根仓库锁定的提交或子模块指针，不拉取 `latest`。
- 所有进入公开 Release 的后端包只允许发布 native archive；JVM 后端包只作为开发、测试、CI 或内部排障形态，不发布 JAR/WAR、`.class` 或源码快照。
- 后端私有仓库 CI 先编译 `backend-full` 与 `backend-services` native archive，并只通过 GitHub Actions artifact 临时交接给主仓库；后端 artifact 保留期为 1 天。
- 主仓库 Release 可以公开后端 native archive；但主仓库 CI 不 checkout 后端私有源码，Release 不包含源码、JAR/WAR、`.class` 或后端构建中间产物。
- 后端微服务按平台聚合为 `backend-services` 压缩包，微服务粒度保留在包内部；App 不内置后端，只发布 Online 客户端。

发布组装与复用：

- 真实 release workflow 使用 GitHub App token 跨仓库读取 artifact，主仓库下载后校验 manifest、sha256、root ref、OpenAPI hash 和禁止文件。
- 校验通过后，主仓库构建 Web、Desktop Online、Desktop Full 和后续 App Online，并统一发布到主仓库 Release。
- 后端 native 输入未变化时，主仓库可以按 backend native fingerprint 复用指定历史主仓库 Release 中已经公开的后端 native asset。
- 复用来源必须显式记录 release tag、asset name、sha256、size 和历史构建来源，不允许使用 `latest` 或后端临时 Actions artifact。

当前实现状态：

- `backend-native-manifest.json`、`release-manifest.json`、`backend-build.json` 和 `backend-services-manifest.json` 的 JSON Schema 位于 `packages/shared/contracts/release/`。
- 当前已有 `check-*` 与 `debug-*` 手动验证 workflow；它们不是正式发布入口，具体用途见 `.github/workflows/README.md`。
- `.github/workflows/release-start.yml` 已提供正式 tag start 入口第一版：真实 `v*` tag push 会计算 root/backend/OpenAPI 发布上下文，按 tag 形态区分正式发布与预览发布；`v1.2.3` 是 stable 正式发布，`v1.2.3-rc.1` 等 prerelease tag 是 preview 预览发布。
  它会先在主仓库判断最新一个合格历史 Release 中的后端 native asset 是否可复用；复用成功时直接触发主仓库 `release.yml`，复用失败时才触发后端私有仓库 release resolver 运行 native build；手动入口默认 dry-run。
- `.github/workflows/release.yml` 已提供正式发布入口第一版：手动接收后端来源 payload，由 `resolve-backend-native` 统一输出已校验后端资产。
  它支持多个后端 native Actions artifact 聚合，支持从同一个历史主仓库 Release 复用多个后端 native asset，构建 Web node-server asset、Desktop Online Windows/Linux asset 和 Desktop Full Windows/Linux asset，创建 draft Release、上传资产并远端校验；`release_mode=publish` 时远端校验通过后发布，preview tag 会发布为 GitHub prerelease 且不标记为 Latest。
  App 当前不进入发布闭环，不构建、不要求 App asset，也不阻塞 publish。
- Desktop Full 发布包当前以公开 `backend-full` archive 为校验事实源，并在打包阶段把同平台已解压 `backend-full` 与 `backend-build.json` 放入 Desktop 资源。
  Desktop Full 运行时已实现最小 sidecar 闭环：复制内置资源到用户数据目录、启动本机后端、健康检查、读取 `/local/session` 并在退出时清理进程。
  Desktop 发布包改为消费 `apps/web` 的 `desktop-static` 静态输出；Desktop 静态 UI 通过 Rust BFF command 调用本机 sidecar，WebView 不接触本机 token。
  Desktop Online 已实现远端地址填写、用户级配置持久化、`/actuator/health` 连接检查、远端登录、refresh、logout 和业务请求 Bearer 注入；远端 access/refresh token 只保存在 Rust 主进程内。
- `services/backend/.github/workflows/backend-release-resolve.yml` 已收缩为后端 native build resolver：只按输入的 `backend_commit` checkout 后端源码、计算必需资产对应的 native build 范围、调用 `backend-native-artifact.yml` 生产短期 Actions artifact。
  它可用 `HDX Main Workflow Bot` 的 `Actions: write` token 回调主仓库 `release.yml` assemble；不读取主仓库历史 Release，也不需要主仓库 `Contents: read` GitHub App 权限。
- Release manifest schema、校验脚本和最小 draft 复用脚本已能表达、校验并生成历史主仓库 Release asset 复用来源、backend native fingerprint 和历史后端 asset 构建来源。

正式 tag-only 发布设计已记录在 ADR 0013 和 ADR 0014。`v0.0.0-preview.5` 已验证真实 tag-only 预览发布和 Desktop Full/Linux 真实后端 AppImage sidecar/API smoke。后续仍需把失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和真实安装包矩阵验证串成完整发布闭环；App 等有基础工程和打包入口后再单独接入。

## Web 第一阶段架构

Web 工程位于 `apps/web/`，当前不把仓库根目录升级为 pnpm workspace。

Web 第一阶段采用：

- Nuxt 4.x 默认 SSR 形态。
- Nuxt UI 4.x 作为 UI 组件和主题基础。
- `@nuxtjs/i18n` 作为国际化方案，默认 `zh-CN`，备用 `en-US`。
- i18n 使用应用内部状态切换，URL 不随语言变化，不使用域名或路径前缀切换语言。
- Pinia 作为端侧状态管理，按领域拆分 store。
- Zod 作为 Web 边界数据解析与显式校验工具。
- pnpm 作为 `apps/web/` 内包管理器。
- Web UI 的信息密度和主要交互以桌面浏览器为目标，不为手机 Web 单独适配布局或编辑态。
- 手机端体验后续由 App 承接；手机浏览器不作为当前首页工具箱的验收范围。
- 交互层继续统一使用 Pointer Events，让鼠标与桌面宽度触摸输入共用一套事件模型。
- 关键操作不能只依赖 hover；需要为触摸输入保留 tap 或显式按钮入口。

Web 浏览器代码不直接访问后端地址。

- 浏览器调用 Nuxt server 暴露的 BFF/proxy 路径，例如 `/api/hdx/v1/**`。
- Nuxt server 再分别调用后端公开 REST API 和认证中心 API。
- 业务请求通过后端业务入口，登录、刷新和登出请求直接调用后端认证入口。
- 后端地址、本机令牌、access token、refresh token 和其他敏感配置只能留在 Nuxt server 私有运行边界内。
- Web 登录态使用加密 `HttpOnly` cookie session，浏览器只能读取 public session 和 CSRF token。

同一套 Web UI 可以作为 Desktop 静态 UI 构建，但不改变 Web Online 的 Nuxt SSR/Nitro 运行形态。

- Desktop 静态构建使用 `HDX_WEB_BUILD_TARGET=desktop-static`，生成 `ssr: false` 的静态输出供 Tauri WebView 消费。
- Web store 通过 `app/utils/hdx-api-client.ts` 选择传输方式：Web Online 调 Nuxt server BFF，Desktop WebView 调 Tauri Rust BFF command。
- Desktop Rust BFF 负责持有本机 sidecar token 或远端登录态；WebView 不保存本机 token、access token 或 refresh token。

## 待决策事项

以下事项尚未决策，不能在没有 ADR 的情况下擅自固定：

- 对象存储上传下载业务接口、文件生命周期、消息 topic、consumer 拓扑和具体业务接入点。
- 真实 GitHub Actions release workflow 的完整实现、失败重试策略和人工发布确认体验；跨仓库凭据与 artifact 策略已由 ADR 0013 约束，当前仅有 release dry-run workflow 骨架。
- Release notes 和版本号策略。
- Desktop 自动更新、发布渠道，以及从首版未签名发布切换到签名发布的条件。
- App Android/HarmonyOS NEXT 工程骨架细节、移动端离线缓存/草稿的具体存储、同步队列、冲突 UI 和加密策略。

## 后端第一阶段架构

后端工程位于私有子模块 `services/backend/`，根仓库不作为 Maven 主工程。公开主仓库只描述交付形态、跨端集成方式、必要模块/服务名和 release 边界；后端内部调用链、迁移目录、基础设施适配、内部契约、native/AOT 诊断和验证流水账以 `services/backend/README.md` 与 `services/backend/docs/README.md` 为事实源。

公开可见的后端交付形态：

- Desktop Full / Local 本机后端：随 Desktop Full 或本机模式使用，面向本机私有数据和本机 sidecar。
- Services 微服务服务端：面向有部署能力的服务端环境，由后端私有仓库构建 native 服务端包。
- Standalone 服务端单体：面向手工服务端部署，和本机 Full 模式保持安全边界隔离。

后端公开边界：

- 公开 Release 后端包只发布 native archive，不发布 JVM JAR/WAR、`.class`、源码快照或 JVM 后端包。
- Web/Desktop Online/App 只通过公开 API 或 BFF/客户端能力访问远端服务，不依赖后端源码或内部实现。
- Desktop Full 只消费发布流程提供的本机后端 native 产物，不把后端源码或构建中间产物带入公开主仓库。
- 根仓库 `packages/shared/contracts` 只放多端公开契约和 release/schema 契约；后端内部微服务契约留在后端私有仓库。
