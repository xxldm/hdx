# 环境配置

本文档定义 HDX 的环境配置分层。目标是让本地开发、Symphony、Codex Desktop、手动 PowerShell、后端部署和前端部署各自有稳定入口，同时避免把部署机制混成一套。

## 配置分层

### 本地开发

根目录 `.env.local` 是本机开发的统一配置源，供手动 PowerShell、Codex Desktop、IDE 启动前环境、Symphony 启动脚本等本机场景复用。

- `.env.local` 不提交。
- `.env.example` 是可提交模板，不包含真实密钥。
- `.env.example` 修改后必须按模板原有分组和相邻位置同步 `.env.local` 的文件结构，不能简单追加到文件末尾；变量键保持一致但真实值可不同。
- 对 `.env.local` 新增变量不需要用户事前同意，完成后必须提示用户填写真实值；修改或删除 `.env.local` 已有变量前必须主动请求用户确认，不能以“需要同意”为理由静默跳过。
- 本地脚本应优先读取 `.env.local`。
- 如果某个工具有专属覆盖文件，应在读取 `.env.local` 后再读取专属文件。
- 本地 `.env.local` 可以保存 Nacos 地址、Nacos 登录凭据、数据库密码、Redis 密码、desktop all-in-one 本地库覆盖项和 Nuxt server 私有配置。
- `.env.example` 默认只让必须显式维护或高频变化的变量保持活跃；已有代码默认值的覆盖项以注释形式保留，需要改默认值时再取消注释。
- 后端 service profile 的非密钥运行配置仍应通过 Nacos Data ID 管理；本地调试 service profile 时，也优先连接本机或测试 Nacos，而不是把 service 配置散落到多个 `.env.*` 文件。

### Symphony

`.env.symphony.local` 只放 Symphony 专用变量或覆盖项，例如 Linear API Key、Symphony/Codex provider 覆盖、临时实验开关。

`.env.symphony.example` 修改后必须按模板原有分组和相邻位置同步 `.env.symphony.local` 的文件结构，不能简单追加到文件末尾。新增变量不需要用户事前同意，完成后提示用户填写真实值；修改或删除 `.env.symphony.local` 已有变量前必须主动请求用户确认，不能以“需要同意”为理由静默跳过。

加载顺序：

1. `.env.local`
2. `.env.symphony.local`

后者可以覆盖前者。后端数据库、Nacos、JWT issuer、前端后端地址等共享配置默认放 `.env.local`，不要重复维护在 `.env.symphony.local`。

### 后端部署

后端 service profile 的部署配置以 Nacos 为主。Spring Cloud Alibaba 2025.1.x 已不使用 `bootstrap.yml`，后端通过 `spring.config.import` 导入 Nacos 配置。

- Nacos 适合管理服务端非密钥配置，例如端口、数据库 JDBC URL、数据库用户名、JWT issuer、网关路由、服务治理和非敏感业务开关。
- 数据库密码、API Key、证书、令牌等密钥优先使用部署平台 Secret 或环境变量注入。
- Redis 地址、端口、database 和 timeout 属于非密钥配置，放 Nacos；Redis 密码和 PostgreSQL 密码一样属于密钥，通过服务启动配置中的环境变量或部署 Secret 注入，不写入 Nacos。
- Nacos 地址、Namespace 和登录凭据属于启动引导信息，通过环境变量或部署平台 Secret 注入；Namespace 为空仅表示使用 public namespace，登录凭据为空仅适用于 Nacos 未开启鉴权。Group 和 Data ID 已有代码默认值，只有改名或多环境复用启动脚本时才需要覆盖。
- 如果未来决定把密钥放入 Nacos，必须先新增 ADR，说明 Nacos 权限、加密、审计、备份和轮换策略。
- Nacos 配置示例位于 `docs/config/nacos/`；示例中的地址、用户名和 issuer 均为占位，不代表真实部署值。
- 修改 `docs/config/nacos/` 下的 Nacos 模板后，必须按模板原有层级和相邻位置同步真实 Nacos Data ID。新增配置项可以直接补到 Nacos 并在完成后通知用户；修改或删除已有配置项必须先征得用户同意。URL、issuer、内网地址等模板占位值不能自动猜测真实值，必须提示用户手动修改。

