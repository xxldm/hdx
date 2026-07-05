# Completed 计划说明

本目录保存已经完成的历史计划。历史计划可能包含当时的验证命令、配置路径、native 诊断或排障细节，用于审计当时发生过什么，不代表当前公开主仓库应该继续维护这些后端内部信息。后端模块名/服务名本身不敏感，但 completed plan 不作为当前事实源。

## 读取规则

- 需要了解历史过程、提交背景或当时验证结果时，可以读取对应 completed plan。
- 需要判断当前后端实现、职责拆分、调用关系、迁移、基础设施适配、native/AOT 诊断或验证命令时，不以 completed plan 为事实源，改读 `services/backend/README.md` 与 `services/backend/docs/README.md`。
- 不要向 completed plan 追加新的后端内部实现细节。确实需要补历史说明时，只补“历史更正”或指向后端私有文档的入口。
- 新的产品私有详案、权限矩阵、数据模型、接口草案、通知调度、公开治理、审计策略和实现切片默认写入 `internal-docs/`。

## 迁移原则

公开主仓库继续保留 completed plan 的历史审计价值，但当前事实源只允许保留公开摘要、跨仓库路由、交付边界、公共契约和可公开操作说明。后端内部细节和产品私有详案不要从 completed plan 复制回 active plan、ADR 或入口文档。
