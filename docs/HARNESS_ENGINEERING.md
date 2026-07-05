# Harness Engineering 约束映射

本文将 OpenAI Harness Engineering 文章中的实践，映射为 HDX 当前阶段可执行的项目约束。

参考资料：[OpenAI：工程技术：在智能体优先的世界中利用 Codex](https://openai.com/zh-Hans-CN/index/harness-engineering/)

## 人类负责意图，智能体负责执行

项目约束：

- 需求、边界、验收标准和风险应写入仓库。
- 智能体执行前应能从 `AGENTS.md` 和 `docs/` 恢复上下文。
- 重要取舍必须记录为 ADR，而不是只保留在对话中。

落地位置：

- `AGENTS.md`
- `docs/CONSTRAINTS.md`
- `docs/adr/`

## 仓库知识成为事实源

项目约束：

- 长期有效的知识进入 `docs/`。
- 文档过期视为缺陷。
- 目录职责、依赖方向和质量门禁都应有明确文档入口。

落地位置：

- `docs/README.md`
- `docs/ARCHITECTURE.md`
- `docs/QUALITY.md`

## 提高应用可读性

项目约束：

- 后台预留结构化日志、指标和追踪接入点。
- Web 与 App 预留错误上报、性能指标和版本信息。
- 关键运行状态、错误路径和验证结果应能被工具读取，而不是只靠人工观察。

落地位置：

- `docs/CONSTRAINTS.md`
- 未来测试、lint、CI 和观测脚本。

## 强制架构和品味

项目约束：

- 框架未定阶段不提前锁死技术栈。
- 跨端依赖方向先行固定。
- 引入技术栈、共享层职责变化或高风险能力前必须新增 ADR。
- 重复出现的评审意见要沉淀为文档规则、测试或 lint。

落地位置：

- `docs/ARCHITECTURE.md`
- `docs/adr/TEMPLATE.md`
- `docs/QUALITY.md`

## 建立反馈回路

项目约束：

- 新增行为必须有验证方式。
- 修复缺陷时优先先复现再修复。
- 复杂改动应有计划、验收标准和剩余风险记录。

落地位置：

- `docs/QUALITY.md`
- `docs/plans/`

## 控制熵增

项目约束：

- 技术债必须记录影响、临时方案和移除条件。
- 共性能力不得在多端复制粘贴。
- 文档、测试、配置和生成产物都纳入维护范围。

落地位置：

- `docs/plans/tech-debt-tracker.md`
- `packages/shared/`