默认 Data ID：

- 公共数据库配置：`hdx-database.yml`
- 公共 Redis 配置：`hdx-redis.yml`
- `backend-core-service`：`hdx-core-service.yml`
- `backend-auth-service`：`hdx-auth-service.yml`
- `backend-gateway`：`hdx-gateway.yml`

`backend-core-service` 和 `backend-auth-service` 默认先可选导入公共数据库配置，再导入各自的服务配置。服务配置可以覆盖公共数据库配置中的 `spring.datasource.url` 和 `spring.datasource.username`，用于单独数据库、单独账号或临时联调。`backend-gateway` 不导入公共数据库配置。

`backend-auth-service` 和 `backend-gateway` 在启用 JWT `sid` 撤销时都读取公共 Redis Data ID：认证中心负责写入撤销 `sid`，gateway 负责读取并拒绝已撤销会话。

服务端启动前必须准备：

1. 在 Nacos 中创建对应 Data ID，内容参考 `docs/config/nacos/`。
2. 通过环境变量或部署 Secret 注入 `NACOS_SERVER_ADDR`、`NACOS_NAMESPACE`、`HDX_POSTGRES_PASSWORD`。
3. 启用 JWT 会话撤销时，通过环境变量或部署 Secret 注入 `HDX_REDIS_PASSWORD`。
4. 如果 Nacos 开启鉴权，注入 `NACOS_USERNAME`、`NACOS_PASSWORD`。

### 前端部署

前端不读取 Nacos。

Web 浏览器代码不得直接访问后端地址。浏览器调用同源 BFF/proxy 路径，例如 `/api/hdx/v1/**`。后端 gateway 地址和认证中心地址只能存在于 Nuxt server 私有 `runtimeConfig`、部署平台环境变量或反向代理配置中。

Nuxt SSR / 有 Nuxt server 时：

```text
业务请求：浏览器 -> /api/hdx/v1/** -> Nuxt server -> HDX_BACKEND_BASE_URL -> backend-gateway
认证请求：浏览器 -> /api/hdx/v1/auth/** -> Nuxt server -> HDX_AUTH_BASE_URL -> backend-auth-service
```

纯静态部署时：

```text
业务请求：浏览器 -> /api/hdx/v1/** -> Nginx/网关反代 -> backend-gateway
认证请求：浏览器 -> /api/hdx/v1/auth/** -> Nginx/网关反代 -> backend-auth-service
```

## 变量分层

本地开发建议保持最小活跃变量：`NACOS_SERVER_ADDR`、`NACOS_NAMESPACE`、`NACOS_USERNAME`、`NACOS_PASSWORD`、`HDX_POSTGRES_PASSWORD`、启用 Redis 会话撤销时的 `HDX_REDIS_PASSWORD`、`HDX_BACKEND_BASE_URL`、`HDX_AUTH_BASE_URL` 和 `NUXT_AUTH_SESSION_SECRET`。
Nacos Namespace 和鉴权必须按环境确认，空值只代表 public namespace 或未开启鉴权。
Data ID、认证中心初始化管理员、desktop all-in-one 数据库、Web cookie 名称、CSRF header、cookie secure、session 时长和 refresh 提前量都有默认值或只在特定场景需要，模板中默认保留为注释覆盖项。

### 后端 service profile 环境变量

