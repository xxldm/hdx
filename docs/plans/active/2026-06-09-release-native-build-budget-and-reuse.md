# Release Native 构建额度与复用策略

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：见下方 active plan 状态块。
- 计划来源：用户确认后端 native 构建需要并行、可复用历史主仓库 Release asset，并确认后端实现细节不继续写入公开主仓库。
- 创建时间：2026-06-09
- 最后更新：2026-07-05（公开文档边界收口）

<!-- active-plan-status:start -->
- 何时读取：后端 native release asset、GitHub Actions release start、历史 Release asset 复用、公开 release manifest 和发布验证相关任务。
- 当前状态：`v0.0.0-preview.5` 已验证 tag-only 预览发布和 Desktop Full Linux AppImage smoke；`v0.0.0-preview.6` 因后端 native 构建停滞取消。GraalVM 25.1.3 相关后端内部调整已收口到后端私有文档；公开仓库只记录 release 资产边界和复用策略。后端 Release 包已确认只发布 native，不发布 JVM/JAR/WAR/`.class`/源码包。
- 下一步：不自动恢复发布；standalone 服务端单体 release artifact 接入需要另行确认后再做。preview/stable tag、远端 release native 复验、stable 正式发布和真实安装包矩阵验证需要另行确认后再做。
- 主要剩余风险：新增 release 超时/诊断仍未在远端卡住场景复验；后端 native 构建资源占用仍可能波动。standalone 服务端单体 release artifact 接入和 native runtime smoke 仍待后续切片；stable 发布、完整安装包矩阵、Windows services、旧 workflow、很旧 tag 入口和 App 发布闭环仍待后续处理。
<!-- active-plan-status:end -->

## 阅读指引

后端 native 构建额度、历史 Release asset 复用、release start/resolver 边界和 tag-only 发布入口读这里。

后端模块名/服务名不敏感，可以在 release asset、Nacos 模板、OpenAPI 快照和公开部署说明中出现。后端职责拆分、调用关系、运行形态、基础设施适配、native/AOT 诊断和实现验证记录不写在公开主仓库，入口为 `services/backend/README.md` 与 `services/backend/docs/README.md`。如果没有后端私有仓库权限，只能依据本文件的公开 release 边界推进。

Web node-server、Desktop asset、Rust BFF 和安装包细节读 `docs/plans/active/2026-06-10-web-desktop-release-artifact-contract.md`。

## 目标

降低后端私有仓库 native-image 对发布时间和 GitHub Actions 私有额度的压力：

- 后端 services 形态按服务级并行 native 构建，再聚合为同一个平台包。
- 明确后端 native-image 是当前主要额度压力；Web、Desktop、App 和主仓库组装后续公开后可以按日常 CI 正常运行。
- 真实 release workflow 在后端 native 输入未变化时，可以复用上一版或指定历史主仓库 Release 中的后端 native asset。
- 公开主仓库只记录 release 资产契约、复用判断、发布入口和验证边界，不复制后端内部实现细节。

## 非目标

- 本计划不记录后端内部职责图、依赖裁剪、基础设施适配、数据迁移细节或 native build report 诊断明细。
- 本计划不修改 GitHub Actions 计费计划、预算或 runner 类型。
- 本计划不把后端 Actions artifact 保留期改长。
- 本计划不引入 S3、RustFS、云 OSS、独立 artifact 仓库或后端 private release 作为 native 存储。
- 本计划不调整安装器签名、公证、自动更新、release notes 或版本号策略。

## repo 内范围

- `docs/adr/0014-release-native-build-budget-and-reuse-strategy.md`
- `docs/adr/0013-release-workflow-token-and-artifact-policy.md`
- `docs/adr/0017-backend-native-delivery-and-standalone-boundary.md`
- `docs/RELEASE_RUNBOOK.md`
- `docs/README.md`
- `docs/CONSTRAINTS.md`
- `docs/ARCHITECTURE.md`
- `docs/AGENT_BRIEF.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-09-release-native-build-budget-and-reuse.md`
- `packages/shared/contracts/release/release-manifest.schema.json`
- `packages/shared/contracts/release/README.md`
- `packages/shared/contracts/release/examples/`
- `.github/workflows/debug-release-draft-reuse-backend.yml`
- `scripts/release-draft-reuse-backend-assets.ps1`
- `scripts/release-manifest-check.ps1`
- `scripts/release-draft-minimal-assets.ps1`
- `services/backend/README.md`（后端私有文档入口，不在主仓库复制细节）

## 本地任务清单

