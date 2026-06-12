# Release Native 构建额度与复用策略

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中；后端 native 构建并行和历史复用策略已落地，主仓库 `release-start.yml` 和 `release.yml` 已有第一版，Web node-server asset 与 Desktop Online asset 已接入 assemble；Release Start 精确提交模型已调整为按 root commit 中的 `services/backend` 子模块 hash 构建后端源码，不再要求该 hash 等于后端当前 `main`；历史 Release asset 复用判断已迁回主仓库，后端 resolver 已收缩为 native build resolver；仍缺 Desktop Full/App 构建、正式 publish 和失败清理。
- 计划来源：用户确认 `backend-services` 并行构建，并允许后端未变时复用上一版主仓库 Release asset
- 创建时间：2026-06-09
- 最后更新：2026-06-11

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
- [ ] 后续完善 `.github/workflows/release.yml`，把 Desktop Full/App 构建、正式 publish 和失败清理整合成完整真实 GitHub Release workflow。

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
- 正式 tag-only 自动发布链路已有 start、主仓库历史后端 asset 复用判断、后端 native build resolver、主仓库 assemble 第一片、Web node-server asset 构建和 Desktop Online asset 构建；后续实现时仍必须按 ADR 0013/0014 补齐 Desktop Full/App 构建、组装、draft、远端校验和 publish，避免直接复制 debug workflow 拼接成正式发布。

## 状态记录

