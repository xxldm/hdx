# 环境配置

本文档定义 HDX 公开主仓库可维护的环境配置分层。主仓库只保留跨端入口、本地开发入口、前端/BFF 变量和公开发布相关环境边界；Nacos、Redis、PostgreSQL 等外部工具可以作为部署准备和环境依赖出现。后端模块名、服务名和 Nacos Data ID 不作为敏感内容，允许出现在部署模板中；内部接入方式、公共工具模块职责拆分、调用链和后端部署验证记录默认维护在后端私有子模块 `services/backend/README.md` 与 `services/backend/docs/README.md`。

## 配置分层

### 本地开发

根目录 `.env.local` 是本机开发的统一配置源，供手动 PowerShell、Codex Desktop、IDE 启动前环境、Symphony 启动脚本等本机场景复用。

- `.env.local` 不提交。
- `.env.example` 是可提交模板，不包含真实密钥。
- `.env.example` 修改后必须按模板原有分组和相邻位置同步 `.env.local` 的文件结构，不能简单追加到文件末尾；变量键保持一致但真实值可不同。
- 对 `.env.local` 新增变量不需要用户事前同意，完成后必须提示用户填写真实值；修改或删除 `.env.local` 已有变量前必须主动请求用户确认。
- 本地脚本应优先读取 `.env.local`。
- 如果某个工具有专属覆盖文件，应在读取 `.env.local` 后再读取专属文件。
- 本地 `.env.local` 可以保存 Nacos 地址、Nacos 登录凭据、数据库密码、Redis 密码、Desktop Full 本机库覆盖项和 Nuxt server 私有配置。
- `.env.example` 默认只让必须显式维护或高频变化的变量保持活跃；已有代码默认值的覆盖项以注释形式保留，需要改默认值时再取消注释。

### Symphony

`.env.symphony.local` 只放 Symphony 专用变量或覆盖项，例如 Linear API Key、Symphony/Codex provider 覆盖、临时实验开关。

`.env.symphony.example` 修改后必须按模板原有分组和相邻位置同步 `.env.symphony.local` 的文件结构，不能简单追加到文件末尾。新增变量不需要用户事前同意，完成后提示用户填写真实值；修改或删除 `.env.symphony.local` 已有变量前必须主动请求用户确认。

加载顺序：

1. `.env.local`
2. `.env.symphony.local`

后者可以覆盖前者。后端数据库、Nacos、JWT issuer、前端后端地址等共享配置默认放 `.env.local`，不要重复维护在 `.env.symphony.local`。

### 后端部署

后端 service profile 的部署配置以 Nacos、环境变量和部署平台 Secret 为主。公开主仓库只保留这些跨仓库规则：

- 数据库密码、API Key、证书、令牌等密钥优先使用部署平台 Secret 或环境变量注入。
- Nacos 地址、Namespace 和登录凭据属于启动引导信息，通过环境变量或部署平台 Secret 注入。
- 如果未来决定把密钥放入 Nacos，必须先新增 ADR，说明 Nacos 权限、加密、审计、备份和轮换策略。
- Nacos 配置示例位于 `docs/config/nacos/`；示例中的地址、用户名和 issuer 均为占位，不代表真实部署值。
- 修改 `docs/config/nacos/` 下的 Nacos 模板后，必须按模板原有层级和相邻位置同步真实 Nacos Data ID。新增配置项可以直接补到 Nacos 并在完成后通知用户；修改或删除已有配置项必须先征得用户同意。URL、issuer、内网地址等模板占位值不能自动猜测真实值，必须提示用户手动修改；发布操作人规则见 `docs/config/nacos/README.md`。

后端 Data ID 和服务名可以在公开模板中出现；具体 service profile 导入顺序、服务端单体、本机模式、数据库/Redis 接入方式、native/AOT 和部署验证细节不在本文展开。需要修改这些内容时，先读 `services/backend/README.md` 与 `services/backend/docs/README.md`。

### 前端部署

前端不读取 Nacos。

Web 浏览器代码不得直接访问后端地址。浏览器调用同源 BFF/proxy 路径，例如 `/api/hdx/v1/**`。后端业务入口地址和认证中心地址只能存在于 Nuxt server 私有 `runtimeConfig`、部署平台环境变量或反向代理配置中。

Nuxt SSR / 有 Nuxt server 时：

```text
业务请求：浏览器 -> /api/hdx/v1/** -> Nuxt server -> HDX_BACKEND_BASE_URL -> 后端业务入口
认证请求：浏览器 -> /api/hdx/v1/auth/** -> Nuxt server -> HDX_AUTH_BASE_URL -> 后端认证入口
```

纯静态部署时：

```text
业务请求：浏览器 -> /api/hdx/v1/** -> Nginx/网关反代 -> 后端业务入口
认证请求：浏览器 -> /api/hdx/v1/auth/** -> Nginx/网关反代 -> 后端认证入口
```

## 变量分层

