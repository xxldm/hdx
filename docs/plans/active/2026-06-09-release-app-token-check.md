# Release App Token Check

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：本地验证通过，待提交推送后触发 GitHub-hosted 验证
- 计划来源：用户已创建 GitHub App 和主仓库 secrets，确认先做最小 token 验证 workflow
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

新增手动触发的 GitHub App token 最小验证 workflow，确认主仓库可以使用 `HDX_RELEASE_APP_ID` 和 `HDX_RELEASE_APP_PRIVATE_KEY` 生成 GitHub App installation token，并读取后端私有仓库与公开主仓库 metadata。

本轮完成后应具备：

- `.github/workflows/release-app-token-check.yml`
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

- `.github/workflows/release-app-token-check.yml`
- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-09-release-app-token-check.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增 GitHub App token check workflow。
- [x] 同步 ADR 0013 和总纲状态。
- [x] 运行本地 workflow lint 与 docs 质量门禁。
- [ ] 提交推送。
- [ ] 触发 GitHub-hosted token check 并记录结果。

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
- `gh workflow run release-app-token-check.yml --repo xxldm/hdx --ref main -f backend_repo=xxldm/hdx-backend`
- `gh run watch <run_id> --repo xxldm/hdx --exit-status`

## 风险与阻塞

- 如果 GitHub App 没有安装到 `xxldm/hdx-backend`，后端 metadata 检查会失败。
- 如果 GitHub App 权限未包含 Actions read 或 Contents read，token 生成或 metadata 检查会失败。
- 本轮只验证 metadata 读取，不代表 artifact 列表读取、artifact 下载或 Release 创建已可用。

## 状态记录

- 2026-06-09：创建计划，开始新增最小 token check workflow。
- 2026-06-09：新增 `.github/workflows/release-app-token-check.yml`，并同步 ADR 0013 与总纲状态。
- 2026-06-09：本地 `actionlint`、docs 质量门禁和空白检查通过；等待提交推送后触发 GitHub-hosted workflow。

## 验证结果

- `actionlint`：通过，GitHub Actions workflow 语法级检查未发现问题。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认关键文档可读、根仓库空白检查、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- `git diff --check`：通过，仅提示部分文件后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。
- GitHub-hosted token check：待提交推送后触发。

## 剩余风险

- 待验证后同步。

## 相关 commit

- 待记录。
