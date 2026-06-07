# OpenAPI 与 shared 层

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已接受 OpenAPI/shared 契约边界 ADR；`backend-auth-service` 已补齐 OpenAPI 暴露与最小文档测试；`packages/shared` 已建立轻量目录骨架；已确认当前暂不生成 TypeScript 类型；已新增 OpenAPI 路径级契约检查入口，下一步补真实 spec 快照或抓取流程。
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
- 当前 Web 手写契约面较小，主要覆盖 runtime、tools、auth token/session 三类；直接引入生成器的包管理和边界成本暂时高于收益。
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
- [x] 确认 OpenAPI 契约事实源：按外部入口拆分 `backend-auth-service` 与 `backend-gateway`，core-service/all-in-one 文档只作调试和本机集成参考。
- [x] 确认本轮生成范围：暂不引入 TypeScript 生成器，不生成浏览器直连后端 client，先补齐 auth-service OpenAPI。
- [x] 确认生成工具和包管理边界：本轮不引入生成器、不创建根 pnpm workspace；后续如新增生成器需补充 ADR 或更新本 ADR。
- [x] 确认 `packages/shared` 首批职责边界：仅放端无关、运行时无关的稳定协议资产，禁止放端侧状态、UI、HTTP token/session 和后端内部模型。
- [x] 建立 `packages/shared` 轻量目录骨架：`contracts/`、`constants/`、`generated/` 和 `tools/`，只放 README 占位，不引入包管理器或运行时代码。
- [x] 确认 TypeScript 生成策略：当前暂不生成类型或 client，下一步先做 OpenAPI spec 快照与漂移检查，等契约面扩大后再评估生成器。
- [x] 建立 OpenAPI 路径级契约检查入口：新增 `packages/shared/contracts/openapi/expected-paths.json` 和 `scripts/openapi-contract-check.ps1`。
- [x] 实施确认后的最小切片，并更新架构文档、README 和相关计划。
- [x] 完成验证、提交并记录 commit。

## 待确认问题

- OpenAPI spec 是否应按外部入口拆分为 `auth-service` 与 `gateway/core` 两份，避免认证中心和业务网关的安全边界混在一起？
- `backend-auth-service` 是否需要补 springdoc，让账号密码登录、refresh 和 logout 也进入 OpenAPI 契约？
- Web 生成物是否只允许服务端使用，防止浏览器绕过 Nuxt BFF 直连后端？
- `packages/shared` 当前是否保持轻量源码包，还是等 App/Desktop 技术栈确认后再引入包管理和构建？
- 生成产物是否提交到仓库，还是由脚本在验证阶段生成并做漂移检查？
- 当前是否应该直接引入 TypeScript 类型生成器？

已确认答案：

- OpenAPI spec 按外部入口拆分，认证中心和业务入口不强行聚合。
- `backend-auth-service` 需要补 springdoc，并暴露 `/v3/api-docs/**` 和 Swagger UI。
- Web 生成物后续默认只允许在 Nuxt server BFF 边界使用，浏览器不得绕过 BFF 直连后端。
- `packages/shared` 当前不升级为根 workspace 包；先保留轻量边界，只在后续确认首批协议资产后实施。
- 本轮不生成产物；后续如选择提交生成产物，必须有可复现命令和漂移检查。
- 当前不直接引入 TypeScript 类型生成器。下一步先捕获 auth-service 与 gateway/core 外部入口 OpenAPI spec 快照，建立手写 Zod schema 与 OpenAPI schema 的漂移检查入口。
- 已先建立路径级契约检查入口。当前无真实 spec 快照时只校验期望路径清单格式；提供 spec 文件后会校验 `paths` 中包含 Web/BFF 已依赖路径。

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
- 2026-06-07：新增 ADR 0006，确认 OpenAPI 按外部入口拆分；本轮暂不引入 TypeScript 生成器或根 pnpm workspace。
- 2026-06-07：`backend-auth-service` 补齐 springdoc OpenAPI 暴露，并新增测试验证 `/v3/api-docs` 包含登录、刷新和登出接口。
- 2026-06-07：`packages/shared` 建立轻量骨架，明确 `contracts/`、`constants/`、`generated/` 和 `tools/` 的候选职责与禁止内容；当前仍不创建可安装包。
- 2026-06-07：调研 Web 手写契约面，确认当前 runtime、tools、auth token/session 的 schema 数量仍小；本阶段不引入 TypeScript 生成器，下一步优先设计 OpenAPI spec 快照与漂移检查。
- 2026-06-07：新增 `scripts/openapi-contract-check.ps1` 与 `packages/shared/contracts/openapi/expected-paths.json`，先做无依赖路径级契约检查；真实 spec 快照和 schema 级漂移检查后续补齐。

