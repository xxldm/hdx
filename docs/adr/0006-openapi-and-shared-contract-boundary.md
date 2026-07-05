# ADR 0006：OpenAPI 与 shared 契约边界

- 日期：2026-06-07
- 状态：已接受
- 修订：2026-07-05 收敛为公开契约边界；后端模块名/服务名不敏感，内部拓扑、调用链和实现契约以后端私有文档为准。

## 背景

HDX 后端已经形成认证入口、业务入口、内部业务服务和 Desktop Full 本机后端等第一阶段运行形态。Web 端已经通过 Nuxt server BFF 调用后端公开 API，并在 `apps/web/app/types/` 中手写 Zod schema 与 TypeScript 类型。

随着认证、当前身份和工具目录接口增加，继续由 Web 手写所有契约会带来漂移风险。与此同时，Web 浏览器不能直接访问后端地址，access token 和 refresh token 必须留在 Nuxt server 私有边界内，因此不能为了生成 client 破坏现有 BFF、HttpOnly session 和 CSRF 边界。

本决策影响后端 OpenAPI 暴露方式、Web 契约同步方式和 `packages/shared` 的首批职责。

## 决策

- 后端公开 REST API 以 OpenAPI 文档作为跨端契约事实源之一；后端内部 Java 编译期契约、职责拆分和调用关系由后端私有文档维护。
- OpenAPI spec 按外部入口拆分：
  - 后端认证入口暴露认证中心契约，其中第一方登录、刷新和登出进入 OpenAPI；OIDC discovery 与 JWK 继续按 Authorization Server 标准端点暴露。
  - 后端业务入口暴露服务端业务入口契约。
  - 后端内部服务和 Desktop Full 本机后端不作为外部 OpenAPI 事实源，默认不提供运行时文档入口。
- 后端认证入口和业务入口的 OpenAPI 契约由测试期 springdoc 生成快照；生产和 release native 运行时不暴露 `/v3/api-docs` 或 Swagger UI，不把 springdoc 放入启动器 runtime classpath。
- 当前阶段不引入 OpenAPI TypeScript 生成器，不创建根 pnpm workspace，不把 `packages/shared` 做成可安装包。
- Web 浏览器继续只调用同源 `/api/hdx/v1/**`。未来如果生成 TypeScript 类型或轻量 client，默认只允许在 Nuxt server BFF 边界内使用，不生成或使用会让浏览器直连后端的 client。
- Web 运行时边界校验继续保留 Zod。OpenAPI 静态类型不能替代跨边界数据解析。
- `packages/shared` 首批只允许承载端无关、运行时无关的稳定协议资产，例如错误码、权限 code 常量、协议枚举和后续确认的生成类型；不得放入 Nuxt composable、Pinia store、Spring DTO、数据库模型、HTTP token/session 处理或平台 API 适配。

## 备选方案

- 立即引入 OpenAPI 生成器并生成 Web client：可以更快减少手写类型，但会引入新依赖和生成物策略，也容易生成浏览器直连后端的 client，当前先不选。
- 将 `packages/shared` 立即升级为 TypeScript workspace 包：未来共享更方便，但会提前把根仓库绑定到 JS 包管理边界，违反当前 Web 只在 `apps/web/` 使用 pnpm 的约束。
- 只保留 Java DTO，不暴露认证入口 OpenAPI：后端编译期简单，但 Web 登录契约仍依赖人工同步，漂移风险较高。
- 通过业务入口聚合所有 OpenAPI：对外入口统一，但当前认证中心与业务入口是同级入口，强行聚合容易混淆 issuer、登录和资源访问安全边界。

## 影响范围

- 后端私有仓库使用 test-scope springdoc 生成认证入口和业务入口 OpenAPI 快照，不在生产运行时保留文档端点。
- `docs/ARCHITECTURE.md` 需要记录 OpenAPI 入口拆分与 shared 层边界。
- `services/backend/README.md` 需要记录 OpenAPI 只在测试期生成契约，不作为生产文档入口。
- `docs/plans/completed/2026-06-07-openapi-shared-layer.md` 已同步本决策状态和剩余风险。
- 后续 Web 类型生成或 shared 包结构调整必须以本 ADR 为约束；如果需要引入生成器或根 workspace，需要补充 ADR。

## 验证方式

- 后端验证：以后端私有文档中的 OpenAPI 快照生成测试为准，覆盖认证入口 OpenAPI 文档包含第一方登录、刷新和登出接口。
- 文档验证：`pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`。
- 后续如果引入生成器，需要新增生成命令、漂移检查和 Web 契约测试。

## 后续补充

- 2026-06-07：后端业务入口通过 OpenAPI customizer 显式声明当前对外代理的 `/api/v1/auth/current`、`/api/v1/runtime` 和 `/api/v1/tools` 业务路径；根仓库提交 `packages/shared/contracts/openapi/snapshots/` 作为外部入口 spec 快照，并通过 `scripts/openapi-contract-check.ps1` 做路径级漂移检查。
- 2026-06-07：在不引入 TypeScript 生成器的前提下，根仓库新增 `expected-schemas.json`，对 Web 当前依赖的 auth token/user、runtime、current actor 和 tools 关键字段做 schema 级漂移检查；后端业务入口 OpenAPI customizer 同步补齐这些外部业务 DTO 的最小 schema。
- 2026-06-07：新增 ADR 0007，确认下一阶段只允许从 OpenAPI 生成 TypeScript 类型，不生成完整 API client，不升级根 pnpm workspace，并继续保留 Web Zod 运行时边界校验。
- 2026-07-04：生产自用场景不需要运行时 API 文档入口，OpenAPI 改为测试期契约生成能力；后端认证入口和业务入口的 OpenAPI 配置移入测试范围，springdoc 改为 test-scope 依赖，release native 不再携带 springdoc、Swagger UI 或 WebJars。

## 回滚条件

- springdoc 在测试期契约生成中导致无法接受的维护成本，且无法通过最小配置修复。
- 后续部署确认必须在线提供 OpenAPI 文档入口，需要新增受控文档 profile 或专用文档服务，不直接把 springdoc 恢复进默认 release native。
- 后续统一 API 门户或网关聚合能力成熟后，可以用新的 ADR 替代本拆分策略。

回滚时需要明确恢复方式：如果只是不再使用 OpenAPI 契约生成，则移除测试期 springdoc 依赖和相关契约测试；如果需要恢复在线文档入口，则新增受控文档 profile 或专用文档服务，并在安全链、架构文档和 native 验证中单独记录。

## 后续事项

- 评估是否为后端业务入口提供只包含外部业务路径的稳定 OpenAPI spec。
- 按 ADR 0007 评估只生成 TypeScript 类型的工具、生成物提交策略和漂移检查。
- 明确 `packages/shared` 的最小目录结构和第一批协议资产。
- 将 Web 手写 Zod schema 与 OpenAPI schema 的漂移检查纳入后续质量门禁。
