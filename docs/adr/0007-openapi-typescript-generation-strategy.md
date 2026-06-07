# ADR 0007：OpenAPI TypeScript 类型生成策略

- 日期：2026-06-07
- 状态：已接受

## 背景

ADR 0006 已确认后端公开 REST API 以 OpenAPI 作为跨端契约事实源之一，并按外部入口拆分 `backend-auth-service` 与 `backend-gateway`。根仓库也已经建立 OpenAPI 快照、路径级漂移检查和关键字段级 schema 漂移检查。

Web 端当前仍在 `apps/web/app/types/` 手写 Zod schema 与 TypeScript 类型，并在 Nuxt server BFF 边界校验后端响应。随着认证、当前身份、运行时信息和工具目录接口继续增加，继续完全手写 TypeScript 类型会产生重复维护成本。但如果过早生成完整 API client，容易绑定请求库、鉴权、错误处理、缓存策略和浏览器直连后端的调用形态，反而破坏既有 BFF、HttpOnly cookie session 和 CSRF 边界。

因此需要先确定 OpenAPI 到 TypeScript 的最小生成策略，给后续工具选择和实现留出清晰边界。

## 决策

- 第一阶段只允许从 OpenAPI 生成 TypeScript 类型，不生成完整 API client。
- 生成类型的目标是减少手写 TypeScript 结构漂移；它不能替代 Web 边界处的 Zod 运行时解析。
- 生成产物的候选落点为 `packages/shared/generated/`，但在工具、命令、输出结构和漂移检查未落地前，当前仍不提交真实生成物。
- 生成输入优先使用根仓库已提交的外部入口 OpenAPI 快照：
  - `packages/shared/contracts/openapi/snapshots/auth-service.openapi.json`
  - `packages/shared/contracts/openapi/snapshots/gateway.openapi.json`
- 生成脚本必须可重复执行，并提供漂移检查；提交生成物前必须能证明生成结果与已提交快照一致。
- Web 浏览器代码不得使用生成物绕过 Nuxt server BFF 直连后端。未来如果生成的类型被 Web 使用，默认只作为端无关协议类型，或在 Nuxt server BFF 内部辅助约束请求与响应。
- 当前不把根仓库升级为 pnpm workspace，不把 `packages/shared` 立即做成可安装包。若生成工具必须引入包管理或构建边界，优先放在既有 Web 工程的开发工具链中，生成产物仍遵守 shared 边界；如果需要改变根仓库包管理方式，必须新增独立 ADR 说明原因。
- 生成类型不得引入 Nuxt、Pinia、Vue、Spring、JPA、数据库模型、token/session 处理或平台适配逻辑。

## 备选方案

- 继续只维护手写 Zod 与 `expected-schemas.json`：侵入最小，但 TypeScript 类型仍需要人工同步，契约面扩大后重复成本会上升。
- 立即生成完整 API client：短期减少接口调用样板，但会提前固定请求库、鉴权注入、错误封装和缓存策略，也容易让浏览器绕过 BFF 直连后端。
- 将 `packages/shared` 升级为根 workspace 包并发布内部包：长期消费体验更好，但会提前改变根仓库包管理边界，当前收益不足以覆盖成本。
- 从后端 Java DTO 直接生成 TypeScript：能减少 OpenAPI 中间层，但会让前端契约耦合后端内部模块，违背公开契约边界。

## 影响范围

- `packages/shared/generated/`：作为后续 TypeScript 类型生成产物候选落点，继续禁止无来源、无命令、无漂移检查的生成物。
- `packages/shared/contracts/openapi/`：继续作为第一阶段生成输入和漂移检查事实源。
- `apps/web/`：后续可以逐步引用生成类型辅助编译期检查，但必须保留 Zod 运行时解析。
- `docs/ARCHITECTURE.md`、`packages/shared/README.md`、`packages/shared/generated/README.md` 和 OpenAPI active 计划需要同步本决策。

## 验证方式

本 ADR 本身通过文档质量门禁验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild
```

后续真正引入生成器时，必须新增至少以下验证：

- 从已提交 OpenAPI 快照生成 TypeScript 类型的命令。
- 生成产物漂移检查，确认重新生成后没有未提交差异。
- Web 类型检查，确认 Web 消费生成类型不会绕过 BFF 或取消 Zod 边界校验。
- 如生成器引入新依赖，补充对应包管理、锁文件和安装复现说明。

## 回滚条件

如果后续发现生成类型维护成本高于收益、生成工具不稳定、输出过重，或生成物难以在不升级根 workspace 的前提下被消费，可以回滚到 ADR 0006 已建立的手写 Zod 加 OpenAPI 漂移检查方案。

如果未来确实需要生成完整 API client，应新增 ADR 替代或扩展本决策，并单独说明 client 只允许在 Nuxt server BFF、desktop 本机后端或其他受控边界中使用的规则。

## 后续事项

- 评估 TypeScript 类型生成工具，优先选择只输出类型、无运行时 client、输出稳定且便于漂移检查的方案。
- 设计生成脚本名称、输入快照、输出目录和差异检查方式。
- 明确 Web 是否直接引用 `packages/shared/generated/`，还是先在 `apps/web` 内部做只读验证。
- 在生成器落地前，继续维护 `expected-schemas.json` 与 Web Zod schema 的人工同步关系。
