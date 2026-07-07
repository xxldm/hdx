# 外部任务系统与本地计划协作规则实施计划

- 外部任务系统：无
- 外部任务链接/编号：无
- 外部任务是否为主计划来源：否
- 当前状态：已完成，提交前验证已通过
- 计划来源：用户要求细化 Symphony/Linear 与 repo-local 计划文件协作规则
- 创建时间：2026-06-02
- 最后更新：2026-06-02

## 目标

明确外部任务系统和 `docs/plans/` 本地计划文件的分工，让 Symphony/Linear 等系统可以承载完整项目管理计划，同时保证后续智能体能从仓库恢复实现状态、验证缺口、技术债、风险、决策和 commit 关联。

## 非目标

- 不引入具体 Symphony/Linear 集成、API、自动同步脚本或包依赖。
- 不调整后台、Web、App 或共享层实现。
- 不重新整理既有 active 计划的归档状态。

## repo 内范围

- `AGENTS.md`
- `docs/CONSTRAINTS.md`
- `docs/QUALITY.md`
- `docs/GIT.md`
- `docs/plans/README.md`
- `docs/plans/TEMPLATE.md`
- `docs/adr/0004-external-task-and-local-plan-rules.md`
- 本计划文件

## 本地任务清单

- [x] 阅读入口规则、质量门禁、Git 规则、计划 README 和 ADR 0001。
- [x] 创建本轮本地计划文件。
- [x] 更新 `docs/plans/README.md`，定义外部任务系统与本地计划的分工、触发条件、最低内容和状态同步规则。
- [x] 新增 `docs/plans/TEMPLATE.md`，包含外部任务字段和本地交接字段。
- [x] 同步更新 `AGENTS.md`、`docs/CONSTRAINTS.md`、`docs/QUALITY.md` 和 `docs/GIT.md`。
- [x] 新增 ADR 0004，记录该工作流决策。
- [x] 检查规则文档之间口径一致。
- [x] 执行 `git diff --cached --check` whitespace 检查。
- [x] 完成后移动计划到 `docs/plans/completed/`。

## 验收标准

- 外部任务系统可作为主计划来源，但本地计划不机械复制完整产品/项目管理步骤。
- 规则明确说明何时必须创建 `docs/plans/active/` 计划、何时可以豁免。
- 本地计划最低内容、状态显示规则、执行中更新要求和提交前检查均有文档入口。
- ADR 0004 包含背景、决策、备选方案、影响、验证方式和回滚条件。

## 验证方式

- 人工检查 `AGENTS.md`、`docs/CONSTRAINTS.md`、`docs/QUALITY.md`、`docs/GIT.md`、`docs/plans/README.md`、`docs/plans/TEMPLATE.md` 与 ADR 0004 口径一致。
- 执行 `git diff --cached --check` 或等效 whitespace 检查。

## 过程记录

- 当前没有外部任务链接，示例和模板必须保持占位，不伪造 Symphony/Linear 编号。
- 本轮仅更新规则文档，不提供外部系统自动同步能力。

## 状态记录

- 2026-06-02：已阅读指定入口文档和架构文档，确认工作树干净、`docs/plans/TEMPLATE.md` 尚不存在、下一个 ADR 编号为 0004。
- 2026-06-02：已创建本轮 active 计划，开始更新计划 README、模板和规则入口。
- 2026-06-02：已更新计划 README、计划模板、入口规则、约束、质量门禁、Git 规则和 ADR 0004，开始一致性检查。
- 2026-06-02：已用 `rg` 检查关键规则词，确认外部任务、本地计划、状态同步、验证结果和相关 commit 的口径在各入口一致。
- 2026-06-02：规则文档工作已完成，计划移动到 `docs/plans/completed/`，并在提交前完成 whitespace 检查。
- 2026-06-02：`git diff --cached --check` 通过，提交前验证完成。

## 验证结果

- 人工读回检查通过：`AGENTS.md`、`docs/CONSTRAINTS.md`、`docs/QUALITY.md`、`docs/GIT.md`、`docs/plans/README.md`、`docs/plans/TEMPLATE.md` 与 ADR 0004 口径一致。
- `rg` 关键规则词检查通过，确认外部任务、本地计划、状态同步和 commit 关联规则均有文档入口。
- `git diff --cached --check` 通过。

## 归档备注

- 本轮仅定义人工协作规则，尚未接入 Symphony/Linear 自动同步能力。
- 本计划对应提交 hash 已由 Git 历史体现：`8143313 杂项：细化外部任务与本地计划规则`。

## 相关 commit

- `8143313 杂项：细化外部任务与本地计划规则`（根仓库）
