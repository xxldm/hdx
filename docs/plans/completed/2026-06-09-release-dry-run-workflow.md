# Release Dry Run Workflow

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成，随本轮提交归档
- 计划来源：用户确认先做主仓库 GitHub Actions release dry-run 骨架
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

新增公开主仓库 release dry-run workflow，用于演练发布链路的输入校验、root ref checkout、release manifest 校验和发布摘要生成。

本轮完成后应具备：

- 手动触发的 GitHub Actions workflow。
- 输入 `version`、`root_ref` 和 dry-run 保护开关。
- 不创建 GitHub Release，不上传 release asset，不下载后端私有 artifact，不使用跨仓库 secret。
- 不 checkout 后端私有源码；只记录根仓库锁定的子模块指针。
- 运行 `scripts/release-manifest-check.ps1`，复用本地 release manifest 校验入口。
- 输出 dry-run summary，列出后续真实发布需要接入的步骤。

## 非目标

- 本轮不实现真实 GitHub Release 创建或 asset 上传。
- 本轮不接入后端私有仓库 artifact 下载、repository dispatch 或跨仓库 token。
- 本轮不构建 Web、Desktop、App 或后端 native。
- 本轮不实现安装器签名、公证、自动更新、release notes 或版本号策略。

## repo 内范围

- `.github/workflows/release-dry-run.yml`
- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/adr/0012-github-releases-artifact-boundary.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-09-release-dry-run-workflow.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增 release dry-run workflow。
- [x] 更新 README、架构、ADR 和总纲状态。
- [x] 运行 release 校验和 docs 质量门禁。
- [x] 归档计划并提交推送。

## 验收标准

- workflow 使用 `workflow_dispatch` 手动触发。
- workflow 权限保持 `contents: read`。
- workflow checkout root ref 时不初始化子模块，避免读取私有后端源码。
- workflow 不包含 `gh release create`、`softprops/action-gh-release`、`actions/upload-release-asset`、跨仓库 token 或后端 artifact 下载步骤。
- workflow 会运行 `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`。
- 文档说明 dry-run 与真实发布的边界差异。

## 验证方式

- `rg -n "release-dry-run|workflow_dispatch|contents: read|submodules: false|release-manifest-check|gh release|upload-release|BACKEND|secret|dry_run" .github docs README.md`
- `actionlint`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 风险与阻塞

- 本地无法真正执行 GitHub-hosted workflow；本轮只能做静态检查和本地脚本验证。
- dry-run 不初始化子模块，因此只能记录根仓库锁定的子模块指针，不能验证私有后端 artifact 或真实子模块 checkout。
- 正式发布仍需要后续单独设计跨仓库触发、artifact 下载权限、真实 release asset 一致性、Release 上传、签名、公证、自动更新、release notes 和版本号策略。

## 状态记录

- 2026-06-09：创建计划并开始实施。
- 2026-06-09：新增 `.github/workflows/release-dry-run.yml`，使用手动触发、只读权限、指定 root ref checkout、子模块指针记录和 release manifest 校验；不初始化私有后端子模块、不下载后端 artifact、不创建 Release、不上传 asset。
- 2026-06-09：完成 README、架构、ADR 0012 和总纲同步，完成本地验证并归档计划。

## 验证结果

- `rg -n "workflow_dispatch|contents: read|submodules: false|persist-credentials: false|release-manifest-check|dry_run" .github/workflows/release-dry-run.yml`：通过，确认 workflow 具备手动触发、只读权限、禁用子模块 checkout、禁用 checkout 凭据持久化和 release manifest 校验入口。
- `rg -n "gh release|upload-release|action-gh-release|download-artifact|repository_dispatch|secrets|GITHUB_TOKEN|actions/upload-artifact" .github/workflows/release-dry-run.yml`：无匹配，确认本 dry-run workflow 未包含真实 Release 创建、上传、artifact 下载、跨仓库触发或凭据引用。
- `actionlint -version`：通过，当前版本为 `1.7.12`。
- `actionlint`：通过，GitHub Actions workflow 语法级检查未发现问题。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过，确认 release manifest schema 和样例检查仍通过。
- `git diff --check`：通过，仅提示部分文件后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认 docs 质量门禁已运行 release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查。

## 剩余风险

- 本轮没有在 GitHub-hosted runner 实际触发 workflow；真实运行仍需在 GitHub Actions 页面手动验证一次。
- dry-run 不初始化子模块，因此只能记录根仓库锁定的子模块指针，不能验证私有后端 artifact 或真实子模块 checkout。
- 正式发布仍需要后续单独设计跨仓库触发、artifact 下载权限、真实 release asset 一致性、Release 上传、签名、公证、自动更新、release notes 和版本号策略。

## 相关 commit

- 本计划随本轮提交 `功能：添加发布演练工作流` 归档；具体哈希以 Git 历史为准。
