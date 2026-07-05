# 文档索引

本文档目录是 HDX 工具箱的事实源。仓库内项目文档默认使用中文编写。

## 核心文档

- `CONSTRAINTS.md`：项目约束。
- `ARCHITECTURE.md`：暂定架构。
- `QUALITY.md`：质量门禁。
- `AGENT_WORKFLOW.md`：智能体命令执行、权限失败、PowerShell 与本地环境纪律。
- `GIT.md`：Git 提交、推送和智能体提交纪律。
- `ENVIRONMENT.md`：公开主仓库可维护的本地、Symphony、前端/BFF 和跨端环境分层；后端部署细节走后端私有文档。
- `AUTH_DATA_MODEL.md`：主仓库历史认证数据模型入口；后续认证 schema、migration 和表字段细节走后端私有文档。
- `BACKEND_DATA_ACCESS.md`：后端数据访问公开默认原则；具体模块、表、SQL、验证和例外清单走后端私有文档。
- `DATA_PERSISTENCE_AUDIT.md`：主仓库历史后端数据表审计入口；后续审计细节走后端私有文档。
- `HARNESS_ENGINEERING.md`：Harness Engineering 实践到本项目约束的映射。
- `RELEASE_RUNBOOK.md`：tag-only 日常发布流程和失败处理。
- `adr/`：架构决策记录。
- `plans/`：执行计划与技术债记录。

## 事实源分工

- 总览文档只写当前事实、入口和硬约束，不复制 ADR 的完整背景、备选方案或实施记录。
- 公开主仓库只保留公开摘要、跨仓库路由、交付边界、公共契约和可公开操作说明；后端内部细节默认维护在 `services/backend/README.md` 与 `services/backend/docs/README.md`，产品私有详案默认维护在 `internal-docs/`。
- ADR 记录长期决策、理由、边界、回滚条件和后续事项。
- Active plan 保留当前推进所需的状态、验证摘要、风险和交接信息；完成后移动到 `plans/completed/`，历史记录不为了“瘦身”而丢失。
- Completed plan 可以保留历史审计信息，但不作为当前后端实现事实源，也不要继续追加新的后端内部细节。
- README、runbook 和子目录说明只写用户或维护者执行入口，细节应链接到事实源。

## 维护规则

- 新增长期规则时，优先更新核心文档。
- 新增或改变技术选型时，必须新增 ADR。
- 文档过期时，按缺陷处理。
- 大型工作应在 `plans/active/` 中创建计划，完成后移动到 `plans/completed/`。
