# OpenAPI 与 shared 层

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已创建计划并完成现状调研，等待确认 OpenAPI 生成策略与 `packages/shared` 首批职责。
- 计划来源：HDX 后续事项总纲第 5 步
- 创建时间：2026-06-07
- 最后更新：2026-06-07

## 目标

确定后端 OpenAPI、Web TypeScript 契约和 `packages/shared` 之间的职责边界，让 Web、后续 App 和 desktop 能通过稳定契约调用后端公开 API，而不是继续复制手写类型。

本计划完成后，仓库应明确：

- 后端公开 API 的契约事实源。
- 是否从 OpenAPI 生成 Web TypeScript 类型或 client。
- 生成产物放置位置、提交策略和验证方式。
- `packages/shared` 第一批职责，以及明确不放入其中的端侧实现。

## 非目标

- 本轮不直接引入 OpenAPI 生成器依赖，除非先补 ADR 并确认验证方式。
- 本轮不把仓库根目录升级为 pnpm workspace。
- 本轮不把 Web BFF、Nuxt server session、CSRF、UI store 或后端内部实现迁入 shared。
- 本轮不决定 App 技术栈，也不为 App 创建运行时 SDK。
- 本轮不改变认证、权限、JWT issuer、Redis 撤销或数据库迁移策略。

## repo 内范围