本地开发建议保持最小活跃变量：`NACOS_SERVER_ADDR`、`NACOS_NAMESPACE`、`NACOS_USERNAME`、`NACOS_PASSWORD`、`HDX_POSTGRES_PASSWORD`、启用 Redis 时的 `HDX_REDIS_PASSWORD`、`HDX_BACKEND_BASE_URL`、`HDX_AUTH_BASE_URL` 和 `NUXT_AUTH_SESSION_SECRET`。

Nacos Namespace 和鉴权必须按环境确认，空值只代表 public namespace 或未开启鉴权。后端 Data ID、认证中心初始化管理员、服务端单体变量、Desktop Full 本机数据库、Web cookie 名称、CSRF header、cookie secure、session 时长和 refresh 提前量都有默认值或只在特定场景需要，模板中默认保留为注释覆盖项。

### 后端环境变量

公开主仓库只维护后端环境变量的分层原则，不复制完整变量表：

- 启动引导：Nacos 地址、Namespace、用户名和密码。
- 密钥：数据库密码、Redis 密码、初始化管理员密码、证书和令牌。
- 本机模式：Desktop Full 本机数据库覆盖项。
- 服务端部署：具体 service profile、Nacos Data ID 和服务端单体变量。

完整变量表和验证方式以后端私有文档为准。新增或调整后端变量时，只在公开主仓库同步 `.env.example` 中必要的跨仓库模板和本文的入口说明，不把后端内部配置表复制到本文。

### Web / BFF 环境变量

- `HDX_BACKEND_BASE_URL`：本地和部署统一使用的后端业务入口基础地址；Nuxt server 未设置 `NUXT_BACKEND_BASE_URL` 时会直接读取它。
- `NUXT_BACKEND_BASE_URL`：可选覆盖项，Nuxt 当前运行时读取的后端业务入口地址；只在 Web 需要使用不同于 `HDX_BACKEND_BASE_URL` 的地址时设置。
- `HDX_AUTH_BASE_URL`：本地和部署统一使用的认证中心基础地址；Nuxt server 未设置 `NUXT_AUTH_BASE_URL` 时会直接读取它。
- `NUXT_AUTH_BASE_URL`：可选覆盖项，Nuxt 当前运行时读取的认证中心地址；只在 Web 需要使用不同于 `HDX_AUTH_BASE_URL` 的地址时设置。
- `NUXT_BACKEND_LOCAL_TOKEN_HEADER`：可选，Desktop Full 本机令牌 header 名。
- `NUXT_BACKEND_LOCAL_TOKEN`：可选，Desktop Full 本机令牌值。
- `NUXT_AUTH_SESSION_COOKIE_NAME`：可选覆盖项，Web 加密 `HttpOnly` session cookie 名，默认 `hdx_web_session`。
- `NUXT_AUTH_SESSION_SECRET`：Web session 加密/签名密钥，至少 32 字符；真实环境必须稳定注入，Nuxt 重启后依靠它从 cookie 恢复登录态。
- `NUXT_AUTH_CSRF_COOKIE_NAME`：可选覆盖项，Web CSRF cookie 名，默认 `hdx_csrf`。
- `NUXT_AUTH_CSRF_HEADER_NAME`：可选覆盖项，Web 状态变更请求使用的 CSRF header 名，默认 `X-HDX-CSRF`。
- `NUXT_AUTH_COOKIE_SECURE`：可选覆盖项，Web auth cookie 是否带 `Secure`；默认在生产环境为 `true`，其他环境为 `false`。
- `NUXT_AUTH_SESSION_MAX_AGE_SECONDS`：可选覆盖项，Web session cookie 滑动有效期，默认 `604800` 秒。
- `NUXT_AUTH_REFRESH_SKEW_SECONDS`：可选覆盖项，Web BFF 在 access token 距离过期多少秒内提前 refresh，默认 `60` 秒。

Web 不提供访客模式。远程服务模式下，登录态由 Nuxt server 保存到加密 `HttpOnly` cookie session；浏览器不能读取 access token 或 refresh token，只通过同源 BFF 接口访问 session、login、refresh 和 logout。

Nuxt server 的业务 API 请求走 `HDX_BACKEND_BASE_URL` 指向后端业务入口，认证 API 请求走 `HDX_AUTH_BASE_URL` 指向认证中心。后端 refresh token 仍是滑动不活跃窗口的事实源；BFF 触发 refresh 后会轮换后端 refresh token，并重写 Web session cookie。

Desktop Full 模式通过 `NUXT_BACKEND_LOCAL_TOKEN_HEADER` 和 `NUXT_BACKEND_LOCAL_TOKEN` 判断。该模式永远视为已登录，不展示登录页，不要求输入账号密码。

Desktop Full 发布包不再通过 Nuxt server 子进程读取上述 `NUXT_BACKEND_LOCAL_TOKEN_*` 变量。Desktop 静态 Web UI 通过 Tauri command 调用 Rust BFF，Rust 主进程从 sidecar 读取本机 token 并只在 Rust 边界内使用。

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
