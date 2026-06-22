# 智能体工作流

本文档记录智能体在本仓库执行命令、处理权限失败和使用 PowerShell 时的本地操作纪律。

## 命令执行入口

- 项目 PowerShell 脚本要求 PowerShell 7+ / `pwsh`，不支持 Windows PowerShell 5.1。
- 优先使用仓库内已有脚本入口，例如 `pwsh -NoLogo -NoProfile -File scripts/verify-changed.ps1` 或 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope changed`。
- 可以用 `rg`、`git status`、`git diff`、`Get-Content` 等只读命令做排查；涉及 Git 写操作、网络、依赖下载或构建产物写入时，按本文件的权限规则处理。
- 在 Windows/Codex 本地环境中，不使用 `git submodule foreach` 做常规子模块状态检查。该命令依赖 Git for Windows 的 shell 辅助环境，已多次稳定失败为 `basename: command not found`、`sed: command not found` 或 `git-sh-setup: file not found`，容易浪费排查时间。
- 检查全部子模块状态时使用 `pwsh -NoLogo -NoProfile -File scripts/git-submodule-status.ps1 -RepoRoot <repo>`；检查单个子模块时使用 `git -C <submodule-path> status --short --branch`、`git -C <submodule-path> rev-parse HEAD` 等直接命令。
- 后端 native 构建调参时，不要用命令行 `-DbuildArgs=...` 直接覆盖 Maven 父 POM 的 `<buildArgs>`。
  父 POM 内已有 `--exclude-config` 用于排除部分依赖旧式 `resource-config.json`；覆盖后可能让 GraalVM 25 在 `ResourcesFeature.beforeAnalysis` 阶段触发 `LegacyResourceConfigurationParser` NPE。
  需要追加 native 参数时，在后端 POM 中新增 profile，并用 `combine.children="append"` 合并。
- 重复出现的命令踩坑、平台差异和环境问题应沉淀到本文档或脚本中；active plan 只记录当前任务状态、关键决策、验证摘要和剩余风险。

## Windows PowerShell 运行环境

- Windows 本地执行环境要求使用 MSI 版 PowerShell 7+ / `pwsh`。
- 不使用 Microsoft Store、MSIX 或 WindowsApps 版 PowerShell 作为 Codex 集成终端、脚本入口或质量门禁入口。
- WindowsApps/MSIX 版 PowerShell 可能干扰 Codex Windows sandbox 创建子进程，表现为普通 shell 工具调用在启动前失败，例如 `CreateProcessAsUserW failed: 1312`。
- 如果普通 shell 工具调用在 Windows 上出现 `CreateProcessAsUserW failed: 1312`，优先检查 `pwsh` 是否来自 WindowsApps/MSIX 版。
- 已知修复方式是卸载 WindowsApps/MSIX 版 PowerShell，安装 MSI 版 PowerShell 7，并重启 Codex Desktop。
- 后端启动与测试依赖 GraalVM JDK 25 和 Maven 3.8.8；如果长期运行的 Codex Desktop、IDE 或终端仍继承旧 `JAVA_HOME`、`MAVEN_HOME` 或 `PATH`，先重启对应应用或终端，再判断是否是项目问题。
- 修复后用普通权限复测：

```powershell
git status --short
rg --version
Get-Content -LiteralPath README.md -TotalCount 1
```

## PowerShell 内联命令引用规则

- 优先使用 `pwsh -NoLogo -NoProfile -File scripts/<name>.ps1` 运行项目脚本，避免把复杂逻辑堆进 `pwsh -Command`。
- 在 Windows/PowerShell 外层 shell 中调用 `pwsh -Command` 时，如果内联脚本包含 `$`、`$_`、变量、管道脚本块或 PowerShell 表达式，必须用外层单引号包住 `-Command` 内容。
- 正确示例：

```powershell
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion; $PSVersionTable.PSEdition'
```

- 错误示例：

```powershell
pwsh -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion; $PSVersionTable.PSEdition"
```

- 原因：外层 PowerShell 会先展开双引号中的 `$PSVersionTable`、`$_` 等变量，导致传给内层 `pwsh` 的脚本被破坏。
- 如果内联命令超过一行、包含多层引号、循环、条件或复杂管道，应改为脚本文件或拆成更小的验证命令。

## 权限失败与重试

- 同一命令在同一工作目录下因 `Permission denied`、`AccessDeniedException`、`EPERM`、`spawn EPERM`、`.git/*.lock`、`.git/FETCH_HEAD`、Maven/Node 缓存写入、`target` 写入、`node_modules/.cache` 写入、沙盒网络限制或 Codex sandbox 启动失败时，只允许普通权限失败一次。
- 首次普通权限失败必须记录到本地计划、提交说明、最终回复或其他 repo-local 交接位置。
- 后续遇到同类命令时，直接使用审批/提权路径，不再为了复现而普通权限试跑。
- 如果 `pnpm` 在 Codex Windows sandbox 普通权限下出现 `EPERM: operation not permitted, lstat 'C:\Users\<user>'`，先判断是否真的需要运行 `pnpm`。
  仅为调用已安装的本地包命令时，优先直接调用对应项目的 `node_modules/.bin/<tool>`，避免把包管理器启动行为混入质量门禁。
  确需 `pnpm install`、`pnpm add`、`pnpm update`、`pnpm test`、`pnpm build` 等包管理、测试或构建命令时，按本节权限失败规则记录并走审批/提权路径。
- `apps/web` 的 `pnpm typecheck`、`pnpm lint` 也归入上条同类命令，已确认在 Codex Windows sandbox 普通权限下会触发同样的 `C:\Users\<user>` 访问问题；不要先普通权限试跑。
- 不在质量门禁脚本中通过长期或隐式修改 `HOME`、`USERPROFILE`、`TEMP`、`TMP`、pnpm store/cache 等环境变量来绕过 `pnpm` 的本地环境问题；这类改动可能改变工具读取用户配置、临时文件、缓存或依赖仓库的行为，导致验证结果被环境差异污染。
- 已知需要直接走审批/提权路径的命令类别：
  - Git 写操作：`git add`、`git commit`、`git rebase`、`git merge`、`git checkout`、`git stash` 等会写 `.git` 的命令。
  - Git 网络操作：`git push`、`git fetch`、`git pull`、`git ls-remote`，以及依赖 GitHub 网络或凭据的 `gh` 命令。
  - 需要下载依赖或写外部缓存的命令，例如 Maven 首次解析新依赖、`pnpm install`。
  - 已知会写入或清理受限构建产物的命令，例如 Maven AOT/native/package、`pnpm test`、`pnpm build`。
- 只读排查命令仍优先普通权限执行，例如 `git status`、`git diff`、`git log`、`git rev-parse`、`rg`、`Get-Content`。
- 提权后仍失败时，必须记录 blocker、失败命令、失败摘要、影响判断和下一步 unblock 条件；禁止循环重复普通权限试跑。

## 验证与记录

- 完成一项实现后，应在最终回复或对应计划中说明执行过的验证命令、未验证内容和剩余风险。
- 验证命令按 `docs/QUALITY.md` 的分层策略执行：开发中跑最小命中验证，跨边界后跑聚合契约入口，提交前只跑一次相称总门禁。
- 如果某批文件在当前轮已经通过等价验证，且之后没有再修改相关文件，不要为了“再确认一次”重复运行同一批测试、类型检查或契约检查。
- 多端同步改动优先使用 `scripts/verify-changed.ps1 -Profile commit` 串行调度已有聚合脚本；需要强覆盖时使用 `-Profile full` 或严格 `scripts/quality-gate.ps1 -Scope changed`。
- Web 常规验证优先使用 `scripts/web-verify.ps1`；需要覆盖 build 时使用 `scripts/web-verify.ps1 -Build`。不要把 `pnpm test`、`pnpm typecheck` 和 `pnpm lint` 拆成多次工具调用，除非正在定位单项失败。
- 后端常规验证优先使用 `scripts/backend-verify.ps1`；需要覆盖 all-in-one AOT/package smoke 时使用 `scripts/backend-verify.ps1 -AotSmoke`。不要把空白检查、Boot 4 Jackson 检查、Maven 测试和 AOT smoke 拆成多次工具调用，除非正在定位单项失败。
- OpenAPI / Web 契约常规验证优先使用 `scripts/openapi-verify.ps1`，需要刷新快照和生成类型时使用 `scripts/openapi-verify.ps1 -RefreshSnapshots -GenerateTypes`，避免把多个底层脚本拆成多轮来回执行。
- Codex 内置浏览器可用于读取页面结构、DOM 状态、按钮集合和普通点击路径，但它的鼠标 hover 结果存在兼容性偏差。不要把内置浏览器观察到的 hover 显示或隐藏当作最终视觉结论；涉及 hover 样式、悬浮工具条或鼠标停留反馈时，以用户真实浏览器手测、Chrome 真实交互或可复现手工步骤为准。
- 如果故障属于本地环境问题，而不是项目代码问题，应说明判断依据，避免后续智能体误把环境问题当作仓库缺陷处理。
- 重复出现的操作失误或环境坑应沉淀为本文档规则，不能只依赖聊天记录。
