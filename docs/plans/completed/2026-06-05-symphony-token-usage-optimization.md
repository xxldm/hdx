# Symphony Token 消耗优化

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户要求落实 Symphony token 消耗优化计划
- 创建时间：2026-06-05
- 最后更新：2026-06-05

## 目标

降低 Symphony/Codex 在无人值守任务中的重复审计、权限失败重试、长上下文读取、无效 PR 轮询和 Linear workpad 大体量更新造成的 token 消耗。

## 非目标

- 不修改 Symphony 源码。
- 不降低 HDX 仓库既有质量门槛。
- 不移除本地计划和排障记录要求。
- 不调整应用代码、后端、Web 或 App 技术栈。

## repo 内范围

- `WORKFLOW.md`
- `docs/plans/completed/2026-06-05-symphony-token-usage-optimization.md`

## 本地任务清单

- [x] 收紧 Symphony agent 轮次和 Codex stall/turn timeout。
- [x] 增加权限失败重试预算，避免同一命令反复普通权限失败。
- [x] 增加 Linear workpad “摘要 + 索引”规则，把完整排障细节转移到本地计划。
- [x] 增加无新增信息即停止规则，避免连续“续作 N 审计”。
- [x] 限制续作时重复读取仓库入口大上下文。
- [x] 优化 PR feedback sweep 触发条件，减少无变化时全量扫描。
- [x] 增加 Git 网络命令防挂规则。

## 验收标准

- `WORKFLOW.md` 明确描述权限失败重试预算。
- `WORKFLOW.md` 要求 workpad 包含 `详情位置`，且完整排障细节写入 repo-local 计划。
- `WORKFLOW.md` 禁止无新增信息时连续写入重复续作审计。
- `WORKFLOW.md` 收紧 `max_turns`、`stall_timeout_ms` 和 `turn_timeout_ms`。
- PR feedback sweep 仍在进入 `Human Review` 前完整执行。

## 验证方式

- `rg` 检查新增规则关键词。
- `git diff --check -- WORKFLOW.md docs/plans/completed/2026-06-05-symphony-token-usage-optimization.md`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\start-symphony.local.ps1 -ValidateOnly`

## 风险与阻塞

- 权限失败预算会减少重复复现普通权限失败现场；首次失败必须写入本地计划作为补偿。
- Workpad 摘要化后，仅看 Linear 无法获得完整长日志；通过 `详情位置` 指向本地计划补偿。
- 超时和轮次收紧后，超长任务可能更早停止；停止前必须写清已完成、未完成和下一步。

## 状态记录

- 2026-06-05：创建并完成计划，已将 token 优化规则落实到 `WORKFLOW.md`。

## 验证结果

- 待运行提交前验证。

## 剩余风险

- 未修改 Symphony 源码，因此权限失败重试次数依赖 Codex 遵循 `WORKFLOW.md` 规则，而不是运行时硬限制。
- 真实无人值守行为仍需下一次 Symphony 任务观察验证。

## 相关 commit

- 待记录。
