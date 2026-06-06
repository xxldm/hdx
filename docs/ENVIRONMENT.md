# 环境配置

本文档定义 HDX 的环境配置分层。目标是让本地开发、Symphony、Codex Desktop、手动 PowerShell、后端部署和前端部署各自有稳定入口，同时避免把部署机制混成一套。

## 配置分层

### 本地开发

根目录 `.env.local` 是本机开发的统一配置源，供手动 PowerShell、Codex Desktop、IDE 启动前环境、Symphony 启动脚本等本机场景复用。

- `.env.local` 不提交。
- `.env.example` 是可提交模板，不包含真实密钥。
- 本地脚本应优先读取 `.env.local`。
- 如果某个工具有专属覆盖文件，应在读取 `.env.local` 后再读取专属文件。
- 本地 `.env.local` 可以保存 Nacos 地址、Nacos 登录凭据、数据库密码、Redis 密码、desktop all-in-one 本地库配置和 Nuxt server 私有配置。
- 后端 service profile 的非密钥运行配置仍应通过 Nacos Data ID 管理；本地调试 service profile 时，也优先连接本机或测试 Nacos，而不是把 service 配置散落到多个 `.env.*` 文件。

### Symphony

`.env.symphony.local` 只放 Symphony 专用变量或覆盖项，例如 Linear API Key、Symphony/Codex provider 覆盖、临时实验开关。

加载顺序：

1. `.env.local`
2. `.env.symphony.local`

后者可以覆盖前者。后端数据库、Nacos、JWT issuer、前端后端地址等共享配置默认放 `.env.local`，不要重复维护在 `.env.symphony.local`。

### 后端部署

后端 service profile 的部署配置以 Nacos 为主。Spring Cloud Alibaba 2025.1.x 已不使用 `bootstrap.yml`，后端通过 `spring.config.import` 导入 Nacos 配置。

- Nacos 适合管理服务端非密钥配置，例如端口、数据库 JDBC URL、数据库用户名、JWT issuer、网关路由、服务治理和非敏感业务开关。
- 数据库密码、API Key、证书、令牌等密钥优先使用部署平台 Secret 或环境变量注入。
- Redis 地址、端口、database 和 timeout 属于非密钥配置，放 Nacos；Redis 密码和 PostgreSQL 密码一样属于密钥，通过服务启动配置中的环境变量或部署 Secret 注入，不写入 Nacos。
- Nacos 地址、Namespace、Group、Data ID 和 Nacos 登录凭据属于启动引导信息，通过环境变量或部署平台 Secret 注入。
- 如果未来决定把密钥放入 Nacos，必须先新增 ADR，说明 Nacos 权限、加密、审计、备份和轮换策略。
- Nacos 配置示例位于 `docs/config/nacos/`；示例中的地址、用户名和 issuer 均为占位，不代表真实部署值。

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
2. 通过环境变量或部署 Secret 注入 `NACOS_SERVER_ADDR`、`HDX_POSTGRES_PASSWORD`。
3. 启用 JWT 会话撤销时，通过环境变量或部署 Secret 注入 `HDX_REDIS_PASSWORD`。
4. 如果 Nacos 开启鉴权，注入 `NACOS_USERNAME`、`NACOS_PASSWORD`。

### 前端部署

前端不读取 Nacos。

Web 浏览器代码不得直接访问后端地址。浏览器调用同源 BFF/proxy 路径，例如 `/api/hdx/v1/**`。后端地址只能存在于 Nuxt server 私有 `runtimeConfig`、部署平台环境变量或反向代理配置中。

Nuxt SSR / 有 Nuxt server 时：

```text
浏览器 -> /api/hdx/v1/** -> Nuxt server -> HDX_BACKEND_BASE_URL -> backend-gateway
```

纯静态部署时：

```text
浏览器 -> /api/hdx/v1/** -> Nginx/网关反代 -> backend-gateway
```

## 变量分层

### 后端 service profile 环境变量

