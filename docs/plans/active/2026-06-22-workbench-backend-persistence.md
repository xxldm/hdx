# Web 工作台布局后端持久化

- 外部任务系统：无。
- 外部任务链接/编号：不适用。
- 外部任务是否为主计划来源：否。
- 当前状态：见下方 active plan 状态块。
- 计划来源：用户确认将 Web 工作台布局从 localStorage 主状态转向后端持久化。
- 创建时间：2026-06-22
- 最后更新：2026-06-22

<!-- active-plan-status:start -->
- 何时读取：修改 Web 首页工作台布局持久化、后端工作台状态 API、Nuxt BFF 或 layout localStorage 边界时。
- 当前状态：后端 `GET/PUT /api/v1/workbench/layout`、JPA/Flyway 持久化、Gateway OpenAPI、Web BFF、Zod schema 和 Pinia layout store 已接入；后端与 Web 子模块已分别提交，Web Online 不再读取 layout localStorage。
- 下一步：后续按真实登录闭环恢复未登录跳转，并重新验证未登录访问工作台的体验。
- 主要剩余风险：完整 native 编译因 GraalVM 25.1 前 release native 风险仍暂停；本轮仅完成 core-service/all-in-one Spring AOT 验证。
<!-- active-plan-status:end -->

## 目标

把 Web Online 首页工作台布局的主事实源切到后端接口：

- 页面加载时通过 Nuxt BFF 请求后端工作台布局。
- 保存布局时写入后端。
- 浏览器不直接访问后端地址，不保存敏感凭据。
- 未登录仍由登录守卫处理；接口不可用时显示不可用/空态和错误提示，不再悄悄回退默认布局。
- localStorage 不再作为 Web Online 的 layout 主存储，避免继续叠加临时迁移和 SSR hydration 问题。

## 非目标

- 本轮不新增独立 `backend-user-service` 或完整用户中心微服务；先遵循当前 `backend-core` 核心业务入口，新增清晰的 `workbench` 子域。
- 本轮不解决 Web 未登录跳转临时注释的完整认证闭环。
- 本轮不为 Desktop/App 设计离线草稿同步队列；Desktop 后续可在自身 BFF 或本地层单独接入缓存。
- 本轮不迁移计时器等 widget 自身业务状态；layout 只保存布局和显示偏好。

## repo 内范围

- `services/backend/backend-contract/`
- `services/backend/backend-core/`
- `services/backend/backend-core-service/`
- `services/backend/backend-gateway/`（主要通过 OpenAPI/验证覆盖，路由目前已代理 `/api/v1/**`）
- `apps/web/app/stores/workbench-layout.ts`
- `apps/web/app/types/hdx-api.ts`
- `apps/web/app/utils/hdx-api-client.ts`
- `apps/web/server/api/hdx/v1/`
- `packages/shared/generated/openapi/`
- `docs/plans/active/`

## 本地任务清单

- [x] 确认后端现有 core/tool/API/test 模式，并决定最小工作台持久化契约。
- [x] 在后端新增工作台布局 DTO、JPA 实体、Repository、Service、Controller 和 Flyway migration。
- [x] 为工作台布局读写、当前身份隔离、输入校验和不存在布局场景补测试。
- [x] 在 Web 新增工作台布局 Zod schema、BFF GET/PUT 路由和 hdx API client 方法。
- [x] 改造 Pinia layout store：加载/保存走后端，接口不可用进入错误态，不再读取 layout localStorage。
- [x] 更新页面空态/错误提示和相关单元测试。
- [x] 刷新 OpenAPI 快照和生成类型，运行相称质量门禁。

## 验收标准

- 刷新首页不会再先显示服务器默认布局再跳到 localStorage 用户布局。
- 后端无已保存布局时返回明确的初始化布局响应；后端不可用时 Web 显示不可用空态并保留错误提示。
- 工作台布局保存后，再次加载来自后端响应，而不是 localStorage。
- 后端按当前身份 `actorType + subject` 隔离工作台状态。
- 所有跨边界请求和响应都经过 Bean Validation 或 Zod schema 校验。

## 验证方式

- `mvn -pl :backend-core,:backend-core-service,:backend-gateway -am test`
- `pwsh -NoLogo -NoProfile -File scripts/openapi-refresh-snapshots.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/openapi-contract-check.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/openapi-generate-types.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/openapi-generate-types.ps1 -Check`
- `pwsh -NoLogo -NoProfile -File scripts/openapi-web-type-check.ps1`
- `pnpm test`
- `pnpm typecheck`
- `pnpm lint`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope changed -NoBuild -SkipDesktop`

## 风险与阻塞

- 当前登录守卫临时注释，未登录路径与工作台 API 的最终体验仍需认证闭环恢复后再收口。
- 如果后端接口不可用，Web 不能显示默认布局兜底，短期会比 localStorage 更“硬”，但符合让不可用状态显性的边界。
- OpenAPI 快照和生成类型会跨根仓库与后端/Web 子模块，提交顺序需要分开处理。

## 状态记录

- 2026-06-22：创建计划，当前状态为准备实现最小后端持久化切片。
- 2026-06-22：完成后端工作台布局持久化和 Web Online 接入。后端按 `actorType + subject` 隔离布局，未保存过布局时返回后端内置默认布局；接口失败时 Web store 使用空布局并显示错误，不再读取 layout localStorage。

## 验证结果

- 通过：`mvn -pl :backend-core,:backend-gateway -am '-Dtest=WorkbenchLayoutServiceTest,GatewayOpenApiDocumentationTest' '-Dsurefire.failIfNoSpecifiedTests=false' test`。
- 通过：`mvn -pl :backend-core,:backend-core-service,:backend-gateway -am test`。
- 通过：`mvn -pl :backend-core-service -am compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot -DskipTests`。
- 通过：`mvn -pl :backend-all-in-one -am compile org.springframework.boot:spring-boot-maven-plugin:4.0.0:process-aot -DskipTests`。
- 通过：`pnpm test`、`pnpm typecheck`、`pnpm lint`（`apps/web`）。
- 通过：`pwsh -NoLogo -NoProfile -File scripts/openapi-contract-check.ps1`。
- 通过：`pwsh -NoLogo -NoProfile -File scripts/openapi-generate-types.ps1 -Check`。
- 通过：`pwsh -NoLogo -NoProfile -File scripts/openapi-web-type-check.ps1`。
- 通过：`pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope changed -NoBuild -SkipDesktop`。

## 剩余风险

- 完整 GraalVM native 编译仍按 release native 计划暂停到 GraalVM 25.1 后复测；本轮只验证 Spring AOT。
- `auth.global.ts` 的未登录跳转仍处于此前临时注释状态，真实登录闭环恢复时需要重新验证未登录访问工作台的体验。

## 相关 commit

- `services/backend`：`f817204` 功能：持久化工作台布局。
- `apps/web`：`cde768a` 功能：接入工作台布局后端持久化。
- 根仓库：本次提交同步子模块指针、OpenAPI 生成物、契约检查脚本和 active plan。