- 2026-06-09：创建计划并新增 ADR 0014。
- 2026-06-09：已将 `backend-services` Linux/Windows workflow 结构改为服务级 matrix build job 加聚合 package job；Windows services 仍由 `include_windows_services=true` 控制。
- 2026-06-09：已同步后端 README、README、约束、架构、ADR 0012/0013、release 契约说明和总纲状态；ADR 0013 的“第一版不复用”已保留为历史状态，并明确当前后端 native 复用边界由 ADR 0014 替代。
- 2026-06-09：本地 dummy dry-run 首次从根仓库 cwd 调用打包脚本时，`-OutputDirectory target/...` 被脚本判定不在后端仓库 `target/` 下并拒绝；随后按 workflow 真实 cwd `services/backend` 复跑通过。
- 2026-06-09：release manifest 校验首次把外层 `backend-native-manifest.json` 与包内 `backend-services-manifest.json` 混用同一个 `-AssetRoot`，脚本正确拒绝；随后按外层输出目录和包内 stage 根目录分别校验通过。
- 2026-06-09：`services/backend` commit `c8d2aea 功能：并行构建后端 services native` 已推送到 `origin/main`。
- 2026-06-09：根仓库 commit `e7815f1 功能：记录 native 构建额度与复用策略` 已推送到 `origin/main`，记录 ADR 0014、active 计划和 `services/backend` 子模块指针。
- 2026-06-09：开始补充 `build_scope` 手动输入，目标是在不重跑 full Linux/Windows 的情况下只验证 `backend-services-linux-x64` 并行构建和聚合下载。
- 2026-06-09：`services/backend` commit `0f520ab 功能：支持按范围构建后端 native` 已推送到 `origin/main`；workflow 新增 `build_scope=services-linux-only`，可只运行 Linux services matrix build 与聚合 package job。
- 2026-06-09：首次 `services-linux-only` 远端 run `27201075082` 已触发；`backend-full-linux-x64`、`backend-full-windows-x64`、Windows services build 和 Windows services 聚合均按预期跳过，Linux `backend-auth-service`、`backend-gateway` 和 `backend-core-service` 三个 service binary job 并行运行并全部成功。
- 2026-06-09：run `27201075082` 的 Linux services 聚合 job 在 `Set up job` 阶段失败，未进入 artifact 下载或打包；原因判断为 workflow 引用了不存在的 `actions/download-artifact@v7.0.1`，公开 action tag 存在 `v7` / `v7.0.0`，不存在 `v7.0.1`。已改为 `actions/download-artifact@v7.0.0`，需要重新触发一次 `services-linux-only` 验证。
- 2026-06-09：`services/backend` commit `b5759ac 修复：修正后端 artifact 下载 action 版本` 已推送到 `origin/main`。
- 2026-06-09：第二次 `services-linux-only` 远端 run `27202869734` 已成功；`backend-full-linux-x64`、`backend-full-windows-x64`、Windows services build 和 Windows services 聚合均按预期跳过，Linux `backend-auth-service`、`backend-gateway` 和 `backend-core-service` 三个 service binary job 并行运行并全部成功，最终 `Backend services linux-x64` 聚合 job 已成功下载三个临时二进制、打包并上传最终 artifact。
- 2026-06-09：run `27202869734` 的 native-image 构建步骤耗时分别为 auth 约 17 分 43 秒、gateway 约 19 分 09 秒、core 约 25 分 25 秒；最终聚合 job 约 1 分 02 秒，services-only 墙钟时间约 26 分钟，验证了等待时间由最慢服务主导而不是三个服务串行累加。
- 2026-06-09：run `27202869734` 的最终 artifact `hdx-backend-services-native-v0.0.0-services-parallel.2-linux-x64` ID 为 `7506747699`，大小 `232079179` bytes，过期时间 `2026-06-10T11:51:47Z`；临时二进制 artifact 分别为 auth `7506567328`、gateway `7506599309` 和 core `7506724997`，保留期均为 1 天。
- 2026-06-09：已下载最终 artifact 到 `target/backend-artifact-check/27202869734/services-linux` 并完成两层 manifest 校验；外层 `backend-native-manifest.json` 和包内 `manifest/backend-services-manifest.json` 均通过 schema、sha256/size 和禁止文件扫描。
- 2026-06-09：开始实现历史 Release asset 复用契约；`release-manifest.json` 顶层 `backendNativeManifest.source.type` 改为显式来源，支持 `github-actions-artifact` 和 `historical-release-asset`；backend native asset 的 `source.type=historical-release-asset` 必须记录历史 release、历史构建上下文和 backend native fingerprint。
- 2026-06-09：历史 Release asset 复用契约已完成第一版：新增历史复用有效样例和缺失 fingerprint 负例；校验脚本会拒绝非后端 asset 使用 `historical-release-asset`、拒绝缺失 fingerprint 的 backend native 复用、校验历史 asset sha256/size、历史构建 OpenAPI hash、backend commit、backend native manifest sha256 以及 fingerprint 的 kind/platform/backend/openapi 一致性。
- 2026-06-09：新增 `scripts/release-draft-reuse-backend-assets.ps1` 和 `.github/workflows/debug-release-draft-reuse-backend.yml`，提供手动最小 draft 复用入口。该入口从主仓库指定历史 Release 下载 `release-manifest.json`、`backend-native-manifest.json` 和后端 native asset，校验 fingerprint、sha256、size、历史构建上下文和禁止文件扫描后，生成新的 `release-manifest.json`、`SHA256SUMS` 并重新上传到新 draft Release。
- 2026-06-09：本地 dry-run 首次将复用后端 asset 自动改名为新版本文件名，导致复制过来的历史 `backend-native-manifest.json` 仍指向旧文件名并被校验脚本正确拒绝；已改为默认保留历史 asset 文件名，并禁止 `OutputBackendAssetName` 与历史文件名不一致。
- 2026-06-09：准备 GitHub-hosted 复用实跑时发现主仓库当前没有可复用历史 Release，且旧版 `release-draft-minimal-assets.ps1` 生成的历史 release manifest 不包含 `backendNativeFingerprint`；已补齐最小 draft 资产脚本的 fingerprint 输出，让后续用 `debug-release-draft-minimal.yml` 创建的历史 draft 可以被复用入口校验。
- 2026-06-09：`debug-release-draft-minimal.yml` GitHub-hosted run `27209181697` 通过，使用后端 run `27202869734` 的 artifact `7506747699` 创建历史 draft Release `v0.0.0-services-parallel.2`；资产包含 `backend-native-manifest.json`、`release-manifest.json`、`SHA256SUMS` 和 `hdx-backend-services-linux-x64-v0.0.0-services-parallel.2.tar.gz`，远端回读 size/sha256 校验通过。
- 2026-06-09：`debug-release-draft-reuse-backend.yml` GitHub-hosted run `27209326174` 通过，复用历史 draft Release `v0.0.0-services-parallel.2` 的后端 native asset 创建 draft Release `v0.0.0-services-parallel.3`。新 `release-manifest.json` 的 `root.commit` 为 `773e48a93fb0160af00eab0ec329c4edadbfdfdc`，`backendNativeManifest.source.type` 和后端 asset `source.type` 均为 `historical-release-asset`，并记录历史 release tag、asset sha256/size、历史构建 root commit `cc525b3ac82656bfced6e8951eaa901cef63c12c` 和 `backendNativeFingerprint`。
- 2026-06-09：已按用户确认删除测试 draft Release `v0.0.0-services-parallel.2` 和 `v0.0.0-services-parallel.3`；`gh release list --repo xxldm/hdx --limit 10` 已确认当前主仓库 Release 列表为空，两个测试 tag ref 均不存在。
- 2026-06-09：补充正式 `release.yml` 第一版设计，不创建 workflow 文件。ADR 0013 记录 `version`、`root_ref`、`backend_source_mode`、`backend_sources_json` 输入、job 图、最小权限 token、draft 到 publish 和失败 draft 保留规则；ADR 0014 记录 `resolve-backend-native` 对后端 Actions artifact 与历史主仓库 Release asset 两种来源的统一输出和历史 asset 不重命名规则。
- 2026-06-10：纠正一次性配置说明和日常发布手册边界：`docs/RELEASE_RUNBOOK.md` 保留常规人工只推主仓库 release tag、观察自动化和失败处理；GitHub App 权限配置属于一次性外部配置，不写入仓库手册。主仓库使用 `HDX Backend Actions Bot` 触发后端 release resolve；后端使用 `HDX Main Workflow Bot` 读取主仓库发布脚本和历史 Release asset，并通过 `workflow_dispatch` 触发主仓库 release assemble；主仓库使用自身 `GITHUB_TOKEN` 创建、上传和 publish Release，避免在后端仓库保存具备主仓库 `Contents: write` 的 App private key。长期设计边界保留在 ADR 0013/0014。
- 2026-06-11：用户确认发布模型应允许给主仓库任意一次 commit 打版本 tag，并按该 root commit 中记录的各子模块 commit hash 打包子仓库。此前 `release-start.yml` 第一版要求 `services/backend` 子模块 commit 等于后端仓库当前 `main`，虽然能防止实际构建漂移，但会把后端发布能力退化为只能发布当前 main；已决定不在主仓库用后端 `Contents: read` 权限查询 commit，后端 resolver 和 native build 必须显式 checkout 输入的 `backend_commit` 并在 checkout 后校验 HEAD。
- 2026-06-11：误触发一次真实 `Release Start` 演练 run `27324861530`，它成功触发后端 resolver run `27324870505`；在确认提交锁定边界前已取消后端 resolver，run 结论为 `cancelled`，native build job 在早期阶段停止，未产生后端 native artifact。
- 2026-06-11：进一步收缩职责边界。主仓库 `release-start.yml` 现在先用自身 `GITHUB_TOKEN` 选择并校验最新一个合格历史主仓库 Release；复用成功时直接触发主仓库 `release.yml`，复用失败时才通过 `HDX Backend Actions Bot` 的 `Actions: write` token 触发后端 resolver。后端 `backend-release-resolve.yml` 不再读取主仓库历史 Release，只按输入 `backend_commit` 运行 native build，并可用 `HDX Main Workflow Bot` 的 `Actions: write` token 回调主仓库 assemble；两个 GitHub App 最大权限均不再需要 `Contents: read`。

