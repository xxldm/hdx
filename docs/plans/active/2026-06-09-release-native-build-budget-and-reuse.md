# Release Native 构建额度与复用策略

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中；后端 native 构建并行和历史复用策略已落地，主仓库 `release-start.yml` 和 `release.yml` 已有第一版，Web node-server asset、Desktop Online asset 与 Desktop Full asset 已接入 assemble。
  Release Start 精确提交模型已调整为按 root commit 中的 `services/backend` 子模块 hash 构建后端源码，不再要求该 hash 等于后端当前 `main`；历史 Release asset 复用判断已迁回主仓库，后端 resolver 已收缩为 native build resolver。
  Release Start 手动 dry-run 已支持预演后端来源判断且不触发后端或 assemble；Desktop Full sidecar 最小启动闭环和 Desktop 静态 Web UI + Rust BFF 已实现。
  Desktop Online 远端配置和远端 Rust BFF 认证转发已实现；仍缺 App 构建、正式 publish、失败清理和 Desktop Full 真实安装包验证。
- 计划来源：用户确认 `backend-services` 并行构建，并允许后端未变时复用上一版主仓库 Release asset
- 创建时间：2026-06-09
- 最后更新：2026-06-15（补充阅读指引并收敛当前状态）

## 阅读指引

后端 native 构建额度、历史 Release asset 复用、release start/resolver 边界和 tag-only 发布入口读这里。Web node-server、Desktop asset、Rust BFF 和安装包细节读 `2026-06-10-web-desktop-release-artifact-contract.md`。

## 目标

降低后端私有仓库 native-image 对发布时间和 GitHub Actions 私有额度的压力：

- `backend-services` 改为服务级并行 native 构建，再聚合为同一个平台包。
- 明确后端 native-image 是当前主要额度压力；Web、Desktop、App 和主仓库组装后续公开后可以按日常 CI 正常运行。
- 不新增候选发布分级。
- 真实 release workflow 在后端 native 输入未变化时，可以复用上一版或指定历史主仓库 Release 中的后端 native asset；当前先提供手动最小 draft 复用入口，完整发布链路后续整合。

## 非目标

- 本轮只设计完整真实 GitHub Release workflow 的第一版 job 图和输入边界，不创建 `.github/workflows/release.yml`，也不把手动最小 draft 复用入口实际整合进去。
- 本轮不修改 GitHub Actions 计费计划、预算或 runner 类型。
- 本轮不把后端 Actions artifact 保留期改长。
- 本轮不引入 S3、RustFS、云 OSS、独立 artifact 仓库或后端 private release 作为 native 存储。
- 本轮不调整安装器签名、公证、自动更新、release notes 或版本号策略。

## repo 内范围