- `NACOS_SERVER_ADDR`：Nacos 地址。
- `NACOS_NAMESPACE`：Nacos Namespace；为空时使用 public namespace，非 public 环境必须显式配置。
- `NACOS_USERNAME`：Nacos 用户名；仅 Nacos 未开启鉴权时可以为空。
- `NACOS_PASSWORD`：Nacos 密码；仅 Nacos 未开启鉴权时可以为空。
- `HDX_NACOS_GROUP`：可选覆盖项，Nacos Group，默认 `DEFAULT_GROUP`。
- `HDX_NACOS_DATABASE_DATA_ID`：可选覆盖项，后端数据库公共配置 Data ID，默认 `hdx-database.yml`。
- `HDX_NACOS_AUTH_DATA_ID`：可选覆盖项，`backend-auth-service` 读取的 Data ID，默认 `hdx-auth-service.yml`。
- `HDX_NACOS_CORE_DATA_ID`：可选覆盖项，`backend-core-service` 读取的 Data ID，默认 `hdx-core-service.yml`。
- `HDX_NACOS_GATEWAY_DATA_ID`：可选覆盖项，`backend-gateway` 读取的 Data ID，默认 `hdx-gateway.yml`。
- `HDX_NACOS_REDIS_DATA_ID`：可选覆盖项，公共 Redis 配置 Data ID，默认 `hdx-redis.yml`。
- `HDX_NACOS_DISCOVERY_IP`：可选覆盖项，服务注册到 Nacos 的可访问 IP；本地可填当前机器局域网 IP，云上优先由 Kubernetes Downward API、云主机 metadata 或部署脚本自动注入。
- `HDX_POSTGRES_PASSWORD`：PostgreSQL 默认密码。
- `HDX_AUTH_POSTGRES_PASSWORD`：可选，认证服务专用 PostgreSQL 密码；未设置时使用 `HDX_POSTGRES_PASSWORD`。
- `HDX_CORE_POSTGRES_PASSWORD`：可选，核心服务专用 PostgreSQL 密码；未设置时使用 `HDX_POSTGRES_PASSWORD`。
- `HDX_REDIS_PASSWORD`：Redis 密码。
- `HDX_AUTH_BOOTSTRAP_ADMIN_USERNAME`：可选，认证中心初始化管理员用户名；与密码同时设置时启用 bootstrap。
- `HDX_AUTH_BOOTSTRAP_ADMIN_PASSWORD`：可选，认证中心初始化管理员明文密码，只通过环境变量或部署 Secret 注入，服务端写入 BCrypt hash；不得写入 Nacos 或提交到仓库。
- `HDX_AUTH_BOOTSTRAP_ADMIN_DISPLAY_NAME`：可选覆盖项，初始化管理员显示名，默认 `管理员`。
- `HDX_AUTH_BOOTSTRAP_ADMIN_ROLE_CODE`：可选覆盖项，初始化管理员角色 code，默认 `ADMIN`。
- `HDX_AUTH_BOOTSTRAP_ADMIN_ROLE_NAME`：可选覆盖项，初始化管理员角色显示名，默认 `管理员`。
- `HDX_AUTH_BOOTSTRAP_ADMIN_PERMISSION_CODE`：可选覆盖项，初始化管理员权限 code，默认 `*`。
- `HDX_AUTH_BOOTSTRAP_ADMIN_PERMISSION_NAME`：可选覆盖项，初始化管理员权限显示名，默认 `全部权限`。

认证中心初始化管理员默认关闭。只设置用户名或只设置密码会导致 `backend-auth-service` 启动失败，以避免误以为初始化成功。账号不存在时创建用户、用户名标识、密码凭据、角色、权限和关联；账号已存在时只补齐角色、权限和关联，不覆盖已有密码。

### 后端 service profile Nacos 配置

公共数据库 Data ID 默认包含：

- `spring.datasource.url`：PostgreSQL JDBC URL。
- `spring.datasource.username`：PostgreSQL 用户名。

公共 Redis Data ID 默认包含：

- `spring.data.redis.host`：Redis 主机。
- `spring.data.redis.port`：Redis 端口。
- `spring.data.redis.database`：Redis database 编号。
- `spring.data.redis.timeout`：Redis 连接超时时间。

模块 Data ID 默认包含：

