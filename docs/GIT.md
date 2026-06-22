# Git 规则

本文档定义 HDX 工具箱的 Git 使用纪律。所有代码、文档、配置和生成产物变更都应遵守本文档；子模块内的变更还必须在对应子仓库内独立满足这些规则。

## 提交信息

- 提交信息使用中文。
- 提交信息使用约定式前缀，优先使用：`功能：`、`修复：`、`重构：`、`杂项：`。
- 每个提交只包含一个逻辑单元，避免把不相关修改堆在同一个提交里。

## 推送规则

- 智能体可以在任务流程需要时推送自己创建或更新的分支。
- 推送前必须确认目标 remote、目标分支、工作树状态、相关验证结果和敏感信息检查。
- 不得推送无关本地改动、他人未交接改动或真实密钥、令牌、证书和敏感数据。
- 不得在未说明风险和回滚方式的情况下执行 force push。
- 可用 `scripts/git-push-stack.ps1 -DryRun` 先预览后端、Web、Desktop 与根仓库的推送顺序和 ahead 状态，再去掉 `-DryRun` 串行推送。

## 智能体提交纪律

- 核心原则：严禁积压未提交改动。任何代码、文档或配置改动都必须被记录在 Git 历史中，不允许以“改了一堆文件但零 commit”的状态结束任务。
- 即使用户没有明确要求提交，智能体也应在相称验证通过后，按逻辑单元自动提交自己的改动。
- 如果工作开始前已经存在无关未提交改动，必须先识别并保护这些改动；只提交本轮自己产生的逻辑单元，不得顺手提交、覆盖或回滚他人改动。
- 如果因为已有脏工作树、验证失败、权限限制或用户指令而无法提交，最终输出必须明确说明未提交文件、原因、已完成验证和剩余风险。

## 提交前验证

- 提交前必须完成与变更范围相称的验证，最低要求见 `docs/QUALITY.md`。
- 代码或配置变更必须先通过对应测试、构建、脚本验证或清晰的手工复现步骤，确认没有错误后才能提交。
- 文档-only 变更至少要检查相关索引、入口说明和事实源之间是否一致。
- 如果本轮工作存在 Symphony、Linear 等 external task 或 `docs/plans/active/` 计划，提交前必须同步对应链接/编号、当前状态、checkbox 或状态表、状态记录、验证结果、剩余风险和相关 commit 占位。
- 完成的本地计划应随相关逻辑单元移动到 `docs/plans/completed/`；如果仍保留在 `active/`，必须在计划中说明原因和下一次清理条件。
- Warning 是否阻塞提交由当前模块质量门禁决定；没有明确规则时，必须在最终输出中说明保留的 Warning 和影响判断。

## 多仓库和子模块

- 根仓库与子模块仓库分开提交，不把子模块内部文件和根仓库文档、指针更新混成一个不清楚的提交。
- `services/backend/`、`apps/web/`、`apps/desktop/` 是子模块路径。子模块内改动应先在子模块仓库提交；如果需要更新根仓库记录的子模块指针，再在根仓库单独提交。
- 不在根仓库提交子模块内部未提交内容的替代说明；子模块自己的历史必须能恢复真实改动。
- 根仓库提交或推送子模块指针前，必须确认主仓库记录的每个子模块 commit 已经存在于对应子仓库远端，避免主仓库指向远端不可获取的 hash。推荐顺序是：先在子仓库提交并推送，再在根仓库更新、提交和推送子模块指针。
- 如果根仓库包含子模块指针变更，推送根仓库前必须检查相关子模块没有领先其远端分支；必要时用 `git -C <submodule-path> status --short --branch` 确认，或用 `git ls-remote <submodule-url> <commit-hash>` 验证该 hash 在远端可达。

## 提交编排脚本

本仓库提供保守的串行提交编排入口：

```powershell
pwsh -NoLogo -NoProfile -File scripts/git-commit-stack.ps1 -DryRun -StageAll -WebMessage "修复：..." -RootMessage "杂项：..."
pwsh -NoLogo -NoProfile -File scripts/git-commit-stack.ps1 -StageAll -WebMessage "修复：..." -RootMessage "杂项：..."
```

- 脚本按 `services/backend`、`apps/web`、`apps/desktop`、根仓库顺序串行处理，仍保持子模块和根仓库分开提交。
- 对存在改动的仓库，必须显式提供对应提交信息；没有提交信息会失败，不会静默跳过脏工作树。
- 默认只提交已暂存改动；只有显式传入 `-StageAll` 时才会对对应仓库执行 `git add -A`。
- 首次使用或范围不确定时先传 `-DryRun`，确认会提交哪些仓库和提交信息后再去掉。
- 该脚本不负责推送；推送仍遵守先子模块、后根仓库的顺序。

## 推送编排脚本

本仓库提供保守的串行推送编排入口：

```powershell
pwsh -NoLogo -NoProfile -File scripts/git-push-stack.ps1 -DryRun
pwsh -NoLogo -NoProfile -File scripts/git-push-stack.ps1
```

- 脚本按 `services/backend`、`apps/web`、`apps/desktop`、根仓库顺序串行处理，先推子模块再推根仓库。
- 推送前会要求对应仓库工作树干净；存在未提交改动时失败，不会带脏工作树推送。
- 每个仓库必须有明确 upstream；没有 upstream 时失败，不猜 remote 或目标分支。
- 没有 ahead 提交的仓库会跳过；有 ahead 提交时执行普通 `git push`。
- 脚本不提供 force push 参数；需要 force push 时必须单独说明风险和回滚方式后手动执行。
- 可用 `-SkipBackend`、`-SkipWeb`、`-SkipDesktop`、`-SkipRoot` 跳过对应仓库。

## Git 操作串行规则

- 所有 Git 写操作必须串行执行，禁止并发运行 `git add`、`git commit`、`git rebase`、`git stash`、`git checkout`、`git merge`、`git push` 等命令。
- 只有确认前一个 Git 命令已经完成，且仓库锁已释放后，才能启动下一个 Git 命令。
- 并行开发或多智能体协作时，由主智能体统一安排提交策略；多个子任务不得各自同时提交，避免历史冲突和责任边界不清。
