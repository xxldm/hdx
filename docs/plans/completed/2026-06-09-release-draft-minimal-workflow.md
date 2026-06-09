# 主仓库 Draft Release 最小闭环

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成；GitHub-hosted workflow 已创建测试 draft Release、上传资产并完成远端下载校验
- 计划来源：用户确认继续推进真实 GitHub Release workflow 的最小闭环
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

在公开主仓库新增手动 workflow，验证真实发布主链路的最小闭环：

- 使用 GitHub App token 读取后端私有仓库指定 Actions artifact。
- 下载并校验 `backend-native-manifest.json` 与后端 native archive。
- 生成最小 `release-manifest.json` 与 `SHA256SUMS`。
- 使用 GitHub App token 在主仓库创建 draft GitHub Release。
- 上传后端 native archive、`backend-native-manifest.json`、`release-manifest.json` 和 `SHA256SUMS`。
- 从远端 draft Release 下载资产并核对文件名、size 和 sha256。
- 验证通过后仍保持 draft，不自动 publish。

## 非目标

- 本轮不 publish 正式 Release。
- 本轮不构建 Web、Desktop 或 App。
- 本轮不实现 `backend-services`、Windows native artifact、安装器签名、公证、自动更新、release notes 或版本号策略。
- 本轮不自动清理失败 draft Release 或 Git tag。

## repo 内范围

- `.github/workflows/release-draft-minimal.yml`
- `scripts/release-draft-minimal-assets.ps1`
- `docs/plans/completed/2026-06-09-release-draft-minimal-workflow.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增最小 Release 资产整理脚本。
- [x] 新增 draft Release 最小闭环 workflow。
- [x] 本地用已下载后端 artifact 验证资产整理脚本。
- [x] 运行 `actionlint`、docs 质量门禁和空白检查。
- [x] 提交并推送。
- [x] 触发 GitHub-hosted workflow 并记录结果。

## 验收标准

- workflow 使用 GitHub App token 下载后端 artifact，不 checkout 后端私有源码。
- workflow 使用 GitHub App token 创建和写入主仓库 draft Release，不使用默认 `GITHUB_TOKEN` 发布资产。
- 所有输入禁止使用 `latest`。
- 后端 artifact 下载后必须校验 manifest、sha256、size 和禁止文件扫描。
- draft Release 上传后必须从远端下载资产并重新核对 size 和 sha256。
- 验证通过后 Release 仍保持 draft，不自动 publish。
- 失败时如果 draft 已创建，则保持 draft 供排障，不自动发布。

## 验证方式

- `pwsh -NoLogo -NoProfile -File scripts/release-draft-minimal-assets.ps1 ...`
- `actionlint .github/workflows/release-draft-minimal.yml`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`
- `gh workflow run release-draft-minimal.yml --repo xxldm/hdx --ref main ...`
- `gh run watch <run_id> --repo xxldm/hdx --exit-status`
- `gh run view <run_id> --repo xxldm/hdx --json status,conclusion,headSha,event,url,jobs`

## 风险与阻塞

- 本轮验证依赖后端 artifact `7500484195`；该 artifact 过期时间为 `2026-06-10T06:52:18Z`，过期后需要重跑后端 native workflow。
- GitHub App 必须安装到主仓库并具备 contents write 权限，否则 draft Release 创建或 asset 上传会失败。
- 本轮已创建测试 draft Release 和对应 tag；Release 仍保持 draft，未 publish。
- 本轮不自动清理测试 draft Release 或 Git tag；后续是否保留、删除或复用为下一次测试入口，由用户决定。

## 状态记录