- `server.port`：服务端口。
- `spring.security.oauth2.resourceserver.jwt.issuer-uri`：OAuth2/JWT issuer 地址。
- `spring.security.oauth2.authorizationserver.issuer`：认证中心 issuer 地址。
- `hdx.auth.tokens.access-token-ttl`：第一方账号密码登录 access token 有效期。
- `hdx.auth.tokens.refresh-token-ttl`：第一方账号密码登录 refresh token 滑动不活跃窗口，默认 `7d`；7 天内没有触发 refresh 的用户需要重新登录，7 天内有操作并由客户端或 BFF 触发 refresh 时会签发新 refresh token 并刷新窗口。
- `hdx.auth.tokens.revocation-ttl-skew`：写入 Redis `sid` 撤销索引时追加的时钟偏移缓冲。
- `hdx.auth.login-security.max-failures`：账号密码登录冷却阈值，默认 `5`；小于等于 0 时关闭冷却。
- `hdx.auth.login-security.failure-window`：统计失败次数的滑动窗口，默认 `15m`。
- `hdx.auth.login-security.cooldown`：达到失败阈值后的冷却时间，默认 `15m`。
- `spring.flyway.schemas` 和 `spring.flyway.default-schema`：认证中心迁移使用 `auth` schema。
- `hdx.gateway.routes.core-uri`：gateway 转发到 core-service 的目标地址。
- `hdx.security.jwt.revocation.enabled` 和 `hdx.security.jwt.revocation.key-prefix`：gateway JWT 会话撤销检查开关和 Redis key 前缀。
- 其他非密钥服务治理、Sentinel 和业务开关配置。

`backend-auth-service` 和 `backend-gateway` 的 service profile 本地启动配置会把 `spring.data.redis.password` 绑定到 `HDX_REDIS_PASSWORD`，与 core/auth 的 `spring.datasource.password` 绑定到 `HDX_POSTGRES_PASSWORD` 或模块专用密码保持一致。

如果某个模块需要单独数据库或用户名，可以在该模块 Data ID 中重新声明 `spring.datasource.url` 和 `spring.datasource.username`；模块配置会覆盖公共数据库配置。数据库密码仍不放入 Nacos，使用模块专用环境变量或 `HDX_POSTGRES_PASSWORD`。

### 后端 all-in-one

- `HDX_LOCAL_JDBC_URL`：可选覆盖项，desktop all-in-one 使用的 H2 JDBC URL。
- `HDX_LOCAL_DB_USERNAME`：可选覆盖项，all-in-one 本地数据库用户名。
- `HDX_LOCAL_DB_PASSWORD`：可选覆盖项，all-in-one 本地数据库密码。

### Web / BFF 环境变量

- `HDX_BACKEND_BASE_URL`：本地和部署统一使用的后端 gateway 基础地址；Nuxt server 未设置 `NUXT_BACKEND_BASE_URL` 时会直接读取它。
- `NUXT_BACKEND_BASE_URL`：可选覆盖项，Nuxt 当前运行时读取的后端地址；只在 Web 需要使用不同于 `HDX_BACKEND_BASE_URL` 的地址时设置。
- `HDX_AUTH_BASE_URL`：本地和部署统一使用的认证中心基础地址；Nuxt server 未设置 `NUXT_AUTH_BASE_URL` 时会直接读取它。
- `NUXT_AUTH_BASE_URL`：可选覆盖项，Nuxt 当前运行时读取的认证中心地址；只在 Web 需要使用不同于 `HDX_AUTH_BASE_URL` 的地址时设置。
- `NUXT_BACKEND_LOCAL_TOKEN_HEADER`：可选，desktop all-in-one 本机令牌 header 名。
- `NUXT_BACKEND_LOCAL_TOKEN`：可选，desktop all-in-one 本机令牌值。
- `NUXT_AUTH_SESSION_COOKIE_NAME`：可选覆盖项，Web 加密 `HttpOnly` session cookie 名，默认 `hdx_web_session`。
- `NUXT_AUTH_SESSION_SECRET`：Web session 加密/签名密钥，至少 32 字符；真实环境必须稳定注入，Nuxt 重启后依靠它从 cookie 恢复登录态。
- `NUXT_AUTH_CSRF_COOKIE_NAME`：可选覆盖项，Web CSRF cookie 名，默认 `hdx_csrf`。
- `NUXT_AUTH_CSRF_HEADER_NAME`：可选覆盖项，Web 状态变更请求使用的 CSRF header 名，默认 `X-HDX-CSRF`。
- `NUXT_AUTH_COOKIE_SECURE`：可选覆盖项，Web auth cookie 是否带 `Secure`；默认在生产环境为 `true`，其他环境为 `false`。
- `NUXT_AUTH_SESSION_MAX_AGE_SECONDS`：可选覆盖项，Web session cookie 滑动有效期，默认 `604800` 秒。
- `NUXT_AUTH_REFRESH_SKEW_SECONDS`：可选覆盖项，Web BFF 在 access token 距离过期多少秒内提前 refresh，默认 `60` 秒。

