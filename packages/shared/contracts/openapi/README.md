# openapi

本目录记录 OpenAPI 契约检查的最小输入。

- `expected-paths.json`：当前 Web/BFF 已依赖的后端公开路径清单。
- `snapshots/`：后端外部入口 OpenAPI spec 快照，当前包含 `auth-service.openapi.json` 和 `gateway.openapi.json`。

当前检查重点是避免已被 Web 使用的后端路径从 OpenAPI 中消失，并让快照漂移在提交前可见。

## 刷新流程

先运行后端 OpenAPI 测试生成真实 spec：

```powershell
mvn -pl :backend-auth-service,:backend-gateway -am test
```

再从后端 `target/openapi/` 刷新本目录快照：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/openapi-refresh-snapshots.ps1
```

最后运行契约检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/openapi-contract-check.ps1
```

如果后端公开路径变化符合预期，必须同时提交后端测试或 OpenAPI 配置变更、`snapshots/` 快照更新和 `expected-paths.json` 变更。
