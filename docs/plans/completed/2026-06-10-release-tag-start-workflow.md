# Release tag start workflow

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户同意继续推进 tag-only 发布链路
- 创建时间：2026-06-10
- 完成时间：2026-06-10

## 目标

让公开主仓库在推送 `v*` release tag 后，自动计算发布上下文并触发后端私有仓库 `backend-release-resolve.yml`。

## 非目标

- 不在本切片实现 Web/Desktop/App 真实打包。
- 不把 `release.yml` 改成自动 publish。
- 不实跑完整 native-image fallback。
- 不改变 GitHub App secret 命名。
- 不从主仓库 checkout 后端私有源码。

## 实施计划

- [x] 固化 OpenAPI snapshot hash 计算脚本，供 release start 和后端 native 输入复用。
- [x] 新增主仓库 `release-start.yml`，监听 `push.tags: v*`，并保留手动 dry-run 入口用于 smoke。
- [x] release start checkout tag/ref，校验版本、root commit 和后端子模块指针。
- [x] 生成默认 required backend assets JSON。
- [x] 使用 `HDX Backend Actions Bot` token 触发后端 `backend-release-resolve.yml`，显式开启 `allow_native_build_fallback` 与 `trigger_release_assemble`。
- [x] 更新 ADR、runbook、workflow README、OpenAPI 契约文档和总纲。
- [x] 运行 actionlint、docs 门禁和远端 smoke。

## 实现记录

- 主仓库新增 `.github/workflows/release-start.yml`，正式路径监听 `push.tags: v*`，手动入口用于安全 dry-run。
- 主仓库新增 `scripts/openapi-snapshot-hash.ps1`，按 OpenAPI snapshot 文件相对路径、大小和文件 sha256 生成稳定 snapshot hash。
- release start 会计算 `version`、`root_ref`、`root_commit`、`backend_commit`、`openapi_hash`、`release_intent_id` 和默认 required backend assets。
- 正式触发后端 resolver 前，第一版要求 `services/backend` 子模块 commit 与后端私有仓库 `main` 指针一致。
- 触发后端 resolver 时传入 `allow_native_build_fallback=true` 和 `trigger_release_assemble=true`，由后端 resolver 决定复用历史主仓库 Release asset 或执行 native build fallback。
- 实现提交：`bcfa822035d753eaafb11c5f909ec817fe8be970`。

## 验收标准

- tag push 触发路径能从 tag/ref 推导出 version、root commit、backend commit、OpenAPI hash 和 release intent id。
- 触发后端 resolver 时不使用 `latest`。
- 后端 resolver 输入包含 `allow_native_build_fallback=true` 和 `trigger_release_assemble=true`。
- smoke 可以在不创建真实 tag 的情况下验证 context 计算和 workflow_dispatch 调用形状，避免误触发完整发布。

## 验证记录

- `actionlint .github/workflows/release-start.yml`
- `pwsh -NoLogo -NoProfile -File scripts/openapi-snapshot-hash.ps1 -Quiet`
  - 输出：`8df8f055bd59deba93fabca12cdb2788e54477ff0ce712269e245b90700a71a1`
- `git diff --check`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- 远端 smoke：`gh workflow run release-start.yml --repo xxldm/hdx --ref main -f version=v0.0.996-start.1 -f root_ref=refs/heads/main -f backend_repository=xxldm/hdx-backend -f dry_run=true -f trigger_backend_resolve=false`
  - run id：`27261244683`
  - 结论：`success`
  - head sha：`bcfa822035d753eaafb11c5f909ec817fe8be970`
  - 跳过项：GitHub App token 生成、后端 main 指针校验、后端 resolver 触发。
- `gh release list --repo xxldm/hdx --limit 20 --json tagName,isDraft,isPrerelease`
  - 输出：`[]`

## 归档备注

- 完整 tag push 到 publish 仍缺 Web/Desktop/App 构建和正式 publish。
- 真实 tag push 触发后可能进入 native-image fallback，需注意私有仓库 Actions 额度。
- 第一版 release start 为避免误触发私有后端错误版本，要求后端子模块 commit 与后端私有仓库 `main` 指针一致；后续如需支持非 `main` 后端发布分支，需要扩展输入和校验规则。
