# ADR 0004：外部任务系统与本地计划协作规则

- 日期：2026-06-02
- 状态：已接受

## 背景

HDX 后续可能使用 Symphony、Linear 等外部任务系统管理任务。外部系统适合展示完整计划步骤、负责人、状态、排期和产品/项目管理信息，但后续智能体不一定能访问这些系统，也不能假设外部任务内容和仓库状态始终同步。

本仓库已经要求重要设计、验证缺口、技术债和临时决策沉淀到 `docs/`。因此需要明确外部任务系统与 `docs/plans/` 的分工，既避免重复维护两套完整计划，又保证 repo-local handoff 足够恢复实现状态。

## 决策

- Symphony、Linear 等外部任务系统可以作为主计划来源。
- 如果外部任务已有完整步骤，本地计划不复制完整产品或项目管理步骤。
- 本地计划文件用于记录 repo 相关交接信息，包括实现状态、验证缺口、技术债、风险、决策和 commit 关联。
- 当工作跨模块、跨多次提交或跨多天，涉及架构边界、ADR、技术选型、安全或高风险行为，存在验证缺口、技术债、回滚条件或复杂失败处理，外部任务不足以让后续智能体从仓库恢复状态，外部任务系统不可访问，或用户明确要求时，必须在 `docs/plans/active/` 创建或更新本地计划。
- 本地计划至少记录外部任务系统和链接/编号、当前状态、repo 内实现范围、本地代码/文档/验证 checklist、状态记录、验证结果、剩余风险和相关 commit。
- 进行中的计划必须维护顶部 `active-plan-status` 状态块，作为“何时读取、当前状态、下一步、主要剩余风险”的单一事实源。
- `docs/plans/active/README.md` 只作为低 token 状态仪表盘，由 `scripts/sync-active-plan-status.ps1` 从各 active plan 状态块生成或校验。
- 计划内部任务进度必须使用 Markdown checkbox，或使用包含“状态”列的表格。
- 主要步骤完成、遇到阻塞、验证完成、最终回复前，都必须同步更新本地计划。
- 提交前必须检查外部任务链接/编号、本地 active 计划状态、验证结果、剩余风险和相关 commit 占位是否已同步。
- 完成后的本地计划应移动到 `docs/plans/completed/`；如继续留在 `active/`，必须记录原因和下一次清理条件。

## 备选方案

- 完全依赖 Symphony/Linear：减少仓库文档量，但后续智能体可能无法访问外部系统，也无法仅凭 Git 历史判断验证缺口、技术债和回滚条件。
- 在本地计划完整复制外部任务：仓库信息最完整，但会产生双写成本，容易和外部任务状态分叉。
- 只在最终回复中说明状态：短期轻量，但聊天记录不是版本化事实源，无法支撑跨天、跨提交或多智能体接力。

## 影响

- `docs/plans/README.md` 成为本地计划触发条件、最低内容和状态同步规则的事实源。
- `docs/plans/TEMPLATE.md` 增加外部任务字段，同时保留 repo-local 交接字段。
- `AGENTS.md`、`docs/CONSTRAINTS.md`、`docs/QUALITY.md` 和 `docs/GIT.md` 增加外部任务与本地计划的关系规则。
- 文档-only、架构和高风险工作在提交前需要检查 active 计划和 external task 状态是否同步。

## 验证方式

- 人工检查 `AGENTS.md`、`docs/CONSTRAINTS.md`、`docs/QUALITY.md`、`docs/GIT.md`、`docs/plans/README.md`、`docs/plans/TEMPLATE.md` 与本 ADR 的口径一致。
- 文档-only 变更提交前执行 `git diff --cached --check` 或等效 whitespace 检查。
- 后续实际使用 Symphony/Linear 时，通过计划文件确认外部链接/编号、repo 内范围、状态记录、验证结果、剩余风险和相关 commit 已保留在仓库。

## 回滚条件

如果后续引入可靠的外部任务同步机制，并能保证所有后续智能体稳定访问外部任务、离线恢复 repo 状态和追踪 commit 关联，可以新增 ADR 替代本规则。

回滚或替换时，必须同步更新 `AGENTS.md`、`docs/CONSTRAINTS.md`、`docs/QUALITY.md`、`docs/GIT.md`、`docs/plans/README.md` 和 `docs/plans/TEMPLATE.md`，并说明既有本地计划的迁移或归档方式。

## 后续事项

- 后续如接入 Symphony/Linear API 或自动同步工具，需新增 ADR 说明权限、数据边界、失败处理和验证方式。
- `scripts/sync-active-plan-status.ps1` 已作为本地状态投影脚本接入 docs 质量门禁；后续可以继续扩展为检查外部任务字段、状态记录、验证结果和相关 commit。
