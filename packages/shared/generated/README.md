# generated

本目录是未来生成契约产物的候选落点。

当前已提交 OpenAPI schema TypeScript 类型原型，产物位于 `openapi/`。该原型遵守 `docs/adr/0007-openapi-typescript-generation-strategy.md`：只生成类型，不生成完整 API client，不让浏览器绕过 Nuxt server BFF 直连后端。

## 生成命令

从已提交 OpenAPI 快照重新生成类型：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/openapi-generate-types.ps1
```

检查已提交类型是否与快照一致：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/openapi-generate-types.ps1 -Check
```

## 生成前置条件

- 先建立 OpenAPI spec 快照或可重复获取命令；当前快照位于 `packages/shared/contracts/openapi/snapshots/`，检查入口为 `scripts/openapi-contract-check.ps1`。
- 先建立 Web 手写 Zod schema 与 OpenAPI schema 的漂移检查入口；当前已有路径级和关键字段级检查，更完整的生成器/类型漂移检查待补。
- 确认生成物只服务 Nuxt server BFF 或端无关协议类型，不生成完整 API client、请求封装或浏览器直连后端的调用逻辑。
- 确认不需要把根仓库升级为 pnpm workspace；如果需要升级，必须先补充 ADR。

## 当前限制

- 当前脚本只覆盖 `components.schemas`，不生成 paths、operation、request client 或 runtime validator。
- 当前脚本是无外部依赖的 PowerShell 原型，不代表最终生成器选型。
- Web 尚未正式引用这些生成类型；Zod 仍是运行时边界校验事实源。