- `docs/plans/active/2026-06-07-openapi-shared-layer.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- 后续确认后可能涉及：
  - `docs/adr/`
  - `docs/ARCHITECTURE.md`
  - `packages/shared/`
  - `services/backend/README.md`
  - `services/backend/backend-contract/`
  - `apps/web/`

## 当前事实

- 后端已经引入 springdoc `3.0.3`。
- `backend-core-service`、`backend-all-in-one` 和 `backend-gateway` 当前依赖 `springdoc-openapi-starter-webmvc-ui`。
- `backend-core-service` 放行 `/v3/api-docs/**` 和 Swagger UI；`backend-gateway` 也放行 `/v3/api-docs/**`。
- `backend-auth-service` 当前没有引入 springdoc，第一方登录接口仍只通过 Java DTO、测试和文档记录契约。
- 后端 Java DTO 当前集中在 `services/backend/backend-contract/`，已覆盖 runtime、tools、auth login/refresh/logout/token、current actor 等响应与请求。
- Web 当前在 `apps/web/app/types/hdx-api.ts` 和 `apps/web/app/types/hdx-auth.ts` 手写 Zod schema 与 TypeScript 类型，并在 Nuxt server BFF 边界运行时校验后端响应。
- `packages/shared/` 当前只有 README 占位，没有包管理器、构建脚本、测试入口或可被 Web 引用的代码。
- 根架构文档允许 `apps/web/`、`apps/mobile/` 和 `services/backend/` 依赖 `packages/shared/`，但禁止 shared 依赖具体端。
- Web 架构 ADR 已明确：后续如果需要从后端 OpenAPI 生成 TypeScript client，需要新增或更新 ADR。

## 推荐方向草案

- 后端公开 REST API 以 OpenAPI 文档作为跨端契约事实源；Java `backend-contract` 仍是后端内部编译期 DTO 源。
- 先只生成 Web 需要的 TypeScript 类型和轻量请求函数，不生成会绕过 Nuxt server BFF 的浏览器直连 client。
- Web 浏览器继续只调用同源 `/api/hdx/v1/**`；生成 client 如用于 Web，应在 Nuxt server 边界或 BFF 内部使用。
- `packages/shared` 首批只放端无关、运行时无关的稳定协议资产，例如错误码、权限 code 常量、OpenAPI 生成类型或协议枚举；不放 Nuxt composable、Pinia store、Spring DTO、数据库模型或 HTTP token/session 处理。
- 生成产物应有清晰来源、命令和漂移检查；如果选择提交生成产物，提交前必须能复现生成结果。

## 本地任务清单

- [x] 读取约束、架构、质量、Git 和 ADR 入口文档。
- [x] 调研后端 OpenAPI 暴露方式、Java DTO 分布、Web 手写 schema 和 `packages/shared` 现状。
- [x] 创建本计划并记录当前事实、推荐方向、待确认事项和验证入口。
- [ ] 确认 OpenAPI 契约事实源：core-service、gateway 聚合、auth-service 分开暴露，还是按外部入口拆分多个 spec。
- [ ] 确认生成范围：只生成 TypeScript 类型、生成 Nuxt server client，或暂缓生成只加强契约测试。
- [ ] 确认生成工具和包管理边界；如新增依赖或根 workspace，先新增或更新 ADR。
- [ ] 确认 `packages/shared` 首批目录结构、职责清单和禁止内容。
- [ ] 实施确认后的最小切片，并更新架构文档、README、质量门禁和相关计划。
- [ ] 完成验证、提交并记录 commit。

## 待确认问题

- OpenAPI spec 是否应按外部入口拆分为 `auth-service` 与 `gateway/core` 两份，避免认证中心和业务网关的安全边界混在一起？
- `backend-auth-service` 是否需要补 springdoc，让账号密码登录、refresh 和 logout 也进入 OpenAPI 契约？
- Web 生成物是否只允许服务端使用，防止浏览器绕过 Nuxt BFF 直连后端？
- `packages/shared` 当前是否保持轻量源码包，还是等 App/Desktop 技术栈确认后再引入包管理和构建？
- 生成产物是否提交到仓库，还是由脚本在验证阶段生成并做漂移检查？

## 验收标准

- 本计划能让后续智能体从仓库恢复 OpenAPI/shared 的推进状态。
- 计划明确当前事实、非目标、待确认问题、推荐方向和验证入口。
- 总纲第 5 步状态已同步为进行中，并链接到本计划。
- 未在没有 ADR 的情况下引入新技术栈、包管理器、生成器或根 workspace。

## 验证方式

- `Get-Content -Path docs\plans\active\2026-06-07-openapi-shared-layer.md -Encoding UTF8`
- `Get-Content -Path docs\plans\active\2026-06-05-hdx-follow-up-roadmap.md -Encoding UTF8`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git status --short --branch`

## 风险与阻塞

- 如果直接生成浏览器 client，可能绕过现有 Nuxt BFF、HttpOnly session 和 CSRF 边界。
- 如果过早把 `packages/shared` 做成工作区包，可能迫使根仓库提前绑定包管理器，违反当前 Web 只在 `apps/web/` 使用 pnpm 的约束。
- 如果不把 auth-service 纳入 OpenAPI，Web 登录契约仍会继续手写并存在漂移风险。
- 如果只依赖 OpenAPI 静态类型而取消 Web Zod 运行时校验，会削弱跨边界数据解析约束。

## 状态记录

- 2026-06-07：用户确认进入第 5 步；已创建本地计划并完成现状调研，等待确认 OpenAPI 生成策略与 shared 首批职责。

## 验证结果

- 已使用 `Get-Content -Encoding UTF8` 读取约束、架构、质量、Git、ADR 和计划模板文档。
- 已使用 `rg` 调研后端 springdoc、OpenAPI、Web schema 和 `packages/shared` 现状。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过；关键文档 UTF-8 读取和根仓库空白检查均通过。
- `git status --short --branch`：确认本轮只修改根仓库计划文档，未修改子模块内容。

## 剩余风险

- 尚未确认是否引入 OpenAPI 生成器，因此不能开始修改 Web 契约来源。
- 尚未确认 `packages/shared` 是否创建可安装包，因此不能开始调整依赖方向检查。
- 当前 Web 仍维护手写 Zod schema；在生成策略落地前，Web/后端契约仍存在人工同步成本。

## 相关 commit

- 待记录。
