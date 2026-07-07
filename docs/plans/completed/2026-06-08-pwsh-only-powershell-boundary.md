# PowerShell 7 运行边界收口

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户确认项目直接要求 PowerShell 7+ / `pwsh`，不再为 Windows PowerShell 5.1 保留 BOM、`\uXXXX` 或 `Get-Content -Encoding UTF8` 强制规则
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

将 PowerShell 脚本运行边界收口为 PowerShell 7+：

- 当前生效规则明确要求 `pwsh`，不支持 Windows PowerShell 5.1。
- 移除 `.ps1` UTF-8 with BOM 和 `\uXXXX` 转义专项规则。
- 移除 docs 质量门禁中的 `.ps1` BOM/转义专项检查。
- 将当前入口示例和提示命令改为 `pwsh -NoLogo -NoProfile ...`。
- 删除脚本中的 `function U` 包装，中文文案直接写为可读字符串。

## 非目标

- 不修改 `docs/plans/completed/` 中已经发生过的历史记录。
- 不引入 `.sh` 脚本。
- 不重构质量门禁业务逻辑。
- 不调整后端、Web、Desktop 或 App 代码。

## repo 内范围

- `AGENTS.md`
- `README.md`
- `docs/CONSTRAINTS.md`
- `docs/QUALITY.md`
- `docs/ENVIRONMENT.md`
- `docs/GIT.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-08-pwsh-only-powershell-boundary.md`
- `scripts/*.ps1`

## 本地任务清单

- [x] 创建本地计划。
- [x] 更新当前生效文档规则和命令示例。
- [x] 删除质量门禁中的 `.ps1` BOM/转义检查。
- [x] 删除脚本中的 `function U` 包装。
- [x] 运行 release 校验、docs 质量门禁和空白检查。
- [x] 归档计划并提交推送。

## 验收标准

- 当前规则文档明确 `pwsh` 是 PowerShell 脚本入口。
- 当前规则文档不再要求 `.ps1` UTF-8 with BOM、不再要求 `Get-Content -Encoding UTF8`。
- `scripts/*.ps1` 不再包含 `function U` 或 `U '...'` 调用。
- `scripts/quality-gate.ps1 -Scope docs -NoBuild` 不再执行 BOM/转义专项检查。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild` 通过。

## 验证方式

- `pwsh -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion; $PSVersionTable.PSEdition"`
- `rg -n "function U|\\bU\\s+['\"]|\\$\\(U\\s+['\"]" scripts -g "*.ps1"`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 过程记录

- Windows PowerShell 5.1 将不再作为支持环境；未安装 PowerShell 7 的开发者需要先安装 `pwsh`。
- 历史完成计划中仍会保留当时关于 5.1、BOM 和 `\uXXXX` 的记录，避免篡改历史。

## 状态记录

- 2026-06-08：创建计划并开始实施。
- 2026-06-08：完成当前生效文档规则调整，明确项目 PowerShell 脚本要求 PowerShell 7+ / `pwsh`，不支持 Windows PowerShell 5.1。
- 2026-06-08：完成 `scripts/*.ps1` 可读性清理，移除 `function U` 包装并将中文输出、错误提示和帮助文本改为直接可读中文。
- 2026-06-08：更新 `scripts/quality-gate.ps1`，移除 `.ps1` UTF-8 with BOM 和 `\uXXXX` 转义专项检查；docs 范围子脚本调用统一使用当前 `pwsh`。
- 2026-06-08：计划已归档到 `docs/plans/completed/`。

## 验证结果

- `pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion; $PSVersionTable.PSEdition'`：通过，当前版本为 PowerShell 7.6.2，PSEdition 为 Core。
- `rg -n "function U|\\bU\\s+['\"]|\\$\\(U\\s+['\"]" scripts -g "*.ps1"`：无匹配，确认 `function U` 和调用已移除。
- PowerShell AST 解析检查：通过，`scripts/*.ps1` 均可解析。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -ScanPath packages/shared/contracts/release`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。

## 归档备注

- Windows PowerShell 5.1 不再作为支持环境；未安装 PowerShell 7 的开发者需要先安装 `pwsh`。
- `docs/plans/completed/` 中较早计划仍保留当时关于 5.1、BOM、`\uXXXX` 和旧 `powershell -NoProfile -ExecutionPolicy Bypass` 命令的历史记录，本轮不回写历史。

## 相关 commit

- 本轮根仓库提交：见包含本计划归档的提交。