## 验证结果

- 已使用 `Get-Content -Encoding UTF8` 读取约束、架构、质量、Git、ADR 和计划模板文档。
- 已使用 `rg` 调研后端 springdoc、OpenAPI、Web schema 和 `packages/shared` 现状。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过；关键文档 UTF-8 读取和根仓库空白检查均通过。
- `git status --short --branch`：确认本轮包含根仓库文档变更和 `services/backend` 子模块变更，未修改 Web 或 desktop 子模块。
- 本轮首次执行 `mvn -pl :backend-auth-service -am test` 失败，原因是测试使用了 Spring Boot 4 当前不可用的旧 `TestRestTemplate` 包；已改为 `MockMvc`。
- `mvn -pl :backend-auth-service -am test`：通过，覆盖 14 个测试，新增验证 auth-service `/v3/api-docs` 包含 `/api/auth/login`、`/api/auth/refresh` 和 `/api/auth/logout`。
- `mvn -pl :backend-auth-service -am compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot`：通过，验证 auth-service 增加 springdoc 后的 Spring AOT 入口。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，验证根仓库关键文档 UTF-8 读取和空白检查。
- `mvn test`：通过，覆盖后端 7 个 Maven 模块、32 个测试，确认 auth-service OpenAPI 依赖未破坏 core、gateway 和 all-in-one 既有测试。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，验证 `packages/shared` 轻量骨架、架构文档和本计划更新后的 UTF-8 读取与空白检查。
- 已使用 `rg` 和 `Get-Content` 调研 Web BFF 路由、Web Zod schema、后端 controller/DTO 与 `apps/web/package.json`；确认当前不需要新增生成器依赖即可继续推进契约漂移检查设计。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/openapi-contract-check.ps1`：通过，校验 OpenAPI 期望路径清单 JSON 格式、路径前缀和重复路径。

## 剩余风险

- 当前已确认暂不引入 OpenAPI 生成器；后续仍需评估 TypeScript 类型生成工具和生成物提交策略。
- 尚未建立 OpenAPI spec 快照、漂移检查脚本或 CI 入口；Web 手写 Zod schema 与后端 OpenAPI 仍需要人工同步。
- 尚未建立真实 OpenAPI spec 快照、自动抓取流程、schema 级漂移检查或 CI 入口；当前脚本只是路径级最小检查。
- 当前已确认 `packages/shared` 暂不创建根 workspace 包；后续仍需确认第一批真实协议资产和消费者。
- 当前 Web 仍维护手写 Zod schema；在生成策略落地前，Web/后端契约仍存在人工同步成本。
- 调研时发现部分 Web 端中文错误提示在源码中已呈现乱码，应另行作为 Web 文案编码缺陷处理；本轮不顺手修改 Web 运行时代码。
- auth-service 已补 OpenAPI 与 Spring AOT 验证，但本轮未运行完整 native-image 编译和真实 service profile OpenAPI 端点手工访问。

## 相关 commit

- `fed17f9 功能：补齐认证服务 OpenAPI 文档`（`services/backend`）
- `5e84f5d 杂项：记录 OpenAPI shared 契约边界`（根仓库）
- 本计划收尾记录提交由 Git 历史体现，不再回写避免递归提交。