Web 不提供访客模式。远程服务模式下，登录态由 Nuxt server 保存到加密 `HttpOnly` cookie session；浏览器不能读取 access token 或 refresh token，只通过同源 BFF 接口访问 session、login、refresh 和 logout。
Nuxt server 的业务 API 请求走 `HDX_BACKEND_BASE_URL` 指向 gateway，认证 API 请求走 `HDX_AUTH_BASE_URL` 指向 auth-service。
后端 refresh token 仍是 7 天滑动不活跃窗口的事实源；BFF 触发 refresh 后会轮换后端 refresh token，并重写 Web session cookie。

all-in-one 模式通过 `NUXT_BACKEND_LOCAL_TOKEN_HEADER` 和 `NUXT_BACKEND_LOCAL_TOKEN` 判断。该模式永远视为已登录，不展示登录页，不要求输入账号密码。
Nuxt server 返回固定本机 public session：`actorType=LOCAL_ADMIN`、`subject=local-admin`、`displayName=用户`、`roles=['ADMIN']`、`permissions=['*']`。
运行模式不写入 auth session，仍由 runtime/config 边界表达。

Desktop Full 发布包不再通过 Nuxt server 子进程读取上述 `NUXT_BACKEND_LOCAL_TOKEN_*` 变量。Desktop 静态 Web UI 通过 Tauri command 调用 Rust BFF，Rust 主进程从 sidecar `/local/session` 读取本机 token 并只在 Rust 边界内使用。

## 本地使用

从模板创建本地配置：

```powershell
Copy-Item .env.example .env.local
```

加载本地配置到当前 PowerShell 进程：

```powershell
. .\scripts\load-env.ps1
```

验证只打印变量名，不打印变量值：

```powershell
.\scripts\load-env.ps1 -ValidateOnly
```

非交互场景可以显式使用 PowerShell 7+ / `pwsh` 执行脚本：

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\load-env.ps1 -Path .env.example -ValidateOnly
```

## 约束

- 不提交 `.env.local`、`.env.symphony.local` 或任何真实密钥。
- 新增环境变量时必须同步更新 `.env.example` 和本文档。
- 修改 `.env.example` 或 `.env.symphony.example` 时，必须按模板原有分组和相邻位置同步对应 local 文件的变量结构，不能简单追加到文件末尾；新增变量可直接补齐并提示用户填写真实值，修改或删除已有变量必须先主动请求用户确认，不能以“需要同意”为理由静默跳过。
- 新增后端 service profile 非密钥配置时，必须同步更新 `docs/config/nacos/` 示例和本文档。
- 修改 `docs/config/nacos/` 模板时，必须按模板原有层级和相邻位置同步真实 Nacos Data ID；新增项可直接同步，修改或删除项必须先征得用户同意，占位 URL 等真实值由用户手动确认。
- 面向浏览器的 public runtime config 不得包含真实后端内网地址、令牌、数据库配置或密钥。
- 部署环境使用同名变量或 Nacos 配置，不使用仓库内 `.env.local` 文件。
