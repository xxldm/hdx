# Release App Token Check

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成，随本轮后续提交归档
- 计划来源：用户已创建 GitHub App 和主仓库 secrets，确认先做最小 token 验证 workflow
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

新增手动触发的 GitHub App token 最小验证 workflow，确认主仓库可以使用 `HDX_RELEASE_APP_CLIENT_ID` 和 `HDX_RELEASE_APP_PRIVATE_KEY` 生成 GitHub App installation token，并读取后端私有仓库与公开主仓库 metadata。

本轮完成后应具备：

- `.github/workflows/check-release-app-token.yml`
- workflow 使用 `workflow_dispatch` 手动触发。
- workflow 默认检查后端仓库 `xxldm/hdx-backend`。
- workflow 使用 GitHub App token 读取后端仓库 metadata。
- workflow 使用 GitHub App token 读取主仓库 metadata。
- workflow 不创建 Release，不下载 artifact，不上传 artifact，不输出 token。
- ADR 0013 和总纲记录该最小验证入口。

## 非目标

- 本轮不实现真实 GitHub Release workflow。
- 本轮不读取后端 Actions artifact 列表或下载 artifact。
- 本轮不创建、上传、发布或删除 GitHub Release。
- 本轮不修改 GitHub App、secrets 或后端私有仓库配置。

## repo 内范围

- `.github/workflows/check-release-app-token.yml`
- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-09-release-app-token-check.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增 GitHub App token check workflow。
- [x] 同步 ADR 0013 和总纲状态。
- [x] 运行本地 workflow lint 与 docs 质量门禁。
- [x] 提交推送。
- [x] 触发 GitHub-hosted token check 并记录结果。

## 验收标准

- workflow 不使用默认 `GITHUB_TOKEN` 访问目标仓库 metadata。
- workflow 生成后端仓库 token 时只请求 `permission-actions: read`。
- workflow 生成主仓库 token 时只请求 `permission-contents: read`。
- workflow 不打印 GitHub App private key、JWT 或 installation token。
- workflow 失败时不会创建 Release 或上传任何资产。

## 验证方式

- `actionlint`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`
- `gh workflow run check-release-app-token.yml --repo xxldm/hdx --ref main -f backend_repo=xxldm/hdx-backend`
- `gh run watch <run_id> --repo xxldm/hdx --exit-status`

## 风险与阻塞

- 如果 GitHub App 没有安装到 `xxldm/hdx-backend`，后端 metadata 检查会失败。
- 如果 GitHub App 权限未包含 Actions read 或 Contents read，token 生成或 metadata 检查会失败。
- 本轮只验证 metadata 读取，不代表 artifact 列表读取、artifact 下载或 Release 创建已可用。

## 状态记录

- 2026-06-09：创建计划，开始新增最小 token check workflow。
- 2026-06-09：新增 `.github/workflows/check-release-app-token.yml`，并同步 ADR 0013 与总纲状态。
- 2026-06-09：本地 `actionlint`、docs 质量门禁和空白检查通过；等待提交推送后触发 GitHub-hosted workflow。
- 2026-06-09：推送提交 `b3e1f43 功能：添加发布应用令牌验证` 后，触发 GitHub-hosted run `27186745870`；后端仓库 metadata 和主仓库 metadata 均读取成功。
- 2026-06-09：用户删除 `HDX_RELEASE_APP_ID` 后，将 workflow 切换为 `HDX_RELEASE_APP_CLIENT_ID` 与 `client-id` 输入，避免 `app-id` 弃用 warning。
- 2026-06-09：推送提交 `fe632c8 维护：切换发布令牌验证为客户端标识` 后，触发 GitHub-hosted run `27187218112`；后端仓库 metadata 和主仓库 metadata 均读取成功，日志筛选未命中 `deprecated`。

## 验证结果

- `actionlint`：通过，GitHub Actions workflow 语法级检查未发现问题。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认关键文档可读、根仓库空白检查、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- `git diff --check`：通过，仅提示部分文件后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- `gh workflow run check-release-app-token.yml --repo xxldm/hdx --ref main -f backend_repo=xxldm/hdx-backend`：通过，触发 run `27186745870`。
- `gh run watch 27186745870 --repo xxldm/hdx --exit-status`：通过，所有步骤成功。
- `gh run view 27186745870 --repo xxldm/hdx --json status,conclusion,headSha,event,url,jobs`：通过，确认 `status=completed`、`conclusion=success`、`event=workflow_dispatch`、`headSha=b3e1f435b1deeea2e362740382abb13af05bcb87`。
- `gh run view 27186745870 --repo xxldm/hdx --log | Select-String -Pattern "metadata 读取通过|deprecated|HDX Release App Token Check|status:"`：通过，确认后端仓库 metadata 和主仓库 metadata 均读取成功；同时确认 `actions/create-github-app-token@v3.2.0` 对 `app-id` 输入输出弃用 warning，后续已切换为 `client-id` 输入。
- `gh workflow run check-release-app-token.yml --repo xxldm/hdx --ref main -f backend_repo=xxldm/hdx-backend`：通过，切换为 `client-id` 后触发 run `27187218112`。
- `gh run watch 27187218112 --repo xxldm/hdx --exit-status`：通过，所有步骤成功。
- `gh run view 27187218112 --repo xxldm/hdx --json status,conclusion,headSha,event,url,jobs`：通过，确认 `status=completed`、`conclusion=success`、`event=workflow_dispatch`、`headSha=fe632c825d668d79316651d4da395de9285bb2f9`。
- `gh run view 27187218112 --repo xxldm/hdx --log | Select-String -Pattern "metadata 读取通过|deprecated|HDX Release App Token Check|status:"`：通过，确认后端仓库 metadata 和主仓库 metadata 均读取成功，且日志筛选未命中 `deprecated`。

## 剩余风险

- 本轮只验证 metadata 读取，不代表 artifact 列表读取、artifact 下载或 Release 创建已可用。
- 真实 release workflow、后端 artifact 下载、draft Release 创建、asset 上传和 publish 仍需后续小步实现验证。

## 相关 commit

- `b3e1f43 功能：添加发布应用令牌验证`
- `fe632c8 维护：切换发布令牌验证为客户端标识`
- 本计划随后续提交 `文档：记录发布应用令牌验证结果` 归档；具体哈希以 Git 历史为准。
