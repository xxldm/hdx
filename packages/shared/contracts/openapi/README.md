# openapi

本目录记录 OpenAPI 契约检查的最小输入。

- `expected-paths.json`：当前 Web/BFF 已依赖的后端公开路径清单。
- `snapshots/`：未来真实 OpenAPI spec 快照候选目录；当前暂不提交快照。

当前检查重点是避免已被 Web 使用的后端路径从 OpenAPI 中消失。后续如果引入 spec 快照或自动抓取，需要同步更新 `scripts/openapi-contract-check.ps1`、本目录说明和第 5 步计划。