## 验证结果

- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`：通过。
- `git -C services/backend diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `git diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `services/backend/scripts/package-backend-native-artifact.ps1` dummy dry-run：通过，覆盖 workflow 下载路径对应的 `backend-services` `linux-x64` 和 `windows-x64` 聚合打包；Windows 本地没有 `chmod`，Linux executable 权限设置仅保留预期 warning。
- `scripts/release-manifest-check.ps1 -SkipExamples ...`：通过，分别校验 Linux/Windows 的外层 `backend-native-manifest.json`、包内 `backend-services-manifest.json`、archive sha256/size 和禁止文件扫描。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认关键文档可读、根仓库空白检查、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- GitHub-hosted run `27201075082`：部分通过。`build_scope=services-linux-only` 成功限制构建范围，full Linux/Windows 和 Windows services 均跳过；三个 Linux service binary job 均成功；聚合 job 因 `actions/download-artifact@v7.0.1` 版本不存在而失败。
- GitHub-hosted run `27202869734`：通过。`build_scope=services-linux-only` 成功限制构建范围，full Linux/Windows 和 Windows services 均跳过；三个 Linux service binary job 并行运行并成功上传临时二进制；最终 `Backend services linux-x64` 聚合 job 成功下载 `actions/download-artifact@v7.0.0` artifact、打包并上传最终 artifact。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples -BackendNativeManifestPath target/backend-artifact-check/27202869734/services-linux/backend-native-manifest.json -AssetRoot target/backend-artifact-check/27202869734/services-linux -ScanPath target/backend-artifact-check/27202869734/services-linux/hdx-backend-services-linux-x64-v0.0.0-services-parallel.2.tar.gz`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples -BackendServicesManifestPath target/backend-artifact-check/27202869734/services-linux/extracted/manifest/backend-services-manifest.json -AssetRoot target/backend-artifact-check/27202869734/services-linux/extracted -ScanPath target/backend-artifact-check/27202869734/services-linux/hdx-backend-services-linux-x64-v0.0.0-services-parallel.2.tar.gz`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1`：通过，覆盖新增历史复用有效样例、缺失 `backendNativeFingerprint` 负例、既有 schema/hash/禁止文件负例。
- `pwsh -NoLogo -NoProfile -File scripts/release-draft-minimal-assets.ps1 -ArtifactRoot target/backend-artifact-check/27202869734/services-linux ...`：通过，确认最小 draft 资产脚本能生成新版 `backendNativeManifest.source.type=github-actions-artifact` 的 `release-manifest.json`，并完成本地 release manifest 校验。
- `pwsh -NoLogo -NoProfile -File scripts/release-draft-minimal-assets.ps1 -ArtifactRoot target/backend-artifact-check/27202869734/services-linux ... -OutputDirectory target/release-draft-minimal/fingerprint-check/assets ...`：通过，确认最小 draft 资产脚本会为后端 native asset 生成 `backendNativeFingerprint`，并通过 release manifest 校验。
- `pwsh -NoLogo -NoProfile -File scripts/release-draft-reuse-backend-assets.ps1 -HistoricalAssetRoot target/release-draft-reuse-backend/fixture-historical ...`：通过，确认历史 Release asset 复用脚本能生成新版 `backendNativeManifest.source.type=historical-release-asset` 的 `release-manifest.json`，并完成历史 manifest、输出 manifest、sha256、size、fingerprint 和禁止文件扫描校验。
- `pwsh -NoLogo -NoProfile -File scripts/release-draft-reuse-backend-assets.ps1 -HistoricalAssetRoot target/release-draft-minimal/fingerprint-check/assets ...`：通过，确认由最小 draft 资产脚本生成的带 fingerprint 历史资产可以被复用脚本消费。
- `actionlint .github/workflows/debug-release-draft-reuse-backend.yml`：通过。
- GitHub-hosted run `27209181697`：通过。`debug-release-draft-minimal.yml` 成功下载后端 Actions artifact、生成带 `backendNativeFingerprint` 的最小 Release 资产、创建历史 draft Release `v0.0.0-services-parallel.2`、上传资产并远端回读校验。
- GitHub-hosted run `27209326174`：通过。`debug-release-draft-reuse-backend.yml` 成功下载历史 Release asset、校验 fingerprint/sha256/size/历史构建上下文和禁止文件扫描、创建复用 draft Release `v0.0.0-services-parallel.3`、上传资产并远端回读校验。
- `gh release download v0.0.0-services-parallel.3 --repo xxldm/hdx --pattern release-manifest.json`：通过。下载后的 manifest 确认 `historical-release-asset` 来源、历史 release tag、历史 asset sha256/size、历史构建 root commit 和 `backendNativeFingerprint` 均已记录。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认 docs 质量门禁已运行 release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查。
- 2026-06-11：提交锁定边界调整后，运行 `actionlint .github/workflows/release-start.yml`，通过；在 `services/backend/` 运行 `actionlint .github/workflows/backend-release-resolve.yml .github/workflows/backend-native-artifact.yml`，通过；运行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild` 和 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope backend -NoBuild`，均通过。`backend -NoBuild` 仅保留 Maven/Jansi 在 Java 25 下的 restricted method warning，不影响 workflow 静态校验。
- 2026-06-11：发布职责收缩后，运行 `actionlint .github/workflows/release-start.yml .github/workflows/release.yml .github/workflows/check-release-app-token.yml`，通过；在 `services/backend/` 运行 `actionlint .github/workflows/backend-release-resolve.yml .github/workflows/backend-native-artifact.yml`，通过；运行 `git diff --check` 与 `git -C services/backend diff --check`，均通过，仅保留 Git for Windows 行尾转换提示；运行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild` 和 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope backend -NoBuild`，均通过。`backend -NoBuild` 仅保留 Maven/Jansi 在 Java 25 下的 restricted method warning。
- 2026-06-12：主仓库 `check-release-app-token.yml` 手动 run `27402944650` 通过。该 run 使用权限收缩后的 `HDX Backend Actions Bot` 生成 `Actions: read` 和 `Actions: write` token，成功读取后端仓库 Actions metadata；未申请 `Contents: read`，未 checkout 后端源码，未下载 artifact，未创建 Release。

## 剩余风险

- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- 完整真实 tag-only 发布已有设计记录和日常操作手册；主仓库 tag start、后端 release resolve、主仓库 release assemble、Web node-server asset 构建和 Desktop Online asset 构建已有第一片，Desktop Full/App 构建、正式 publish 和失败清理仍未串成完整 workflow。
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
