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
- Web 与 App 调用后台时，必须通过契约或 SDK，不读取后台内部模块。
- 跨端共享的错误码、协议字段、权限枚举和基础类型应归入共享层。
- 端侧私有展示模型不得污染后台领域模型。

OpenAPI 与 shared 层边界见 ADR 0006 和 ADR 0007。

- OpenAPI spec 按外部入口拆分：`backend-auth-service` 暴露认证中心契约，`backend-gateway` 暴露服务端业务入口契约。
- `backend-core-service` 和 `backend-all-in-one` 的 `/v3/api-docs` 只作为调试和本机集成参考。
- 当前只从 OpenAPI 快照生成 TypeScript 类型原型，不生成完整 API client，不创建根 pnpm workspace。
- Web 仍通过 Nuxt server BFF 调用后端，浏览器不得使用生成物直连后端。

`packages/shared/` 当前保持轻量结构。

- `contracts/` 放跨端契约和 release manifest JSON Schema。
- `generated/openapi/` 放从 OpenAPI 快照生成的 TypeScript 类型原型。
- `constants/` 和 `tools/` 放可共享常量与仓库工具。
- Shared 当前不是可安装包，端侧或后端运行时逻辑不得提前进入 shared。

Desktop 第一阶段技术与打包策略见 ADR 0008。

- 技术栈为 Tauri + Rust + Vite + TypeScript，平台范围为 Windows + Linux 并列。
- `apps/desktop` 只维护一套代码，Full/Online 通过构建 flavor、Tauri 配置变体和安装包内容区分。
- `HDX Desktop Full` 后续包含 `backend-all-in-one` sidecar/native exe，仅离线本地模式，使用本机 H2 和固定 `LOCAL_ADMIN:local-admin` 身份。
- 本机 token 只能在 Tauri/Rust 主进程和 Rust BFF command 边界内流转，不得暴露给 WebView 浏览器代码。
- `HDX Desktop Online` 不包含 all-in-one，仅在线远程模式，连接远端 `backend-auth-service` 与 `backend-gateway`。
- 自启动、通知、deep link、托盘、配置目录和导入导出应抽象为 Windows/Linux 通用 desktop capability。
- 类似壁纸软件的桌面窗口嵌入定义为 Windows-only wallpaper mode，需要单独做 Win32 spike，不要求 Linux 提供等价能力。

App 第一阶段技术栈与离线路线见 ADR 0009。

- Android 后续采用 Kotlin + Jetpack Compose。
- HarmonyOS NEXT 后续采用 ArkTS + ArkUI，并面向 PC、平板、手机等多设备形态适配。
- App 不复用 Desktop Tauri shell，不混入 Desktop Online，也不规划移动端 `backend-all-in-one` 或本机 HTTP 后端服务。
- App 首版只做 Online only，连接远端 `backend-auth-service` 与 `backend-gateway`。
- 第二阶段只规划离线缓存和离线草稿，联网后同步提交。

缓存、对象存储与队列基础设施边界见 ADR 0010。

- 服务端/云端模式使用 Redis、S3-compatible 对象存储和 RabbitMQ。
- 对象存储代码只使用 S3 核心子集，默认本地/私有化候选为 RustFS，后续可切换到云端 OSS/COS/OBS/S3。
- 业务代码不得直接散落对象存储或 RabbitMQ SDK 调用；后续通过 `ObjectStoragePort`、`MessageQueuePort`、transactional outbox、消息 envelope 和幂等 consumer 隔离基础设施差异。
- Desktop all-in-one 不内置 Redis 或 RabbitMQ；验证码、登录限流、JWT 撤销等服务端反滥用能力默认禁用或 no-op。
- 需要本地文件能力时可启动绑定 `127.0.0.1` 的 RustFS sidecar；本地异步任务使用 H2 outbox + local worker。

公开许可与后端私有边界见 ADR 0011。

- 公开主仓库采用 Apache-2.0。
- `services/backend` 后续维持私有仓库。
- 公开主仓库禁止提交后端源码快照、后端 Spring Boot JAR/WAR、`.class` 文件和后端构建中间产物。
- 后端 release 目标只允许 native executable archive，不发布 JAR/WAR。
- 用户可见的本地完整模式后续统一称为 Full；当前内部模块名 `backend-all-in-one` 暂不在本轮重命名。

GitHub Releases 产物边界见 ADR 0012、ADR 0013、ADR 0014。日常 tag-only 发布操作见 `docs/RELEASE_RUNBOOK.md`。

发布边界：