- `docs/adr/0014-release-native-build-budget-and-reuse-strategy.md`
- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/RELEASE_RUNBOOK.md`
- `docs/README.md`
- `docs/CONSTRAINTS.md`
- `docs/ARCHITECTURE.md`
- `README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-09-release-native-build-budget-and-reuse.md`
- `packages/shared/contracts/release/release-manifest.schema.json`
- `packages/shared/contracts/release/README.md`
- `packages/shared/contracts/release/examples/`
- `.github/workflows/debug-release-draft-reuse-backend.yml`
- `scripts/release-draft-reuse-backend-assets.ps1`
- `scripts/release-manifest-check.ps1`
- `scripts/release-draft-minimal-assets.ps1`
- `services/backend/.github/workflows/backend-native-artifact.yml`
- `services/backend/README.md`

## 本地任务清单

- [x] 新增 ADR 0014，记录 native 构建并行和历史 Release asset 复用策略。
- [x] 将 `backend-services-linux-x64` 拆为服务级 matrix build job 和聚合 package job。
- [x] 将可选 `backend-services-windows-x64` 拆为服务级 matrix build job 和聚合 package job。
- [x] 更新后端 README 和根仓库事实源文档。
- [x] 运行 workflow 静态校验、打包脚本 dummy dry-run 和 release manifest 校验。
- [x] 运行 docs 质量门禁。
- [x] 提交并推送 `services/backend`。
- [x] 提交并推送根仓库文档和子模块指针。
- [x] 新增 `build_scope` 手动输入，支持只跑 `services-linux-only` 远端验证。
- [x] 触发 `services-linux-only` GitHub-hosted run，验证 matrix 并行和 `actions/download-artifact` 聚合。
- [x] 下载 `backend-services-linux-x64` artifact 并运行 release manifest 校验。
- [x] 扩展 `release-manifest.json` schema、样例和校验脚本，表达历史主仓库 Release asset 复用来源和 backend native fingerprint。
- [x] 让最小 draft 资产脚本为后端 native asset 写入 `backendNativeFingerprint`，避免新建的历史 draft 不能被复用入口消费。
- [x] 新增手动最小 draft 复用入口，下载历史主仓库 Release asset 并生成新的历史复用 `release-manifest.json`。
- [x] GitHub-hosted 实跑手动最小 draft 复用入口。
- [x] 设计正式 `release.yml` 第一版输入、job 图、后端来源解析、draft/publish 和失败处理边界。
- [x] 新增 tag-only 日常发布操作手册，记录发版前检查、推 tag、观察自动化、失败处理和禁止事项；GitHub App 权限配置属于一次性外部配置，不写入仓库手册。
- [x] 新增 OpenAPI snapshot hash 计算入口，避免 release start、后端 native 输入和复用校验继续依赖手动临时值。
- [x] 新增 `.github/workflows/release-start.yml` 第一版，真实 `v*` tag push 会计算发布上下文、优先尝试主仓库历史后端 asset 复用，复用失败时触发后端 release resolver；手动入口默认 dry-run。
- [x] 调整 Release Start 与后端 resolver/native build 的提交锁定边界：主仓库 release tag 锁定 root commit，root commit 中的 `services/backend` gitlink 锁定后端源码 commit；后端 workflow 可以从 `main` 启动控制平面，但源码 checkout 和 manifest 必须使用输入的 `backend_commit`。
- [x] 收缩发布职责边界：主仓库 `release-start.yml` 负责历史 Release asset 复用判断；后端 `backend-release-resolve.yml` 只负责 native build 和可选回调主仓库 assemble；两个 GitHub App 最大权限均不再需要 `Contents: read`。
- [x] 增强 Release Start 手动 dry-run：`dry_run=true` 时也预演历史 Release asset 复用判断，但不触发主仓库 `release.yml` 或后端 resolver。
- [x] 后续完善 `.github/workflows/release.yml`，把 Desktop Full Windows/Linux asset 构建接入真实 draft assemble。
- [ ] 后续完善 `.github/workflows/release.yml`，把 App 构建、正式 publish、失败清理和 Desktop Full 真实安装包验证整合成完整真实 GitHub Release workflow。

## 验收标准

- 默认后端 native workflow 仍产出 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` 三个最终 artifact。
- `backend-services-linux-x64` 的三个服务 native 编译在 matrix job 中并行运行，`max-parallel` 明确限制为 3。
- `backend-services-windows-x64` 仍默认关闭，仅在 `include_windows_services=true` 时按同样结构运行。
- 临时 service binary artifact 只在同一 workflow 内供聚合 job 使用，保留期仍为 1 天。
- 最终 `backend-services` archive 名称、内部结构、`backend-native-manifest.json` 和 `backend-services-manifest.json` 兼容现有 release 契约。
- 文档不再把“第一版不自动复用历史 Release 资产”描述为当前策略；当前策略应指向 ADR 0014 的 fingerprint 复用规则。
- 手动最小 draft 复用入口不 checkout 后端私有源码、不下载后端私有 Actions artifact、不运行 native-image、不 publish Release。
- 历史复用入口校验旧 release manifest、旧 backend native manifest、旧后端 native asset、fingerprint、sha256、size 和禁止文件扫描，并生成新的 `release-manifest.json`。

## 验证方式

- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`
- `pwsh -NoLogo -NoProfile -File services/backend/scripts/package-backend-native-artifact.ps1 ...`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples ...`
- `pwsh -NoLogo -NoProfile -File scripts/release-draft-reuse-backend-assets.ps1 ...`
- `actionlint .github/workflows/debug-release-draft-reuse-backend.yml`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git -C services/backend diff --check`
- `git diff --check`
- 本轮正式发布设计、日常操作手册和计划状态收口只做文档和契约一致性验证；不运行 GitHub-hosted release workflow。

## 风险与阻塞

- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- `release-manifest.json` schema、校验脚本、手动最小 draft workflow、主仓库 `release-start.yml` 和主仓库 `release.yml` draft assemble 第一版已能表达、校验、下载并重新上传历史 Release asset；ADR 0013/0014 已补齐 tag-only 目标发布设计，但完整 tag-only 自动发布链路仍未实现。
- OpenAPI snapshot hash 已由 `scripts/openapi-snapshot-hash.ps1` 固化；release start 使用该脚本生成后端 native 输入 hash。
- 旧后端 asset 的构建 `root.commit` 可能不同于新 Release 的 root commit；后续校验必须区分“当前发布事实源”和“历史后端 asset 构建来源”。
- 当前历史复用入口为保持 `backend-native-manifest.json` provenance，不重命名复用的后端 native asset；如需按新版本重命名，需要先设计 manifest rewrite 和校验规则。
- 正式 tag-only 自动发布链路已有 start、主仓库历史后端 asset 复用判断、后端 native build resolver、主仓库 assemble 第一片、Web node-server asset 构建、Desktop Online asset 构建、Desktop Full asset 构建、Desktop Full sidecar 最小启动闭环和 Desktop 静态 Web UI + Rust BFF。
  后续实现时仍必须按 ADR 0013/0014 补齐 App 构建、正式 publish、失败清理和 Desktop Full 真实安装包验证，避免直接复制 debug workflow 拼接成正式发布。

## 状态记录

- 2026-06-09：创建 ADR 0014，完成后端 services native 服务级 matrix 构建与聚合策略；`build_scope=services-linux-only` 允许只跑 Linux services 验证。首次远端 run `27201075082` 暴露 `actions/download-artifact@v7.0.1` 不存在，修正为 `v7.0.0` 后 run `27202869734` 通过，最终 artifact `7506747699` 通过两层 manifest 校验。
- 2026-06-09：落地历史主仓库 Release asset 复用契约、`release-draft-minimal-assets.ps1`、`release-draft-reuse-backend-assets.ps1` 和 debug workflows。GitHub-hosted run `27209181697` 创建可复用历史 draft，run `27209326174` 复用历史后端 native asset 创建新 draft；测试 draft Release 与 tag 已按用户确认清理。
- 2026-06-09 至 2026-06-12：补齐正式发布设计和 tag-only 操作手册；`release-start.yml` 按 root commit 中的 `services/backend` gitlink 锁定后端源码，主仓库负责历史 asset 复用判断，后端 resolver 只负责 native build 与可选 assemble 回调；手动 dry-run run `27403306816` 验证不会触发后端或 assemble。
- 2026-06-12 至 2026-06-13：`release.yml` 接入 Web node-server、Desktop Online 和 Desktop Full asset 构建第一片；Desktop Full 通过 `resolve-backend-native` 消费后端 asset，包内携带已解压 `backend-full` 与 `backend-build.json`。Desktop 静态 Web UI + Rust BFF 已接入，Online 远端配置当时未实现，后续已在 Web/Desktop 发布产物计划中关闭。
- 逐条命令输出、临时失败细节和完整 run 日志不再保留在 active plan；需要审计时看本文件 2026-06-15 压缩前的 Git 历史，重复性命令/环境踩坑沉淀到 `docs/AGENT_WORKFLOW.md` 或脚本。

## 验证结果

- 本计划有效验证以当前摘要为准：`actionlint` 覆盖后端 native workflow、release start、release assemble、debug reuse 和 app-token check workflow；`git diff --check` 与后端子仓库 diff check 通过，仅保留 Git for Windows 换行提示。
- 后端 native services 并行构建远端验证：GitHub-hosted run `27202869734` 通过，三个 Linux service binary job 并行成功，最终 `backend-services-linux-x64` artifact 下载、聚合、sha256/size、禁止文件扫描和两层 manifest 校验通过。
- 历史 Release asset 复用验证：本地 draft minimal/reuse 脚本 dry-run 通过；GitHub-hosted run `27209181697` 和 `27209326174` 分别验证历史 draft 创建与历史后端 native asset 复用；远端 manifest 回读确认 `historical-release-asset` 来源和 `backendNativeFingerprint`。
- 发布控制面验证：`check-release-app-token.yml` run `27402944650` 通过；`Release Start` 手动 dry-run run `27403306816` 通过，确认 dry-run 只预演后端来源判断，不触发主仓库 assemble、后端 App token 或后端 resolver。
- 本地质量门禁：多次 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild` 通过，覆盖关键文档、release manifest、OpenAPI 契约、OpenAPI 类型生成和 Web 类型对齐检查；后端 `-NoBuild` 检查仅保留 Maven/Jansi Java 25 warning，不影响静态校验结论。

## 剩余风险

- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- 完整真实 tag-only 发布已有设计记录和日常操作手册；主仓库 tag start、后端 release resolve、主仓库 release assemble、Web node-server asset、Desktop Online asset、Desktop Full asset 构建、Desktop Full sidecar 最小启动闭环和 Desktop 静态 Web UI + Rust BFF 已有第一片。
  Desktop Online 远端配置和远端 Rust BFF 认证转发已实现；App 构建、正式 publish、失败清理和 Desktop Full 真实安装包验证仍未串成完整 workflow。
- OpenAPI snapshot hash 已由 `scripts/openapi-snapshot-hash.ps1` 固化，当前 hash 由 release start 自动计算。
- 后端 workflow 控制平面仍通过后端仓库 `main` 上的 workflow 文件启动；源码 checkout 已锁定 `backend_commit`，但如果未来需要复现旧 workflow 逻辑本身，需要另行设计 workflow 版本化或 release 分支策略。
- 主仓库 release start 当前通过 `workflow_dispatch` 触发后续 workflow；若给很旧的 root commit 打 tag，而该 tag 对应提交本身没有当前发布 workflow，需要改用当前 `main` 上的手动入口或后续设计 workflow 版本化策略。
- `backend-services-windows-x64` 仍默认不跑，本轮仅验证 workflow 静态结构和 Windows 聚合打包脚本路径。
- 测试 draft Release `v0.0.0-services-parallel.2` 和 `v0.0.0-services-parallel.3` 已清理；后续如果再次做远端 release 验证，仍需在完成后删除测试 draft 和确认 tag ref 不存在。

## 相关 commit

- `c8d2aea 功能：并行构建后端 services native`（`services/backend`）
- `e7815f1 功能：记录 native 构建额度与复用策略`（根仓库）
- `0f520ab 功能：支持按范围构建后端 native`（`services/backend`）
- `b5759ac 修复：修正后端 artifact 下载 action 版本`（`services/backend`）
- 历史复用契约、校验脚本、正式发布设计和日常操作手册更新由本计划后续提交记录补齐。
