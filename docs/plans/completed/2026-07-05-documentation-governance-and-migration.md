# 文档治理和迁移

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成。
- 创建时间：2026-07-05
- 最后更新：2026-07-07

## 当前结论

文档体系已收敛为两套项目文档：

- 根仓库 `docs/`：公开项目文档，覆盖除后端内部实现以外的入口、约束、ADR、计划、公开契约、部署配置和未归档讨论结论。
- `services/backend/docs/`：后端项目文档，覆盖后端内部 ADR、计划、数据模型、接口草案、通知调度、治理、诊断和验证细节。

不再维护单独的长期产品文档目录，也不再维护额外的 internal docs 层。未归档讨论结论按范围临时放入 `docs/discussions/` 或 `services/backend/docs/discussions/`；进入计划、ADR、接口草案、代码或测试后必须迁走或删除。

## 已完成迁移

- 长期产品文档入口 `docs/product/` 已移除。
- 只剩历史入口的 `docs/AUTH_DATA_MODEL.md` 和 `docs/DATA_PERSISTENCE_AUDIT.md` 已移除。
- Todo、日程、规则生成、通知中心、公开主页、公开流和协作事项的公开状态保留在 `docs/plans/active/2026-06-26-todo-rule-generated-tasks-and-notification-center.md`。
- 后端权限矩阵、数据模型、接口草案、通知调度和实现切片已迁入 `services/backend/docs/plans/`。
- 公开文档边界规则见 `docs/DOCUMENTATION_BOUNDARY.md`；后端私有精确检查规则见 `services/backend/docs/config/public-doc-boundary-rules.psd1`。

## Git 历史裁剪

公开主仓库已按本轮边界裁剪历史：

- 从历史中移除 `docs/plans/active/` 旧版本、`docs/product/`、`docs/AUTH_DATA_MODEL.md`、`docs/DATA_PERSISTENCE_AUDIT.md`、旧 completed 文档治理计划和 `internal-docs` 子模块路径。
- 当前公开版 `docs/plans/active/` 已作为裁剪后的当前版本重新加入。
- 后端内部草案和实现细节由 `services/backend/docs/` 承接。

## 验证

- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`
- `pwsh -NoLogo -NoProfile -File scripts/sync-active-plan-status.ps1 -Check`
- `pwsh -NoLogo -NoProfile -File scripts/check-public-doc-boundary.ps1`

## 归档备注

- 本计划已完成，不保留当前待办。
- 本机根仓库历史裁剪前备份 bundle：`.local/backups/hdx-root-before-doc-history-prune-20260707.bundle`。
- 本机旧 `internal-docs` gitdir 清理前备份 bundle：`.local/backups/internal-docs-gitdir-before-removal-20260707.bundle`。
