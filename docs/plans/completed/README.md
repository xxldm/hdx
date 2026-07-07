# Completed 计划说明

本目录保存已经真正结束的历史计划。completed plan 是历史快照：它记录最终状态、最终结论和最终验证，不代表当前事实源。

进入 completed 前必须确认没有当前仍需处理的残留事项。

## 读取规则

- 需要了解历史过程、提交背景或当时验证结果时，可以读取对应 completed plan。
- completed 中不应保留当前待办。
- 需要判断当前后端实现、职责拆分、调用关系、迁移、基础设施适配、native/AOT 诊断或验证命令时，不以 completed plan 为事实源，改读 `services/backend/README.md` 与 `services/backend/docs/README.md`。
- 不要向 completed plan 追加新的当前结论、后端内部实现细节或当前风险。确实是当时记录写错时，只补“历史更正”。
- 新的未归档公开讨论结论临时写入 `docs/discussions/`；后端权限矩阵、数据模型、接口草案、通知调度、公开治理、审计策略和实现切片写入 `services/backend/docs/`。具体分层见 `docs/DOCUMENTATION_BOUNDARY.md`。

## 迁移原则

公开主仓库继续保留 completed plan 的历史审计价值，但当前事实源按 `docs/DOCUMENTATION_BOUNDARY.md` 分层维护。后端内部细节不要从 completed plan 复制回 active plan、ADR 或入口文档；仍有效但尚未归档的公开结论应临时收敛到 `docs/discussions/`，进入正式事实源后删除。
