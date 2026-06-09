# 主仓库后端 Artifact 下载校验

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成；主仓库 GitHub-hosted workflow 已使用 GitHub App token 下载并校验后端 artifact
- 计划来源：用户要求先做主仓库侧验证，确认主仓库可使用 GitHub App token 下载后端 artifact 并校验内容
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

在公开主仓库新增手动验证入口，使用 GitHub App token 读取后端私有仓库指定 run 的 Actions artifact，下载后校验 `backend-native-manifest.json`、native archive 的 sha256/size 和禁止文件扫描。

本轮完成后应具备：

- `.github/workflows/release-backend-artifact-check.yml`
- `scripts/release-backend-artifact-check.ps1`
- workflow 输入后端仓库、run id、artifact name、版本、root ref、root commit、后端 commit 和 OpenAPI snapshot hash。
- workflow 使用 `HDX_RELEASE_APP_CLIENT_ID` 与 `HDX_RELEASE_APP_PRIVATE_KEY` 生成后端仓库 GitHub App token。
- workflow 只请求后端仓库 Actions read 权限。
- workflow 不 checkout 后端私有源码，不创建 Release，不上传 asset。
- workflow 下载后端 artifact 后运行本地脚本校验 manifest、sha256、size 和禁止文件扫描。

## 非目标

- 本轮不实现真实 GitHub Release workflow。
- 本轮不创建 draft Release。
- 本轮不上传 Web、Desktop、App 或后端 Release asset。
- 本轮不实现 `backend-services` 或 Windows native artifact。
- 本轮不固化 OpenAPI snapshot 集合 hash 算法，只沿用后端 artifact 生产入口已显式传入的 hash。

## repo 内范围

- `.github/workflows/release-backend-artifact-check.yml`
- `scripts/release-backend-artifact-check.ps1`
- `docs/plans/completed/2026-06-09-release-backend-artifact-check.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增后端 artifact 下载校验脚本。
- [x] 新增主仓库手动 workflow。
- [x] 本地用已下载 artifact 验证脚本。
- [x] 运行 `actionlint`、docs 质量门禁和空白检查。
- [x] 提交并推送。
- [x] 触发 GitHub-hosted workflow 并记录结果。

## 验收标准

- workflow 使用 GitHub App token 读取后端 artifact，不使用默认 `GITHUB_TOKEN` 跨仓库读取后端私有仓库。
- workflow 不 checkout 后端私有源码。
- workflow 下载的 artifact 必须与输入的 run id、artifact name、版本、root commit、后端 commit 和 OpenAPI hash 一致。
- 校验失败时不创建 Release、不上传 asset。
- artifact 过期时失败信息明确提示需要重跑后端 native workflow。

## 验证方式

- `pwsh -NoLogo -NoProfile -File scripts/release-backend-artifact-check.ps1 ...`
- `actionlint .github/workflows/release-backend-artifact-check.yml`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`
- `gh workflow run release-backend-artifact-check.yml --repo xxldm/hdx --ref main ...`
- `gh run watch <run_id> --repo xxldm/hdx --exit-status`

## 风险与阻塞

- 本轮验证使用的后端 artifact `7500484195` 保留期为 1 天，过期时间 `2026-06-10T06:52:18Z`；后续复跑同一验证如果 artifact 过期，需要重跑后端 native workflow。
- 正式 release workflow 仍未实现；本轮只是下载和校验切片。

## 状态记录

- 2026-06-09：创建计划，开始新增主仓库后端 artifact 下载校验入口。
- 2026-06-09：新增 `scripts/release-backend-artifact-check.ps1`，用于校验下载后的后端 artifact 目录、manifest 上下文、native archive sha256/size 和禁止文件扫描。
- 2026-06-09：新增 `.github/workflows/release-backend-artifact-check.yml`，使用 GitHub App token 读取后端 run artifact 列表并下载指定 artifact；workflow 不 checkout 后端私有源码、不创建 Release、不上传 asset。
- 2026-06-09：本地使用已下载的后端 artifact `target/backend-artifact-check/27188320676` 验证新脚本通过，随后提交推送并用 GitHub-hosted workflow 验证跨仓库下载链路。
- 2026-06-09：主仓库提交 `f5fd55a` 已推送到 `origin/main`，触发 GitHub-hosted workflow run `27190000244`。
- 2026-06-09：GitHub-hosted run `27190000244` 通过，job `80267675961` 在主仓库提交 `f5fd55a527e070a24c6108e8819110c43fdc44e3` 上完成；日志确认 artifact `7500484195` 定位、下载、解包和内容校验通过。

## 验证结果

- `pwsh -NoLogo -NoProfile -File scripts/release-backend-artifact-check.ps1 -ArtifactRoot target\backend-artifact-check\27188320676 -ExpectedVersion v0.0.0-artifact-test.2 -ExpectedRootRepository xxldm/hdx -ExpectedRootRef refs/heads/main -ExpectedRootCommit fe497d1d17baafd4b0ab3f2942d6a0c8ad63a0b4 -ExpectedBackendRepository xxldm/hdx-backend -ExpectedBackendCommit 051760d590ac2a49ad7ecb4bf1cd643d74ab7b20 -ExpectedRunId 27188320676 -ExpectedRunAttempt 1 -ExpectedArtifactName hdx-backend-native-v0.0.0-artifact-test.2-linux-x64 -ExpectedOpenApiSnapshotHash 6f25f723550eecbeedbe2aca1f23070411a2d81be5127d8fc27643ffab91505c`：通过，确认本地下载 artifact 内容校验通过。
- `actionlint .github/workflows/release-backend-artifact-check.yml`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认 docs 质量门禁、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- `git diff --check`：通过。
- `git push origin main`：通过，主仓库 `main` 从 `6165661` 推进到 `f5fd55a`。
- `gh workflow run release-backend-artifact-check.yml --repo xxldm/hdx --ref main ...`：通过，触发 run `27190000244`。
- `gh run watch 27190000244 --repo xxldm/hdx --exit-status`：通过，workflow conclusion 为 `success`。
- `gh run view 27190000244 --repo xxldm/hdx --json status,conclusion,headSha,event,url,jobs`：通过，`headSha=f5fd55a527e070a24c6108e8819110c43fdc44e3`，job `80267675961` 成功。
- `gh run view 27190000244 --repo xxldm/hdx --log | Select-String ...`：通过，关键日志包含 `artifact 定位通过`、`Release manifest 校验完成` 和 `后端 Actions artifact 下载内容校验通过`。

## 剩余风险

- 正式 release workflow、draft Release、Release asset 上传、`backend-services` 和 Windows native artifact 仍未实现。
- OpenAPI snapshot 集合 hash 算法仍未固化；本轮沿用后端 artifact 生产入口显式传入的 hash。

## 相关 commit

- `f5fd55a`：功能：添加后端 artifact 下载校验
