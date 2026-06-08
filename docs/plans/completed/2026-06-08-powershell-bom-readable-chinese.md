# PowerShell 脚本 UTF-8 BOM 与中文可读性整理

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成，随本轮提交归档
- 计划来源：用户确认将所有 `.ps1` 脚本改为 UTF-8 with BOM，并去掉人类不可读的 `\u` 中文转义
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

统一 PowerShell 脚本编码和中文可读性：

- Git 跟踪的 `.ps1` 文件统一保存为 UTF-8 with BOM。
- Git 跟踪的 `.ps1` 文件不再保留 `\uXXXX` 中文转义。
- docs 质量门禁加入 PowerShell 脚本编码与转义检查，避免后续回退。
- 根目录忽略的本地 `.local.ps1` 脚本同步做本机转换，但不纳入提交。

## 非目标

- 不修改脚本业务逻辑。
- 不修改子模块 `node_modules` 中第三方生成的 `.ps1` shim。
- 不调整 PowerShell 版本要求。
- 不把本地忽略文件强制纳入 Git。

## repo 内范围

- `AGENTS.md`
- `docs/CONSTRAINTS.md`
- `docs/QUALITY.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-powershell-bom-readable-chinese.md`
- `scripts/*.ps1`

## 本地任务清单

- [x] 创建本地计划。
- [x] 将 Git 跟踪的 `.ps1` 转为 UTF-8 with BOM。
- [x] 将 `.ps1` 中的 `\uXXXX` 中文转义转回可读中文。
- [x] 在质量门禁中加入 `.ps1` BOM 与转义检查。
- [x] 同步入口规则、项目约束、质量文档和总纲。
- [x] 验证脚本解析、release 校验和 docs 质量门禁。
- [x] 归档计划并随本轮提交推送。

## 验收标准

- Git 跟踪的 `.ps1` 文件均带 UTF-8 BOM。
- Git 跟踪的 `.ps1` 文件中不再出现 `\uXXXX` 转义。
- `scripts/quality-gate.ps1 -Scope docs -NoBuild` 会检查上述规则。
- 现有 OpenAPI、release manifest 和 docs 质量门禁仍通过。

## 验证方式

- BOM 检查脚本。
- `rg -n "\\u[0-9a-fA-F]{4}" scripts -g "*.ps1"`。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1`。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`。
- `git diff --check`。

## 风险与阻塞

- UTF-8 with BOM 会造成一次性整文件编码变更；diff 可能比逻辑改动更大。
- 根目录 `.local.ps1` 属于忽略文件，只做本机整理，不作为仓库历史事实源。

## 状态记录

- 2026-06-08：创建计划并开始实施。
- 2026-06-08：完成 Git 跟踪 `.ps1` 的 UTF-8 with BOM 转换和中文转义清理；根目录忽略的 `start-symphony.local.ps1`、`patch-symphony-dashboard.local.ps1` 也已在本机同步转换，但不纳入 Git 提交。
- 2026-06-08：`scripts/quality-gate.ps1 -Scope docs -NoBuild` 已接入并通过 PowerShell 脚本编码检查。

## 验证结果

- BOM 检查脚本：通过，Git 跟踪的 `.ps1` 以及本机忽略的两个 `.local.ps1` 均为 UTF-8 with BOM。
- `rg -n "\\u[0-9a-fA-F]{4}" scripts start-symphony.local.ps1 patch-symphony-dashboard.local.ps1`：无匹配。
- PowerShell AST 解析检查：通过，Git 跟踪的 `.ps1` 以及本机忽略的两个 `.local.ps1` 均无解析错误。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1`：通过。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`：通过。
- `git diff --check`：通过；仅提示部分工作区文件后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，包含新增 PowerShell 脚本编码检查、Release manifest 校验、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 OpenAPI/Web 类型对齐检查。

## 剩余风险

- `U` 兼容函数在部分脚本中仍然保留，但其字符串内容已改为可读中文；后续可作为低风险清理单独移除。
- `.local.ps1` 是 Git 忽略文件，本轮只在当前工作区做本机转换，不作为仓库历史事实源。

## 相关 commit

- 本计划随本轮提交 `杂项：统一 PowerShell 脚本编码` 归档；具体哈希以 Git 历史为准。
