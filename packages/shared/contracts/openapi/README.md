# openapi

本目录记录 OpenAPI 契约检查的最小输入。

- `expected-paths.json`：当前 Web/BFF 已依赖的后端公开路径清单。
- `expected-schemas.json`：当前 Web Zod schema 已依赖的关键 OpenAPI schema 字段、类型、格式和最小约束清单。
- `snapshots/`：后端外部入口 OpenAPI spec 快照，当前包含 `auth-service.openapi.json` 和 `gateway.openapi.json`。

当前检查重点是避免已被 Web 使用的后端路径和关键字段从 OpenAPI 中消失，并让快照漂移在提交前可见。

这些快照也是后续 OpenAPI TypeScript 类型生成的首选输入。生成策略见 `docs/adr/0007-openapi-typescript-generation-strategy.md`；第一阶段只允许生成类型，不生成完整 API client。

## Snapshot Hash

发布链路使用 `scripts/openapi-snapshot-hash.ps1` 计算 OpenAPI snapshot 集合 hash。算法按 `snapshots/` 下文件的相对路径排序，记录每个文件的 `path + size + fileSha256`，再对规范清单计算 SHA-256。

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-snapshot-hash.ps1
```

只输出 hash：

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-snapshot-hash.ps1 -Quiet
```

## 刷新流程

先运行后端 OpenAPI 测试生成真实 spec：

```powershell
mvn -pl :backend-auth-service,:backend-gateway -am test
```

再从后端 `target/openapi/` 刷新本目录快照：

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-refresh-snapshots.ps1
```

最后运行契约检查：

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-contract-check.ps1
```

如果后端公开路径或关键字段变化符合预期，必须同时提交后端测试或 OpenAPI 配置变更、`snapshots/` 快照更新、`expected-paths.json` 或 `expected-schemas.json` 变更。

## 类型生成

当前 OpenAPI TypeScript 类型原型从本目录快照生成：

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-generate-types.ps1
```

提交前必须检查生成类型没有漂移：

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-generate-types.ps1 -Check
```

## Web 类型对齐

`scripts/checks/openapi-web-type-compatibility.ts` 是只读编译期检查文件，用于确认 Web Zod schema 推导出的类型和 OpenAPI 生成类型仍兼容。它不生成运行时代码，不替代 Web Zod 边界校验。

该检查文件放在 `scripts/checks/`，因为它会同时读取 shared 生成类型和 Web 手写类型；它属于跨边界验证资产，不属于 `packages/shared` 可被端侧消费的契约资产。

```powershell
pwsh -NoLogo -NoProfile -File scripts/openapi-web-type-check.ps1
```