- `NACOS_SERVER_ADDR`：Nacos 地址。
- `NACOS_NAMESPACE`：Nacos Namespace；为空时使用 public namespace。
- `NACOS_USERNAME`：Nacos 用户名；只在 Nacos 开启鉴权时需要。
- `NACOS_PASSWORD`：Nacos 密码；只在 Nacos 开启鉴权时需要。
- `HDX_NACOS_GROUP`：Nacos Group，默认 `DEFAULT_GROUP`。
- `HDX_NACOS_DATABASE_DATA_ID`：后端数据库公共配置 Data ID，默认 `hdx-database.yml`。
- `HDX_NACOS_AUTH_DATA_ID`：`backend-auth-service` 读取的 Data ID，默认 `hdx-auth-service.yml`。
- `HDX_NACOS_CORE_DATA_ID`：`backend-core-service` 读取的 Data ID，默认 `hdx-core-service.yml`。
- `HDX_NACOS_GATEWAY_DATA_ID`：`backend-gateway` 读取的 Data ID，默认 `hdx-gateway.yml`。
- `HDX_NACOS_REDIS_DATA_ID`：公共 Redis 配置 Data ID，默认 `hdx-redis.yml`。
- `HDX_NACOS_DISCOVERY_IP`：服务注册到 Nacos 的可访问 IP；本地可填当前机器局域网 IP，云上优先由 Kubernetes Downward API、云主机 metadata 或部署脚本自动注入。
- `HDX_POSTGRES_PASSWORD`：PostgreSQL 默认密码。
- `HDX_AUTH_POSTGRES_PASSWORD`：可选，认证服务专用 PostgreSQL 密码；未设置时使用 `HDX_POSTGRES_PASSWORD`。
- `HDX_CORE_POSTGRES_PASSWORD`：可选，核心服务专用 PostgreSQL 密码；未设置时使用 `HDX_POSTGRES_PASSWORD`。
- `HDX_REDIS_PASSWORD`：Redis 密码。

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
- `spring.flyway.schemas` 和 `spring.flyway.default-schema`：认证中心迁移使用 `auth` schema。
- `hdx.gateway.routes.core-uri`：gateway 转发到 core-service 的目标地址。
- `hdx.gateway.routes.auth-uri`：gateway 转发到 auth-service 的目标地址。
- `hdx.security.jwt.revocation.enabled` 和 `hdx.security.jwt.revocation.key-prefix`：gateway JWT 会话撤销检查开关和 Redis key 前缀。
- 其他非密钥服务治理、Sentinel 和业务开关配置。

`backend-auth-service` 和 `backend-gateway` 的 service profile 本地启动配置会把 `spring.data.redis.password` 绑定到 `HDX_REDIS_PASSWORD`，与 core/auth 的 `spring.datasource.password` 绑定到 `HDX_POSTGRES_PASSWORD` 或模块专用密码保持一致。

如果某个模块需要单独数据库或用户名，可以在该模块 Data ID 中重新声明 `spring.datasource.url` 和 `spring.datasource.username`；模块配置会覆盖公共数据库配置。数据库密码仍不放入 Nacos，使用模块专用环境变量或 `HDX_POSTGRES_PASSWORD`。

### 后端 all-in-one

- `HDX_LOCAL_JDBC_URL`：desktop all-in-one 使用的 H2 JDBC URL。
- `HDX_LOCAL_DB_USERNAME`：all-in-one 本地数据库用户名。
- `HDX_LOCAL_DB_PASSWORD`：all-in-one 本地数据库密码。

### Web / BFF 环境变量

- `HDX_BACKEND_BASE_URL`：本地和部署统一使用的后端 gateway 基础地址。
- `NUXT_BACKEND_BASE_URL`：Nuxt 当前运行时读取的后端地址；本地加载脚本会在未显式设置时从 `HDX_BACKEND_BASE_URL` 派生。
- `NUXT_BACKEND_LOCAL_TOKEN_HEADER`：desktop all-in-one 本机令牌 header 名。
- `NUXT_BACKEND_LOCAL_TOKEN`：desktop all-in-one 本机令牌值。

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

如果当前 PowerShell 执行策略禁止运行本地脚本，可以只对本次命令使用 Bypass：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\load-env.ps1 -Path .env.example -ValidateOnly
```

## 约束

- 不提交 `.env.local`、`.env.symphony.local` 或任何真实密钥。
- 新增环境变量时必须同步更新 `.env.example` 和本文档。
- 新增后端 service profile 非密钥配置时，必须同步更新 `docs/config/nacos/` 示例和本文档。
- 面向浏览器的 public runtime config 不得包含真实后端内网地址、令牌、数据库配置或密钥。
- 部署环境使用同名变量或 Nacos 配置，不使用仓库内 `.env.local` 文件。
