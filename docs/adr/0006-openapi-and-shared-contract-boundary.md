# ADR 0006：OpenAPI 与 shared 契约边界

- 日期：2026-06-07
- 状态：已接受

## 背景

HDX 后端已经形成 `backend-auth-service`、`backend-gateway`、`backend-core-service` 和 `backend-all-in-one` 的第一阶段拓扑。Web 端已经通过 Nuxt server BFF 调用后端公开 API，并在 `apps/web/app/types/` 中手写 Zod schema 与 TypeScript 类型。

随着认证、当前身份和工具目录接口增加，继续由 Web 手写所有契约会带来漂移风险。与此同时，Web 浏览器不能直接访问后端地址，access token 和 refresh token 必须留在 Nuxt server 私有边界内，因此不能为了生成 client 破坏现有 BFF、HttpOnly session 和 CSRF 边界。

本决策影响后端 OpenAPI 暴露方式、Web 契约同步方式和 `packages/shared` 的首批职责。

## 决策

- 后端公开 REST API 以 OpenAPI 文档作为跨端契约事实源之一；后端内部 Java 编译期契约仍由 `services/backend/backend-contract/` 承载。
- OpenAPI spec 按外部入口拆分：
  - `backend-auth-service` 暴露认证中心契约，其中第一方登录、刷新和登出进入 OpenAPI；OIDC discovery 与 JWK 继续按 Authorization Server 标准端点暴露。
  - `backend-gateway` 暴露服务端业务入口契约。
  - `backend-core-service` 和 `backend-all-in-one` 可以保留自身 `/v3/api-docs` 作为调试与本机集成参考，但不替代外部入口契约。
- `backend-auth-service` 补齐 springdoc OpenAPI 暴露；`/v3/api-docs/**` 和 Swagger UI 与登录、刷新、登出一样允许匿名访问。
- 当前阶段不引入 OpenAPI TypeScript 生成器，不创建根 pnpm workspace，不把 `packages/shared` 做成可安装包。
- Web 浏览器继续只调用同源 `/api/hdx/v1/**`。未来如果生成 TypeScript 类型或轻量 client，默认只允许在 Nuxt server BFF 边界内使用，不生成或使用会让浏览器直连后端的 client。
- Web 运行时边界校验继续保留 Zod。OpenAPI 静态类型不能替代跨边界数据解析。
- `packages/shared` 首批只允许承载端无关、运行时无关的稳定协议资产，例如错误码、权限 code 常量、协议枚举和后续确认的生成类型；不得放入 Nuxt composable、Pinia store、Spring DTO、数据库模型、HTTP token/session 处理或平台 API 适配。

## 备选方案

- 立即引入 OpenAPI 生成器并生成 Web client：可以更快减少手写类型，但会引入新依赖和生成物策略，也容易生成浏览器直连后端的 client，当前先不选。
- 将 `packages/shared` 立即升级为 TypeScript workspace 包：未来共享更方便，但会提前把根仓库绑定到 JS 包管理边界，违反当前 Web 只在 `apps/web/` 使用 pnpm 的约束。
- 只保留 Java DTO，不暴露 auth-service OpenAPI：后端编译期简单，但 Web 登录契约仍依赖人工同步，漂移风险较高。
- 通过 gateway 聚合所有 OpenAPI：对外入口统一，但当前认证中心与业务网关是同级入口，强行聚合容易混淆 issuer、登录和资源访问安全边界。

## 影响范围

- `services/backend/backend-auth-service/` 增加 springdoc OpenAPI 依赖、匿名文档端点和最小 OpenAPI 文档测试。
- `docs/ARCHITECTURE.md` 需要记录 OpenAPI 入口拆分与 shared 层边界。
- `services/backend/README.md` 需要记录 auth-service OpenAPI 文档入口。
- `docs/plans/active/2026-06-07-openapi-shared-layer.md` 需要同步本决策状态和剩余风险。
- 后续 Web 类型生成或 shared 包结构调整必须以本 ADR 为约束；如果需要引入生成器或根 workspace，需要补充 ADR。

## 验证方式

- 后端验证：`mvn -pl :backend-auth-service -am test`，覆盖 auth-service OpenAPI 文档包含第一方登录、刷新和登出接口。
- 文档验证：`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`。
- 后续如果引入生成器，需要新增生成命令、漂移检查和 Web 契约测试。

## 后续补充

- 2026-06-07：`backend-gateway` 通过 OpenAPI customizer 显式声明当前对外代理的 `/api/v1/auth/current`、`/api/v1/runtime` 和 `/api/v1/tools` 业务路径；根仓库提交 `packages/shared/contracts/openapi/snapshots/` 作为外部入口 spec 快照，并通过 `scripts/openapi-contract-check.ps1` 做路径级漂移检查。

## 回滚条件

- springdoc 在 `backend-auth-service` 中导致无法接受的启动、AOT 或 native-image 问题，且无法通过 Spring AOT、RuntimeHints 或最小配置修复。
- 后续部署确认认证中心 OpenAPI 不应公开匿名访问，需要改为内网或受控文档入口。
- 后续统一 API 门户或网关聚合能力成熟后，可以用新的 ADR 替代本拆分策略。

回滚时移除 `backend-auth-service` 的 springdoc 依赖、OpenAPI 匿名放行和相关测试，并在架构文档中恢复为仅 core/gateway 暴露 OpenAPI。

## 后续事项

- 评估是否为 `backend-gateway` 提供只包含外部业务路径的稳定 OpenAPI spec。
- 评估 OpenAPI 生成 TypeScript 类型的工具、生成物提交策略和漂移检查。
- 明确 `packages/shared` 的最小目录结构和第一批协议资产。
- 将 Web 手写 Zod schema 与 OpenAPI schema 的漂移检查纳入后续质量门禁。