- 公开主仓库 GitHub Releases 是唯一公开发布入口，但不负责自动部署。
- 每次发布以主仓库 release tag 或 root commit 作为事实源，Web、Desktop、shared/OpenAPI 和后续 App 均使用根仓库锁定的提交或子模块指针，不拉取 `latest`。
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
- `.github/workflows/release-start.yml` 已提供正式 tag start 入口第一版：真实 `v*` tag push 会计算 root/backend/OpenAPI 发布上下文，先在主仓库判断最新一个合格历史 Release 中的后端 native asset 是否可复用；复用成功时直接触发主仓库 `release.yml`，复用失败时才触发后端私有仓库 release resolver 运行 native build；手动入口默认 dry-run。
- `.github/workflows/release.yml` 已提供正式发布入口第一版：手动接收后端来源 payload，由 `resolve-backend-native` 统一输出已校验后端资产。
  它支持多个后端 native Actions artifact 聚合，支持从同一个历史主仓库 Release 复用多个后端 native asset，构建 Web node-server asset、Desktop Online Windows/Linux asset 和 Desktop Full Windows/Linux asset，创建并远端校验 draft Release；尚不 publish。
- Desktop Full 发布包当前以公开 `backend-full` archive 为校验事实源，并在打包阶段把同平台已解压 `backend-full` 与 `backend-build.json` 放入 Desktop 资源。
  Desktop Full 运行时已实现最小 sidecar 闭环：复制内置资源到用户数据目录、启动本机后端、健康检查、读取 `/local/session` 并在退出时清理进程。
  Desktop 发布包改为消费 `apps/web` 的 `desktop-static` 静态输出；Desktop 静态 UI 通过 Rust BFF command 调用本机 sidecar，WebView 不接触本机 token。
  Desktop Online 远端地址配置和 Online Rust BFF 认证转发仍待后续实现。
- `services/backend/.github/workflows/backend-release-resolve.yml` 已收缩为后端 native build resolver：只按输入的 `backend_commit` checkout 后端源码、计算必需资产对应的 native build 范围、调用 `backend-native-artifact.yml` 生产短期 Actions artifact。
  它可用 `HDX Main Workflow Bot` 的 `Actions: write` token 回调主仓库 `release.yml` assemble；不读取主仓库历史 Release，也不需要主仓库 `Contents: read` GitHub App 权限。
- Release manifest schema、校验脚本和最小 draft 复用脚本已能表达、校验并生成历史主仓库 Release asset 复用来源、backend native fingerprint 和历史后端 asset 构建来源。

正式 tag-only 发布设计已记录在 ADR 0013 和 ADR 0014。后续仍需把 App 构建、正式 publish、失败清理、Desktop Full 真实安装包验证和 Desktop Online 远端配置闭环串联起来。

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

Web 浏览器代码不直接访问后端地址。

- 浏览器调用 Nuxt server 暴露的 BFF/proxy 路径，例如 `/api/hdx/v1/**`。
- Nuxt server 再分别调用后端公开 REST API 和认证中心 API。
- 业务请求通过 `backend-gateway`，登录、刷新和登出请求直接调用 `backend-auth-service`。
- 后端地址、本机 all-in-one 令牌、access token、refresh token 和其他敏感配置只能留在 Nuxt server 私有运行边界内。
- Web 登录态使用加密 `HttpOnly` cookie session，浏览器只能读取 public session 和 CSRF token。

同一套 Web UI 可以作为 Desktop 静态 UI 构建，但不改变 Web Online 的 Nuxt SSR/Nitro 运行形态。

- Desktop 静态构建使用 `HDX_WEB_BUILD_TARGET=desktop-static`，生成 `ssr: false` 的静态输出供 Tauri WebView 消费。
- Web store 通过 `app/utils/hdx-api-client.ts` 选择传输方式：Web Online 调 Nuxt server BFF，Desktop WebView 调 Tauri Rust BFF command。
- Desktop Rust BFF 负责持有本机 sidecar token 或后续远端登录态；WebView 不保存本机 token、access token 或 refresh token。

## 待决策事项

以下事项尚未决策，不能在没有 ADR 的情况下擅自固定：

- 对象存储上传下载业务接口、文件生命周期、消息 topic、consumer 拓扑和具体业务接入点。
- 真实 GitHub Actions release workflow 的完整实现、失败重试策略和人工发布确认体验；跨仓库凭据与 artifact 策略已由 ADR 0013 约束，当前仅有 release dry-run workflow 骨架。
- Release notes 和版本号策略。
- Desktop 自动更新、发布渠道、Full/Online 数据导入导出格式，以及从首版未签名发布切换到签名发布的条件。
- App Android/HarmonyOS NEXT 工程骨架细节、移动端离线缓存/草稿的存储、同步队列、冲突处理和加密策略。

## 后端第一阶段架构

后端 Maven 工程位于 `services/backend/`，不把仓库根目录改成 Maven 主工程。