- 2026-06-09：创建计划，开始实现主仓库 draft Release 最小闭环。
- 2026-06-09：新增 `scripts/release-draft-minimal-assets.ps1`，用于从已下载后端 artifact 生成最小 Release 资产、`release-manifest.json` 和 `SHA256SUMS`，并复用 release 校验脚本完成本地校验。
- 2026-06-09：新增 `.github/workflows/release-draft-minimal.yml`，用于下载后端 artifact、生成资产、创建 draft Release、上传资产并远端下载回校验；workflow 不 checkout 后端私有源码，不 publish Release。
- 2026-06-09：本地使用已下载的后端 artifact `target/backend-artifact-check/27188320676` 验证资产整理脚本通过，随后提交推送并触发 GitHub-hosted workflow。
- 2026-06-09：主仓库提交 `d8c40db` 已推送到 `origin/main`，触发 GitHub-hosted workflow run `27191204936`。
- 2026-06-09：GitHub-hosted run `27191204936` 通过，job `80271608920` 在主仓库提交 `d8c40db92d8aa28f0884466dd151abd57ae64b06` 上完成；日志确认 artifact 定位、最小 Release 资产生成、draft Release 创建、资产上传和远端下载校验均通过。
- 2026-06-09：测试 draft Release 已创建；GitHub API 返回 `tagName=v0.0.0-artifact-test.2`、`targetCommitish=fe497d1d17baafd4b0ab3f2942d6a0c8ad63a0b4`、`isDraft=true`，draft URL 为 `https://github.com/xxldm/hdx/releases/tag/untagged-b43af9fa30866a1cba8a`。

## 验证结果

- `pwsh -NoLogo -NoProfile -File scripts/release-draft-minimal-assets.ps1 -ArtifactRoot target\backend-artifact-check\27188320676 -Version v0.0.0-artifact-test.2 -RootRepository xxldm/hdx -RootRef refs/heads/main -RootCommit fe497d1d17baafd4b0ab3f2942d6a0c8ad63a0b4 -BackendRepository xxldm/hdx-backend -BackendCommit 051760d590ac2a49ad7ecb4bf1cd643d74ab7b20 -BackendRunId 27188320676 -BackendRunAttempt 1 -BackendArtifactName hdx-backend-native-v0.0.0-artifact-test.2-linux-x64 -OpenApiSnapshotHash 6f25f723550eecbeedbe2aca1f23070411a2d81be5127d8fc27643ffab91505c -BackendArtifactId 7500484195`：通过，生成并校验 `backend-native-manifest.json`、`hdx-backend-full-linux-x64-v0.0.0-artifact-test.2.tar.gz`、`release-manifest.json` 和 `SHA256SUMS`。
- `actionlint .github/workflows/release-draft-minimal.yml`：通过。
- `git diff --check`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认 docs 质量门禁、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- `git push origin main`：通过，主仓库 `main` 从 `3dc919c` 推进到 `d8c40db`。
- `gh workflow run release-draft-minimal.yml --repo xxldm/hdx --ref main ...`：通过，触发 run `27191204936`。
- `gh run watch 27191204936 --repo xxldm/hdx --exit-status`：通过，workflow conclusion 为 `success`。
- `gh run view 27191204936 --repo xxldm/hdx --json status,conclusion,headSha,event,url,jobs`：通过，`headSha=d8c40db92d8aa28f0884466dd151abd57ae64b06`，job `80271608920` 成功。
- `gh run view 27191204936 --repo xxldm/hdx --log | Select-String ...`：通过，关键日志包含 `artifact 定位通过`、`Draft Release 最小资产已生成`、`draft Release 创建完成`、`Release 资产上传完成` 和 `远端 draft Release asset 校验通过`。
- `gh release view v0.0.0-artifact-test.2 --repo xxldm/hdx --json url,isDraft,tagName,targetCommitish,assets`：通过，确认 draft Release 保持 `isDraft=true`，包含 4 个资产：`backend-native-manifest.json`、`hdx-backend-full-linux-x64-v0.0.0-artifact-test.2.tar.gz`、`release-manifest.json` 和 `SHA256SUMS`。

## 剩余风险

- 测试 draft Release `v0.0.0-artifact-test.2` 已保留为 draft；是否删除或继续保留供排障，需要用户后续决定。
- 正式 publish、Web/Desktop/App 资产、`backend-services`、Windows native artifact、签名、公证、自动更新、release notes 和版本号策略仍未实现。

## 相关 commit

- `d8c40db`：功能：添加 draft Release 最小闭环