- [x] 新增 ADR 0014，记录 native 构建并行和历史 Release asset 复用策略。
- [x] 将后端 services Linux native 构建拆为服务级 matrix build job 和聚合 package job。
- [x] 保留后端 services Windows native 构建的可选入口，默认不跑。
- [x] 更新后端 README 和根仓库事实源文档。
- [x] 运行 workflow 静态校验、打包脚本 dummy dry-run 和 release manifest 校验。
- [x] 运行 docs 质量门禁。
- [x] 提交并推送后端私有仓库相关 release workflow 更新。
- [x] 提交并推送根仓库文档和子模块指针。
- [x] 新增手动构建范围输入，支持只跑 services Linux 远端验证。
- [x] 触发 services Linux GitHub-hosted run，验证 matrix 并行和 artifact 聚合。
- [x] 下载 services Linux artifact 并运行 release manifest 校验。
- [x] 扩展 `release-manifest.json` schema、样例和校验脚本，表达历史主仓库 Release asset 复用来源和 backend native fingerprint。
- [x] 让最小 draft 资产脚本为后端 native asset 写入 `backendNativeFingerprint`，避免新建的历史 draft 不能被复用入口消费。
- [x] 新增手动最小 draft 复用入口，下载历史主仓库 Release asset 并生成新的历史复用 `release-manifest.json`。
- [x] GitHub-hosted 实跑手动最小 draft 复用入口。
- [x] 设计正式 `release.yml` 第一版输入、job 图、后端来源解析、draft/publish 和失败处理边界。
- [x] 新增 tag-only 日常发布操作手册，记录发版前检查、推 tag、观察自动化、失败处理和禁止事项。
- [x] 新增 OpenAPI snapshot hash 计算入口，避免 release start、后端 native 输入和复用校验继续依赖手动临时值。
- [x] 新增 `.github/workflows/release-start.yml` 第一版，真实 `v*` tag push 会计算发布上下文、优先尝试主仓库历史后端 asset 复用，复用失败时触发后端 release resolver；手动入口默认 dry-run。
- [x] 调整 Release Start 与后端 resolver/native build 的提交锁定边界：主仓库 release tag 锁定 root commit，root commit 中的 `services/backend` gitlink 锁定后端源码 commit。
- [x] 收缩发布职责边界：主仓库 `release-start.yml` 负责历史 Release asset 复用判断；后端 resolver 只负责 native build 和可选回调主仓库 assemble。
- [x] 增强 Release Start 手动 dry-run：`dry_run=true` 时也预演历史 Release asset 复用判断，但不触发主仓库 `release.yml` 或后端 resolver。
- [x] 完善 `.github/workflows/release.yml`，接入 Web node-server asset、Desktop Online asset 和 Desktop Full asset 构建。
- [x] 完善 `.github/workflows/release.yml`，接入 `release_mode=publish`、stable/preview 发布区分、preview prerelease 和 Desktop asset channel。
- [x] 完成真实 tag-only 预览发布链路验证和 Desktop Full Linux 真实 AppImage 启动/API smoke。
- [x] 清空当前 Actions 临时 artifacts/cache，并在发布成功路径补齐已消费 artifacts 的自动清理。
- [x] 为 release native build 步骤补充单步超时、Maven 日志落盘和失败 job summary 诊断。
- [x] 后端内部 GraalVM 25.1.3 复测、依赖裁剪、服务端单体边界、职责拆分和验证记录已迁入后端私有文档入口。
- [ ] 后续完善失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和真实安装包矩阵验证。App 当前暂不进入发布闭环。
- [ ] 后续确认是否将 standalone 服务端单体 native artifact 接入正式 release 流程；接入前需先完成后端私有仓库内的 native 编译和 runtime smoke。

## 验收标准

- 默认后端 native workflow 仍产出 Full 和 Services 两类公开 release artifact。
- 后端 services Linux native 构建在 matrix job 中并行运行，聚合后产出兼容现有 release 契约的 archive 与 manifest。
- 后端 services Windows native 构建仍默认关闭，仅在显式输入时运行。
- 临时 service binary artifact 只在同一 workflow 内供聚合 job 使用，聚合成功后尽力删除；失败时短期保留用于排障。
- 主仓库 release assemble 成功上传并远端校验 Release 资产后，尽力删除已消费的临时 artifacts；删除失败不应阻塞已成功的 Release。
- 手动最小 draft 复用入口不 checkout 后端私有源码、不下载后端私有 Actions artifact、不运行 native-image、不 publish Release。
- 历史复用入口校验旧 release manifest、旧 backend native manifest、旧后端 native asset、fingerprint、sha256、size 和禁止文件扫描，并生成新的 `release-manifest.json`。
- 公开主仓库文档不再复制后端内部职责拆分、调用关系、基础设施适配、native/AOT 诊断或服务端单体实现细节，只保留必要模块/服务名和私有文档入口。

## 验证方式

- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`
- `pwsh -NoLogo -NoProfile -File services/backend/scripts/package-backend-native-artifact.ps1 ...`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples ...`
- `pwsh -NoLogo -NoProfile -File scripts/release-draft-reuse-backend-assets.ps1 ...`
- `actionlint .github/workflows/debug-release-draft-reuse-backend.yml`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git -C services/backend diff --check`
- `git diff --check`

## 风险与阻塞

- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- Actions storage 本轮瓶颈主要来自大体积临时 artifacts。cache 继续保留以降低构建时间，但如果单仓库 cache 接近上限，需要再单独调整。
- 旧后端 asset 的构建 `root.commit` 可能不同于新 Release 的 root commit；后续校验必须区分“当前发布事实源”和“历史后端 asset 构建来源”。
- 当前历史复用入口为保持后端 native manifest provenance，不重命名复用的后端 native asset；如需按新版本重命名，需要先设计 manifest rewrite 和校验规则。
- 新增 release 超时/诊断还没有用新的 preview/stable tag 在远端卡住场景复验。
- standalone 服务端单体 release artifact 尚未接入正式 release 流程；接入前必须先完成后端私有仓库内的 native 编译和 runtime smoke。
- 失败 draft 人工清理演练、stable 正式发布验证、release artifact 上下文一致性和真实安装包矩阵验证仍未完成。App 当前暂不进入发布闭环。

## 状态记录

- 2026-06-09：创建 ADR 0014，完成后端 services native 服务级 matrix 构建与聚合策略；首次远端 services Linux 验证通过，最终 artifact 通过两层 manifest 校验。
- 2026-06-09：落地历史主仓库 Release asset 复用契约、最小 draft 资产脚本、历史复用脚本和 debug workflows；GitHub-hosted 实跑验证历史后端 native asset 可复用。
- 2026-06-09 至 2026-06-12：补齐正式发布设计和 tag-only 操作手册；Release Start 按 root commit 中的 `services/backend` gitlink 锁定后端源码，主仓库负责历史 asset 复用判断，后端 resolver 只负责 native build 与可选 assemble 回调。
- 2026-06-12 至 2026-06-13：`release.yml` 接入 Web node-server、Desktop Online 和 Desktop Full asset 构建第一片；Desktop Full 消费后端 Full native asset。
- 2026-06-15 至 2026-06-16：真实 preview tag 链路逐步验证；`v0.0.0-preview.2` 已成功发布为 prerelease，`v0.0.0-preview.5` 已通过 Desktop Full Linux AppImage sidecar/API smoke。
- 2026-06-16：`v0.0.0-preview.6` 暴露后端 native 构建长时间停滞并被取消；后端私有仓库补充 native build 单步超时和失败诊断，远端卡住场景仍待后续 preview/stable tag 复验。
- 2026-07-03 至 2026-07-05：GraalVM 25.1.3、后端依赖裁剪、服务端单体边界和后端职责拆分相关实现与验证记录已迁入后端私有文档；公开主仓库只保留 release 资产边界、复用策略、必要模块/服务名和私有文档入口。

## 验证结果

- 后端 native services 并行构建远端验证通过，最终 services Linux artifact 下载、聚合、sha256/size、禁止文件扫描和两层 manifest 校验通过。
- 历史 Release asset 复用验证通过，本地 dry-run 与 GitHub-hosted run 均确认可基于历史主仓库 Release asset 生成新的 release manifest。
- 发布控制面 dry-run 验证通过，确认 dry-run 只预演后端来源判断，不触发主仓库 assemble、后端 App token 或后端 resolver。
- 公开端资产检查已验证 Web node-server、Desktop Online Windows/Linux 和 Desktop Full Linux AppImage 关键路径；Desktop Full Linux 真实 AppImage 已在 `v0.0.0-preview.5` 通过 sidecar/API smoke。
- 公开主仓库的后端内部实现记录已收口为私有文档入口；后端内部验证摘要以 `services/backend/docs/README.md` 路由为准。

## 剩余风险

- 后端 native 构建资源占用仍可能波动，远端 release native 卡住风险还没有用新的 preview/stable tag 复验。
- standalone 服务端单体 release artifact 接入前仍需重新跑后端私有仓库内的真实 native 编译和 runtime smoke。
- 完整真实 tag-only 预览发布已有第一片；失败 draft 人工清理演练、stable 正式发布验证、release artifact 上下文一致性和真实安装包矩阵验证仍未完成。
- 后端 workflow 控制平面仍通过后端仓库当前 workflow 文件启动；如果未来需要复现旧 workflow 逻辑本身，需要另行设计 workflow 版本化或 release 分支策略。
- 主仓库 release start 当前通过 `workflow_dispatch` 触发后续 workflow；若给很旧的 root commit 打 tag，而该 tag 对应提交本身没有当前发布 workflow，需要改用当前 `main` 上的手动入口或后续设计 workflow 版本化策略。

## 相关 commit

- `c8d2aea 功能：并行构建后端 services native`（`services/backend`）
- `e7815f1 功能：记录 native 构建额度与复用策略`（根仓库）
- `d09384c 修复：稳定 Desktop 发布资产打包`（根仓库）
- `0f520ab 功能：支持按范围构建后端 native`（`services/backend`）
- `b5759ac 修复：修正后端 artifact 下载 action 版本`（`services/backend`）
- 历史复用契约、校验脚本、正式发布设计和日常操作手册更新由本计划后续提交记录补齐。
