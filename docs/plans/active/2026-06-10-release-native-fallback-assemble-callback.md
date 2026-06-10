# Release 后端 native fallback 与 assemble 回调

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中
- 计划来源：用户同意继续做后端 resolver 的 native build fallback 和回调主仓库 assemble
- 创建时间：2026-06-10

## 目标

让后端 `backend-release-resolve.yml` 在历史 Release asset 不能复用时，能够进入后端 native build fallback，并在解析出后端来源后可回调主仓库 `release.yml` 继续 assemble。

## 非目标

- 不实现主仓库 tag push start workflow。
- 不把主仓库 `release.yml` 改成自动 publish。
- 不补 Web、Desktop、App 真实打包。
- 不改变后端 native artifact 的打包格式、manifest schema 或 Release asset 文件名规则。
- 不默认在手动排障时创建主仓库 draft Release；assemble 回调通过显式输入开启。

## 设计要点

- `backend-release-resolve.yml` 先尝试历史 Release asset 复用。
- 历史复用失败时，如果开启 native fallback，则调用现有 `backend-native-artifact.yml` reusable workflow 生产后端 Actions artifact。
- fallback 生成 `github-actions-artifact` 模式的 `backend_sources_json`，其中 `runId` 指向当前 resolver run，artifact name 使用既有命名规则。
- resolver 最终统一上传 `backend-source-resolution-<version>` artifact，便于排障和手动重跑。
- 如果显式开启 assemble callback，resolver 使用 `HDX Main Workflow Bot` token 触发主仓库 `release.yml`，并传入 `backend_source_mode`、`backend_sources_json` 和发布上下文。

## 实施计划

- [x] 为 `backend-native-artifact.yml` 增加 `workflow_call` 入口，保留现有手动 `workflow_dispatch`。
- [x] 调整 `backend-release-resolve.yml`：历史复用失败不立即终止，而是输出失败原因和 fallback 上下文。
- [x] 增加 native build fallback job，复用后端 native artifact workflow，不复制 native-image 构建步骤。
- [x] 增加最终解析结果 job，统一上传 `backend-source-resolution-<version>` artifact。
- [x] 增加可选 assemble callback，触发主仓库 `release.yml`。
- [x] 更新 README、ADR、release runbook 和总纲状态。
- [ ] 运行 actionlint、本地文档门禁，并按可控成本做 GitHub Actions smoke。

## 验收标准

- 历史复用成功时仍输出 `historical-release-asset` payload。
- 历史复用失败且未开启 fallback 时，workflow 给出明确失败原因，不静默成功。
- 历史复用失败且开启 fallback 时，workflow 调用后端 native artifact workflow，并输出 `github-actions-artifact` payload。
- assemble callback 开启时，后端 resolver 能触发主仓库 `release.yml`。
- 手动排障默认不创建主仓库 draft Release，避免误发布或产生脏 release。

## 剩余风险

- fallback 真正执行 native-image 会消耗私有仓库 Actions 额度；本切片优先验证编排和 callback，完整 native-image smoke 需按成本单独确认。
- 主仓库 `release.yml` 仍只创建 draft，不构建 Web/Desktop/App，也不 publish。
