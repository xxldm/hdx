# 正式 release.yml 第一版落地

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意继续落地正式 `release.yml` 第一版
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

新增主仓库正式发布入口 `.github/workflows/release.yml` 的第一版骨架，让已验证的后端 native asset 交接、draft Release 创建、资产上传和远端回读校验从 `debug-*` 入口迁移到正式命名 workflow。

## 非目标

- 不在本切片实现完整 tag-only 自动链路。
- 不实现后端 release resolve workflow，也不让主仓库 checkout 后端私有源码。
- 不实现 Web、Desktop、App 真实打包。
- 不实现多后端 native asset 聚合、正式 publish、安装器签名、公证、自动更新、release notes 或版本号策略。

## repo 内范围

- `.github/workflows/release.yml`
- `.github/workflows/README.md`
- `docs/ARCHITECTURE.md`
- `docs/RELEASE_RUNBOOK.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- 本计划文件

## 实施计划

- [x] 新增正式 `release.yml`，提供 `workflow_dispatch` 入口，输入字段贴近 ADR 0013 的主仓库 release assemble payload。
- [x] 支持 `github-actions-artifact` 来源：按显式后端 repo、run id 和 artifact name 下载后端 Actions artifact。
- [x] 支持 `historical-release-asset` 来源：按显式历史主仓库 Release tag 和 asset name 下载历史后端 native asset。
- [x] 复用既有 release 脚本生成 `release-manifest.json`、`SHA256SUMS` 和 draft Release asset。
- [x] 创建 draft Release、上传资产、远端下载并校验 size 与 sha256。
- [x] 更新发布文档，明确第一版 `release.yml` 的能力和未完成项。
- [x] 运行 workflow 静态检查、release 脚本检查、docs 质量门禁和空白检查。

## 验收标准

- `release.yml` 不使用 `latest`，不 checkout 后端私有源码。
- `release.yml` 默认只创建并校验 draft Release，不 publish。
- 后端来源必须显式来自 `backend_sources_json`，不从主仓库猜测最新后端 run、artifact 或 Release。
- `check-*`、`debug-*` 与正式 `release.yml` 的职责在 `.github/workflows/README.md` 中可区分。
- 文档说明第一版仍不是完整 tag-only 发布链路。

## 剩余风险

- 第一版只支持单个后端 native asset 来源，不能一次聚合 `backend-full` Windows/Linux 与 `backend-services` Linux 默认发布集。
- 正式 tag-only start、后端 release resolve、主仓库 assemble 自动触发、Web/Desktop/App 真实打包和 publish 仍需后续切片。
- 未进行 GitHub-hosted 真机实跑前，`release.yml` 只完成静态和本地脚本级验证。

## 验证结果

- 已执行 `actionlint .github/workflows/release.yml`：通过。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过。
- 已执行 `git diff --check`：通过，仅出现 Git for Windows 行尾提示。
- 已执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。

## 相关 commit

- 本提交：`功能：添加正式 release 工作流骨架`。
