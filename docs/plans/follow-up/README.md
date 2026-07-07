# Follow-up 计划说明

本目录保存“主体工作已结束，但仍有当前残留事项”的计划。它介于 `active/` 和 `completed/` 之间。

## 何时放这里

- 主体实现已经完成，但还需要后续验证、观察、清理或补齐。
- 剩余事项不适合继续占用 active 状态，但又不能丢进 completed。
- 判断下一步工作时需要看到这些残留事项。

## 读取规则

- 需要判断下一步做什么时，先读 `docs/plans/active/README.md`，再读本文件。
- 处理某个 follow-up 前，再打开对应计划文件。
- 如果只是小而独立的清理债务，优先放 `docs/plans/tech-debt-tracker.md`。

## 当前 follow-up

暂无独立 follow-up 计划。

## 归档规则

- follow-up 中的残留事项关闭后，移动到 `docs/plans/completed/`。
- 移动到 completed 前，只保留历史摘要、最终验证和相关 commit，并确认没有当前剩余风险。
- completed 是历史快照；除非当时记录写错，否则不再回头改正文。
