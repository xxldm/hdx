# 文档事实源与重复表述整理

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户要求全量扫描文档，不只整理近期 release 文档
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

全量扫描仓库 Markdown 文档中的重复、过期或职责混杂表述，让长期入口重新回到“地图和事实源”的角色。

重点处理：

- 当前事实源仍保留旧规则或旧技术状态。
- 总览文档复制 ADR 的大段正文。
- README、runbook、ADR、计划之间职责不清。

## 非目标

- 不压缩 active plan 中用于交接的状态、验证命令、失败记录和剩余风险。
- 不重写 completed plan 的历史验证记录；历史命令即使包含旧写法，也只作为当时执行记录保留。
- 不改动子模块源码或发布 workflow 行为。

## repo 内范围

- `WORKFLOW.md`
- `README.md`
- `docs/README.md`
- `docs/CONSTRAINTS.md`
- `docs/ARCHITECTURE.md`
- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/adr/0014-release-native-build-budget-and-reuse-strategy.md`
- `packages/shared/contracts/release/README.md`

## 完成内容

- 修正 `WORKFLOW.md` 中仍指向 `docs/GIT.md` 的权限失败规则，把命令权限纪律指回 `docs/AGENT_WORKFLOW.md`。
- 移除 `WORKFLOW.md` 中“读取文档必须 `Get-Content -Encoding UTF8`”的旧强制规则，改为 PowerShell 7+ / `pwsh` 边界。
- 修正 `WORKFLOW.md` 中 “App 当前阶段仍不绑定框架” 的旧状态，改为 ADR 0009 已确认的 Android/HarmonyOS NEXT 原生路线。
- 在 `docs/README.md` 中补齐 `AGENT_WORKFLOW.md`、`ENVIRONMENT.md` 入口，并新增事实源分工规则。
- 将 `docs/ARCHITECTURE.md` 中 OpenAPI/shared、Desktop、App、基础设施、许可、Web 和后端拓扑的长段复述拆为当前事实清单。
- 将 `docs/CONSTRAINTS.md` 和根 `README.md` 中 release 边界长句收敛为硬约束和入口摘要。
- 调整 ADR 0013 的 Release 资产来源表述，使当前策略明确为“非后端资产不自动复用；后端 native 受 ADR 0014 管控复用”。
- 调整 ADR 0014 的后续事项，记录 Linux services 并行 workflow 已实跑，Windows services 仍按需验证。
- 拆分 `packages/shared/contracts/release/README.md` 中 release 契约的长段说明。

## 验证结果

- 已执行旧状态扫描：
  - `App 当前阶段仍不绑定框架` 只剩 ADR 0009 的“确认旧状态不再保留”验证句，以及本计划的修正记录。
  - 未发现 `docs/GIT.md` 仍作为权限失败规则事实源的当前指示。
  - 未发现“第一版真实 release workflow 不做跨 Release 旧资产自动复用”仍作为当前策略。
- 已执行长行扫描：剩余超长行主要位于 active/completed plan 的历史命令、run 记录、`WORKFLOW.md` 的 YAML 命令行、`services/backend/README.md` 的 Windows 验证命令和 `docs/ENVIRONMENT.md` 的环境变量说明；本轮按事实源分工保留。
- 已执行 `git diff --check`：通过，仅出现 Git for Windows 行尾提示。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，覆盖关键文档读取、根仓库空白检查、release manifest 校验、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- Active plan 和 completed plan 中仍有长行、旧命令和历史状态描述；这些属于交接或历史验证记录，本轮不为了格式统一而删除。
- `services/backend/README.md` 中存在较长的 Windows `cmd.exe` 验证命令，属于后端子仓库文档，本轮未改动。
- `docs/ENVIRONMENT.md` 中仍有较长环境变量分层说明；该文件是环境配置事实源，本轮只处理明显重复和过期入口。

## 相关 commit

- 本提交：`杂项：整理文档事实源边界`。
