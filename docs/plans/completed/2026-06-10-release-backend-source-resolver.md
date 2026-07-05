# Release 后端来源解析

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意继续实现后端来源解析切片
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

补齐发布链路中“后端 native 来源从哪里来”的解析层，让后续 tag-only 发布不再依赖人工手写完整 `backend_sources_json`。

## 非目标

- 不在本切片实现完整 tag-only 发布。
- 不在本切片接入 Web、Desktop 或 App 真实打包。
- 不改变后端 native-image 的构建产物格式。
- 不 publish Release；仍保持 draft assemble 边界。

## repo 内范围

- 主仓库 release 相关脚本和文档。
- 后端私有仓库 release resolve workflow 入口。
- release 相关 ADR、runbook、workflow 索引和总纲计划。

## 实施结果

- [x] 梳理 ADR 0013/0014 中的 release start、backend release resolve 和 release assemble 边界。
- [x] 确认 resolver 的最小输入、输出和落点。
- [x] 实现一个可本地验证的最小 resolver 切片，优先覆盖历史 Release asset 复用结果生成。
- [x] 为无法复用历史资产的情况输出明确的后端 native build 后续条件。
- [x] 更新文档，避免把 resolver 描述成完整 tag-only 自动发布。
- [x] 运行相关 workflow、script 和 docs 验证。

## 实现记录

- 新增 `scripts/release-resolve-backend-sources.ps1`，从指定历史主仓库 Release 目录解析后端 native 来源，校验 `release-manifest.json`、`backend-native-manifest.json`、资产 sha256、size、kind、platform、root commit、backend commit 和 OpenAPI snapshot hash，并生成可供当前 `release.yml` 消费的 compact `backend_sources_json`。
- 新增后端私有仓库 `.github/workflows/backend-release-resolve.yml`，支持手动输入 release 版本、root/backend 提交、OpenAPI hash、候选历史 Release tag 和 required assets，使用 `HDX Main Workflow Bot` 的 `Contents: read` token checkout 主仓库发布工具、下载候选主仓库 Release asset 后调用主仓库 resolver，并上传 `backend-source-resolution-<version>` artifact，保留期 1 天。
- 后端 resolver workflow 只覆盖历史 Release asset 复用解析；当前可解析指定历史 Release，或在未指定时只检查最新一个合格已发布 Release，不触发 native-image、不回调主仓库 assemble。
- 更新 `docs/ARCHITECTURE.md`、`docs/RELEASE_RUNBOOK.md`、ADR 0013、ADR 0014、release contracts README 和总纲计划，明确当前能力与未完成边界。

## 验证记录

- `actionlint services/backend/.github/workflows/backend-release-resolve.yml`
- `pwsh -NoLogo -NoProfile -Command '[scriptblock]::Create((Get-Content -LiteralPath "scripts/release-resolve-backend-sources.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-assemble-historical-backend-assets.ps1" -Raw)) | Out-Null; [scriptblock]::Create((Get-Content -LiteralPath "scripts/release-manifest-check.ps1" -Raw)) | Out-Null'`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`
- `pwsh -NoLogo -NoProfile -File scripts/release-resolve-backend-sources.ps1 -HistoricalAssetRoot target/release-assemble-test/assets -RequiredAssetsJsonPath target/release-resolve-test/required-assets.json -Version v0.1.1 -RootRepository xxldm/hdx -RootRef refs/tags/v0.1.1 -RootCommit 3333333333333333333333333333333333333333 -BackendRepository xxldm/hdx-backend -BackendCommit 2222222222222222222222222222222222222222 -OpenApiSnapshotHash aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -OutputPath target/release-resolve-test/backend-source-resolution.json`
- `git -C services/backend diff --check`
- `git -C services/backend diff --cached --check`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- GitHub Actions smoke run `27256705032`：失败，默认 `github.token` 无法在后端私有仓库 workflow 中 checkout 主仓库，报错 `repository 'https://github.com/xxldm/hdx/' not found`。
- GitHub Actions smoke run `27257119592`：失败，已进入 `actions/create-github-app-token@v3.2.0`，但 `HDX Main Workflow Bot` 当前安装未授予 `Contents: read`，报错 `The permissions requested are not granted to this installation.`。
- smoke 使用的两个临时主仓库 draft Release `v0.0.0-resolver-smoke.20260610140148` 和 `v0.0.0-resolver-smoke.20260610141215` 已清理；`gh release list --repo xxldm/hdx --limit 20 --json tagName,name,isDraft,isPrerelease` 返回 `[]`。
- GitHub Actions smoke run `27257508573`：失败，`HDX Main Workflow Bot` 的 `Contents: read` token 可以 checkout 主仓库，但 `gh release download` 无法按 tag 读取 draft Release；真实历史 Release 复用路径应使用已发布 Release，而不是 draft。
- GitHub Actions smoke run `27257591366`：失败，临时 prerelease 下载成功，但 resolver 输出路径写到了后端仓库 `target/`，被主仓库脚本的 target 边界检查拒绝；后续已改为输出到 `hdx-root/target/`。
- GitHub Actions smoke run `27257846087`：通过。后端 workflow 成功生成主仓库 `Contents: read` GitHub App token、checkout 主仓库、下载临时已发布 prerelease assets、调用 resolver、上传 `backend-source-resolution-v0.0.0-resolver-smoke.20260610143018` artifact。下载 artifact 后确认 `backendSourceMode=historical-release-asset`，并解析出 `backend-full/linux-x64` 与 `backend-services/linux-x64` 两个历史 asset 来源。
- 最终 smoke 使用的临时主仓库 prerelease `v0.0.0-resolver-smoke.20260610143018` 已通过 `gh release delete ... --cleanup-tag` 清理。

## 剩余风险

- 自动历史复用第一版只检查最新一个合格 Release；如果它不匹配但更老 Release 可复用，当前仍会进入后续 native build 分支。
- 匹配失败后尚未自动触发后端 native-image workflow。
- 后端 resolver 尚未用 GitHub App token 回调主仓库正式 assemble。
- 后端仓库必须持续配置 `HDX_MAIN_WORKFLOW_APP_CLIENT_ID` 和 `HDX_MAIN_WORKFLOW_APP_PRIVATE_KEY`，且对应 GitHub App 安装到主仓库并具备 `Contents: read`；真实历史复用来源必须是已发布 Release，不能依赖 draft Release。

## 相关 commit

- 后端私有仓库：`1325207122030068624dbc3dd22720c3ba4bdb34`（功能：添加后端来源解析入口）
- 后端私有仓库：`6e82b610adb92127265d8c8d7280038035d00137`（修复：使用主仓库 GitHub App token 解析 release）
- 后端私有仓库：`2dd1a5a9c6421f674d25ddfbfd98c3efdb45f33f`（修复：调整后端来源解析输出路径）
- 主仓库：本完成计划所在提交。