后端第一阶段包含：

- `backend-contract`：后端共享 API 契约与 DTO。
- `backend-core`：核心业务能力、JPA 实体、Repository、服务和 REST 控制器。
- `backend-core-service`：核心业务微服务启动器。
- `backend-auth-service`：认证中心微服务启动器，作为 JWT/OAuth2 issuer，使用 PostgreSQL `auth` schema。
- `backend-gateway`：API 网关微服务启动器。
- `backend-all-in-one`：desktop 集成用本机后端启动器。

运行拓扑：

- 服务端微服务部署：
  - `backend-auth-service` 和 `backend-gateway` 是同级外部入口。
  - `backend-auth-service` 使用 Spring Security Authorization Server 签发 token，暴露登录、刷新、登出、OIDC discovery 和 JWK。
  - `backend-gateway` 对外开放业务 REST API，只转发到 `backend-core-service`，并作为外部资源访问的统一入口校验 JWT，通过 Redis 检查 `sid` 是否已撤销。
  - `backend-core-service` 不作为外部 API 入口暴露。
  - 服务端使用 Nacos Discovery、Nacos Config、Sentinel、OpenFeign、PostgreSQL、Redis、RabbitMQ 和 S3-compatible 对象存储。
- desktop all-in-one：
  - `backend-all-in-one` 复用 `backend-core`，绑定 `127.0.0.1`，使用 H2，并通过随机本机令牌保护 HTTP 请求。
  - 后续需要本地文件能力时可启动 RustFS sidecar。
  - 本地异步任务通过 H2 outbox + local worker 执行，不内置 Redis 或 RabbitMQ。

身份边界：

- 业务核心通过统一当前身份抽象读取请求身份，不直接读取 JWT、Web session 或 all-in-one 本机 token。
- `backend-core` 暴露 `GET /api/v1/auth/current`，返回 `actorType`、`subject`、`displayName`、`roles` 和 `permissions`。
- 服务端模式由 `backend-core-service` 从认证中心签发的 JWT claims 投影当前身份；all-in-one 模式由本机 token 过滤器注入固定 `LOCAL_ADMIN:local-admin` 身份。
- `displayName` 只用于回显，不作为日志、审计、权限判断或业务规则依据。

后端配置规则：

- Spring Cloud Alibaba 2025.1.x 不使用 bootstrap 配置，Nacos 配置通过 `spring.config.import` 接入。
- 服务端 profile 使用外部数据库和 Nacos；非密钥配置放 Nacos，数据库密码、Nacos 登录凭据、API Key、证书和令牌通过环境变量或部署 Secret 注入。
- Redis 用于 JWT 会话撤销/黑名单。认证中心登出或强制下线时写入撤销 `sid`，gateway 在 JWT 校验通过后检查 Redis；Redis 不可用时，受保护请求返回 `503`。
- Redis 后续扩展到缓存、TTL store、限流等能力时，all-in-one 只按单机语义提供 no-op、内存、H2 或 JVM 降级，不模拟服务端反滥用或分布式语义。
- 对象存储配置必须遵守 S3-compatible 核心子集边界；服务端可以连接 RustFS 或云端 OSS/COS/OBS/S3，all-in-one 只在需要文件能力时启动本机 RustFS sidecar。
- 队列配置必须遵守 RabbitMQ + transactional outbox 边界；all-in-one 不启动 RabbitMQ，使用 H2 outbox + local worker。
- 数据库消费者默认先导入公共数据库 Nacos Data ID，再导入模块自己的 Data ID；公共层保存共用 JDBC URL 和用户名，模块层可以覆盖数据库 URL 和用户名，密码通过公共或模块专用环境变量注入。
- all-in-one 使用本地配置文件和本地嵌入式数据库。
- 数据库迁移使用 Flyway。
- 核心业务迁移脚本由 `services/backend/backend-core/src/main/resources/db/migration/` 提供。
- 认证中心迁移脚本由 `services/backend/backend-auth-service/src/main/resources/db/migration/` 提供，并只面向服务端 PostgreSQL `auth` schema。
- PostgreSQL 是服务端数据库事实源，H2 用于 desktop all-in-one、local 和测试；运行时 Hibernate 只做 `ddl-auto: validate` 校验。

后端 native 规则：

- 正式 native 构建入口使用 `mvn -Pnative package`，由 Maven 生命周期先执行 Spring AOT，再执行 GraalVM Native Build Tools。
- JPA 实体在 `backend-core` 中通过 Hibernate Maven 插件做构建期字节码增强；新增实体时必须纳入增强范围。
- Native Image metadata 优先依赖 Spring AOT 与官方 reachability metadata；项目内缺口只通过 Spring `RuntimeHints` 补齐。
