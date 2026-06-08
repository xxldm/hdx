# 自动化质量门禁

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成。
- 计划来源：HDX 后续事项总纲第 4 步
- 创建时间：2026-06-07
- 最后更新：2026-06-07

## 目标

建立一个 repo-local 的最小质量门禁脚本，让人工、Symphony 和后续智能体可以用同一入口检查根仓库、后端子模块和 Web 子模块的常用验证命令。

## 非目标

- 本轮不接入远端 CI。
- 本轮不引入新包管理器、lint 框架或第三方扫描工具。
- 本轮不实现完整密钥扫描、OpenAPI 生成、架构依赖图检查或 native-image 完整编译。
- 本轮不改变后端、Web 或 App 的技术栈。

## repo 内范围

- `scripts/quality-gate.ps1`
- `docs/QUALITY.md`
- `README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-07-automated-quality-gate.md`

## 已确认策略

- 脚本使用 PowerShell，放在根仓库 `scripts/` 下。
- 默认 `-Scope changed`，根据 Git 改动判断需要跑的模块，避免每次都全量重跑。
- 支持显式范围：`all`、`backend`、`web`、`docs`、`changed`。
- 后端验证入口使用 `services/backend/README.md` 记录的 Maven 路径和 GraalVM JDK 25 路径；当前 Codex shell 不可靠依赖全局 `PATH`。
- Web 验证入口在 `apps/web/` 下执行 `pnpm test`、`pnpm typecheck`、`pnpm lint`、`pnpm build`。
- 子模块状态检查通过 `scripts/git-submodule-status.ps1` 包装：优先执行 `git submodule status`，如果当前 Git for Windows 脚本环境因缺少 `basename`、`sed` 或 `git-sh-setup` 失败，则自动使用 Git Bash fallback，最后退到 `git ls-files -s` 指针检查；子仓库工作区状态仍用 `git -C <submodule> status --short --branch` 展示。
- Git 写操作、Maven/Node 构建类命令仍遵守 `docs/GIT.md` 的权限失败重试规则。

## 本地任务清单

- [x] 新增 `scripts/quality-gate.ps1`。
- [x] 支持 changed/all/backend/web/docs 范围选择。
- [x] 支持 `-SkipBackend`、`-SkipWeb` 和 `-NoBuild` 这类轻量控制参数。
- [x] 输出中文步骤标题、执行命令、耗时和失败位置。
- [x] 更新 `docs/QUALITY.md`，把脚本列为本地质量门禁入口。
- [x] 更新根 README，补充质量门禁入口。
- [x] 更新后续事项总纲第 4 步状态。
- [x] 运行脚本自检和相称验证。
- [x] 提交并推送。

## 验收标准

- 后续智能体可以通过根仓库脚本找到并运行常用质量门禁。
- 默认 changed 模式不会在没有相关改动时强制跑后端和 Web 全量验证。
- all 模式能够按顺序跑根仓库检查、后端验证和 Web 验证。
- 脚本失败时能明确显示失败命令和模块。
- 质量文档记录脚本入口、适用范围、失败处理和剩余风险。

## 验证方式

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope changed -NoBuild`
- 根据脚本改动结果决定是否补充后端或 Web 的直接验证命令。

## 状态记录

- 2026-06-07：用户确认进入“自动化质量门禁”切片；创建本地计划，开始实现最小 PowerShell 脚本入口。
- 2026-06-07：新增 `scripts/quality-gate.ps1`，首版脚本改为 ASCII 源码加运行时 Unicode 解码，避免 Windows PowerShell 5.1 在非 UTF-8 解析脚本中文字符串时出现 parser error。
- 2026-06-07：`git submodule status` 在当前环境曾因缺少 Unix 辅助命令失败，本脚本当时改为分别读取根仓库、`services/backend` 和 `apps/web` 的 `git status --short --branch`。
- 2026-06-08：新增 `scripts/git-submodule-status.ps1`，让质量门禁可重新执行子模块状态检查；直接 `git submodule status` 失败时自动使用 Git Bash fallback 或 `git ls-files -s` 指针检查，避免检查误失败。
- 2026-06-07：创建并推送根仓库提交 `3a18291 功能：添加本地质量门禁脚本`。

## 验证结果

- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认关键文档可按 UTF-8 读取，根仓库 `git diff --check` 通过。
- `[System.Management.Automation.PSParser]::Tokenize(...)`：通过，脚本 parse error 数量为 0。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope changed -NoBuild`：通过；当前只检测到 docs/scripts 改动，因此只运行文档与根仓库检查，未触发后端或 Web 构建。

## 剩余风险

- 脚本首版只覆盖本地常用命令，不等同于远端 CI。
- Web `pnpm` 在 Codex 普通权限下可能因读取用户目录触发 `EPERM`，需要按 `docs/GIT.md` 权限失败重试规则走提权。
- 后端 Maven 构建在 Codex 普通权限下可能因 `target` 写入失败，需要按权限规则走提权。
- 当前不做完整 native-image 编译；涉及 native 构建参数、Spring AOT、RuntimeHints 或 Hibernate enhance 时仍需按 `docs/CONSTRAINTS.md` 单独执行 native 验证。

## 相关 commit

- `3a18291 功能：添加本地质量门禁脚本`（根仓库）
