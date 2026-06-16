# Release Native 构建额度与复用策略

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：见下方 active plan 状态块。
- 计划来源：用户确认 `backend-services` 并行构建，并允许后端未变时复用上一版主仓库 Release asset
- 创建时间：2026-06-09
- 最后更新：2026-06-16（native 构建内存排查）

<!-- active-plan-status:start -->
- 何时读取：后端 native artifact、GitHub Actions release start、历史 Release asset 复用、后端 resolver 相关任务。
- 当前状态：`v0.0.0-preview.5` 已验证 tag-only 预览发布和 Full Linux AppImage smoke；`v0.0.0-preview.6` 因 `core-service` native 停滞取消。已补超时/诊断，并在本机验证 baseline、`-Ob` 与线程限制；`-Ob` 和线程限制均不作为 release 默认方案。
- 下一步：暂停会触发后端 native 的 release 验证；待 2026-06-25 GraalVM 25.1 发布后，先复测 `backend-core-service` build report NPE。期间只做只读检查、文档和清理准备，不推新 preview/stable tag。
- 主要剩余风险：新增超时/诊断仍未在远端卡住场景验证；`-Ob` 不可作为 release 默认优化；后端 native 卡住风险解除前，stable 发布和完整安装包矩阵验证暂停。Windows services、旧 workflow、很旧 tag 入口和 App 发布闭环仍待后续处理。
<!-- active-plan-status:end -->

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
- [x] 后续完善 `.github/workflows/release.yml`，接入 `release_mode=publish`、stable/preview 发布区分、preview prerelease 和 Desktop asset channel。
- [x] 完成真实 tag-only 预览发布链路验证和 Desktop Full Linux 真实 `backend-full` AppImage 启动/API smoke。
- [x] 清空当前 Actions 临时 artifacts/cache，并在发布成功路径补齐已消费 artifacts 的自动清理。
- [x] 为所有 release native build 步骤补充单步超时、Maven 日志落盘和失败 job summary 诊断。
- [x] 在本机 Windows GraalVM/VS/Maven 环境验证 `backend-core-service` 与 `backend-all-in-one` native baseline，并确认 build report 在 `core-service` 上触发 GraalVM 25 legacy resource-config NPE、在 `all-in-one` 上可成功生成。
- [x] 在本机 Windows 验证 `backend-core-service` 使用 `-Ob` 可降低 native-image Peak RSS；因该参数以运行性能换构建速度，不接入 release 默认构建。
- [ ] 后续完善失败 draft 人工清理演练、release artifact 上下文一致性、stable 正式发布验证和真实安装包矩阵验证。App 当前暂不进入发布闭环。

## 验收标准

- 默认后端 native workflow 仍产出 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` 三个最终 artifact。
- `backend-services-linux-x64` 的三个服务 native 编译在 matrix job 中并行运行，`max-parallel` 明确限制为 3。
- `backend-services-windows-x64` 仍默认关闭，仅在 `include_windows_services=true` 时按同样结构运行。
- 临时 service binary artifact 只在同一 workflow 内供聚合 job 使用，聚合成功后尽力删除；失败时仍保留 1 天用于排障。
- 主仓库 release assemble 成功上传并远端校验 Release 资产后，尽力删除 `release-backend-assets`、Desktop 临时 assets 和已经消费的后端 native Actions artifacts；删除失败不应阻塞已成功的 Release。
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
- Actions storage 本轮瓶颈主要来自大体积临时 artifacts。Actions cache 与 artifact 的额度/计费模型不同；当前主仓库 cache 约 4.5 GiB、后端 cache 约 0.8 GiB，低于单仓库默认 10 GB cache 上限，不是当前 `0.5 GB` storage 压力的主因。cache 继续保留以降低构建时间，但如果单仓库 cache 接近 10 GB，需要再单独调整。
- `release-manifest.json` schema、校验脚本、手动最小 draft workflow、主仓库 `release-start.yml` 和主仓库 `release.yml` draft assemble 第一版已能表达、校验、下载并重新上传历史 Release asset；ADR 0013/0014 已补齐 tag-only 目标发布设计，但完整 tag-only 自动发布链路仍未实现。
- OpenAPI snapshot hash 已由 `scripts/openapi-snapshot-hash.ps1` 固化；release start 使用该脚本生成后端 native 输入 hash。
- 旧后端 asset 的构建 `root.commit` 可能不同于新 Release 的 root commit；后续校验必须区分“当前发布事实源”和“历史后端 asset 构建来源”。
- 当前历史复用入口为保持 `backend-native-manifest.json` provenance，不重命名复用的后端 native asset；如需按新版本重命名，需要先设计 manifest rewrite 和校验规则。
- 正式 tag-only 自动发布链路已有 start、主仓库历史后端 asset 复用判断、后端 native build resolver、主仓库 assemble、Web node-server asset 构建、Desktop Online asset 构建、Desktop Full asset 构建、Desktop Full sidecar 最小启动闭环、Desktop 静态 Web UI + Rust BFF、远端 asset 回读 manifest 校验、stable/preview 区分和 publish。
  本轮补强公开端 Desktop Full Linux AppImage 合成资源 smoke、publish 开关和 prerelease 语义；后续实现时仍必须按 ADR 0013/0014 补齐真实 tag-only 发布验证、失败 draft 人工清理演练和 Desktop Full 真实 backend-full AppImage 启动验证，避免直接复制 debug workflow 拼接成正式发布。App 当前暂不进入发布闭环。

## 状态记录

- 2026-06-09：创建 ADR 0014，完成后端 services native 服务级 matrix 构建与聚合策略；`build_scope=services-linux-only` 允许只跑 Linux services 验证。首次远端 run `27201075082` 暴露 `actions/download-artifact@v7.0.1` 不存在，修正为 `v7.0.0` 后 run `27202869734` 通过，最终 artifact `7506747699` 通过两层 manifest 校验。
- 2026-06-09：落地历史主仓库 Release asset 复用契约、`release-draft-minimal-assets.ps1`、`release-draft-reuse-backend-assets.ps1` 和 debug workflows。GitHub-hosted run `27209181697` 创建可复用历史 draft，run `27209326174` 复用历史后端 native asset 创建新 draft；测试 draft Release 与 tag 已按用户确认清理。
- 2026-06-09 至 2026-06-12：补齐正式发布设计和 tag-only 操作手册；`release-start.yml` 按 root commit 中的 `services/backend` gitlink 锁定后端源码，主仓库负责历史 asset 复用判断，后端 resolver 只负责 native build 与可选 assemble 回调；手动 dry-run run `27403306816` 验证不会触发后端或 assemble。
- 2026-06-12 至 2026-06-13：`release.yml` 接入 Web node-server、Desktop Online 和 Desktop Full asset 构建第一片；Desktop Full 通过 `resolve-backend-native` 消费后端 asset，包内携带已解压 `backend-full` 与 `backend-build.json`。Desktop 静态 Web UI + Rust BFF 已接入；Online 远端配置和认证转发后续已在 Web/Desktop 发布产物计划中关闭。
- 2026-06-15：`Check Public Release Assets` run `27528781158` 中新增 Desktop Full Linux AppImage 合成资源 smoke 通过；workflow 总体失败于 Windows Online asset 整理，根因是 Rust target cache 中保留旧 NSIS 安装包，而 `package-desktop-release-assets.ps1` 只按 `*setup.exe` 模糊定位。当前已改为按当前 release version 精确选择 Tauri bundle，并新增本地 fixture 覆盖旧缓存产物共存场景；run `27529656045` 已确认 Web、Desktop Online Windows/Linux 和 Desktop Full Linux 全部通过。
- 2026-06-15：`release-start.yml` 按 tag 形态区分发布类型：`v1.2.3` 为 stable 正式发布，`v1.2.3-rc.1` 等 prerelease tag 为 preview 预览发布。`release.yml` 增加 `release_mode=draft|publish`，真实 tag 链路传 `publish`，手动入口默认 `draft`；preview 发布为 GitHub prerelease 且不标记为 Latest，Desktop asset manifest 的 `channel` 跟随 stable/preview。App 当前暂不进入发布闭环。
- 2026-06-15：真实推送 `v0.0.0-preview.1` 触发 tag-only 发布验证。`Release Start` run `27532492338` 成功；后端 resolver run `27532509974` 成功，完成 `backend-full` Linux/Windows native 和 Linux `backend-services` 构建并回调主仓库；主仓库 `release.yml` run `27534125174` 成功完成后端资产解析、Web node-server、Desktop Online/Full Windows/Linux 构建、draft Release 创建和 13 个资产上传。最终失败于 publish 前“远端 Release 资产校验”，根因是 workflow 使用 `pwsh -File scripts/release-manifest-check.ps1 ... -ScanPath $downloadedAssetPaths` 传递多文件数组，PowerShell 子进程参数绑定把首个 tar.gz 误绑定为 `ReleaseContractsDir`；失败 draft `v0.0.0-preview.1` 已保留，未发布。
- 2026-06-15：提交 `6348a31 修复：稳定远端发布资产校验` 后推送 `v0.0.0-preview.2` 复测成功。`Release Start` run `27535070134` 成功；后端 resolver run `27535085705` 成功；主仓库 assemble run `27536663826` 成功。GitHub Release `v0.0.0-preview.2` 已发布，`draft=false`、`prerelease=true`、`make_latest=null`，共 13 个资产。下载远端 `release-manifest.json` 确认 root commit 为 `6348a311b1a829fee9528fe83ee424ae45582cba`，backend/web/desktop commits 分别为 `acc8e1f25a91561ad68020e49d66c50b52e21378`、`dc41f0b65171012026368f53fe36cc92d68150f3`、`b0cfb45ea65ee05923c7668433b53e9e3115050b`，Desktop Online/Full 六个资产均为 `channel=preview`。
- 2026-06-15：本机 Ubuntu WSL 真实运行 `HDX.Desktop.Full_linux-x64_v0.0.0-preview.2.AppImage`。补齐 WSL GUI/WebKit 运行依赖和 CJK 字体后，Desktop Full UI 可启动并显示中文，但页面提示后端暂时不可用。sidecar 日志位于 `/home/xxldm/.local/share/cn.hdx.desktop.full/backend/logs/`，确认 `backend-full` 已启动到 H2/Flyway/JPA 后失败于 `LocalTokenSecurityConfiguration.allInOneSecurityFilterChain` 参数 `com.fasterxml.jackson.databind.ObjectMapper` 无 bean。根因是 Spring Boot 4 自动配置提供 Jackson 3 `tools.jackson.databind.ObjectMapper`，而 `backend-http-support` 与安全配置仍注入 Jackson 2 类型；测试里手写 Jackson 2 bean 曾掩盖生产缺口。后端已改为使用 Jackson 3 类型并移除安全配置测试里的手写旧 mapper。
- 2026-06-15：为避免同类 Boot 4/Jackson 迁移缺口再次只在真实 native 产物中暴露，后端新增 `scripts/check-boot4-jackson.ps1`，根仓库 `quality-gate.ps1 -Scope backend` 接入该静态检查和 `backend-all-in-one` AOT/package smoke；后端 native artifact workflow 在真实 native 编译前先运行 Jackson preflight。
- 2026-06-15：本轮门禁补强验证通过：后端 Jackson 检查脚本、根仓库 `quality-gate.ps1 -Scope backend -NoBuild`、`quality-gate.ps1 -Scope backend`、`quality-gate.ps1 -Scope docs -NoBuild`、`actionlint services/backend/.github/workflows/backend-native-artifact.yml` 和根/后端 `git diff --check` 均通过。Maven 与 Java 25 相关 warning 暂不阻塞。
- 2026-06-16：推送 `v0.0.0-preview.3` 触发 Release Start run `27592731539`，失败于“解析历史后端来源”。历史 `v0.0.0-preview.2` 的后端 commit 与当前 `0b713c8` 不一致本应触发后端 native build fallback，但 catch 后未清理内层 `pwsh` 留下的 `$LASTEXITCODE=1`，导致步骤误失败。当前已在 `release-start.yml` fallback catch 中清理 `$LASTEXITCODE`；按发布纪律不移动已推送 tag，后续用 `v0.0.0-preview.4` 重跑。
- 2026-06-16：推送 `v0.0.0-preview.4` 触发 Release Start run `27592929905`，确认 fallback 修复有效并触发后端 resolver run `27592945480`。后端 preflight、Linux full 和 Linux services 均通过，Windows full native job 失败于 GraalVM `ConditionalMoveOptimizationPhase` 编译报警超时；该失败阻止 resolver finalize 和主仓库 assemble。当前处理方式是不改变正式发布必需资产矩阵，在 Windows native CI 上启用 `native-windows-ci` profile，将单编译单元超时阈值从默认 300 秒放宽到 1800 秒，后续用 `v0.0.0-preview.5` 复跑。
- 2026-06-16：推送 `v0.0.0-preview.5` 触发 Release Start run `27595323355`，历史复用按预期失败并触发后端 resolver run `27595338384`。后端 preflight、Linux full、Linux services 和 Windows full 全部通过；Windows full native job `81584459958` 在 30m52s 完成，确认 `native-windows-ci` profile 越过 preview.4 的 GraalVM 编译报警超时。主仓库 assemble run `27596496960` 成功发布 prerelease，Release `draft=false`、`prerelease=true`，远端资产校验通过。
- 2026-06-16：本机 Ubuntu WSL 下载 `HDX.Desktop.Full_linux-x64_v0.0.0-preview.5.AppImage`，sha256 `6ad281eabba07f4237ef35cfe43c4818fb9a723ec34036a5552c32d2679edc40` 与 `SHA256SUMS` 一致。隔离 `XDG_*` 目录运行真实 AppImage 后，内置 `backend-full` 启动到 `Started AllInOneApplication` 并优雅退出；API smoke 验证 `/actuator/health` 为 `UP`、`/local/session` 返回 `X-HDX-Local-Token` 和 64 位 token、`/api/v1/runtime` 返回 `hdx-all-in-one` 且 `nativeImage=true`、`/api/v1/tools` 返回空数组、`/api/v1/auth/current` 返回 `LOCAL_ADMIN:local-admin`。WSL 环境仍有 `GStreamer element appsink not found` 与 DRI3 warning，但未阻塞本次 sidecar/API smoke。
- 2026-06-16：公开端资产检查 run `27600342351` 通过，Web node-server、Desktop Online Windows/Linux 和 Desktop Full Linux AppImage 全绿；workflow 已按新约束只在 job 内校验产物，不再上传临时 Actions artifact。`gh api repos/xxldm/hdx/actions/artifacts --jq '.total_count'` 返回 `0`。完整 release 成功路径删除已消费 artifacts 仍需等下一次 preview release 验证。
- 2026-06-16：推送 `v0.0.0-preview.6` 后，`release-start.yml` 仍按当前 fingerprint 规则判定后端输入变化并触发 `hdx-backend` native fallback；`backend-release-resolve.yml` 先后成功完成 `backend-full` Linux/Windows 与 `hdx-auth-service`、`hdx-gateway` native build，但 `hdx-core-service` 在 native-image `[6/8] Compiling methods` 阶段长时间停滞，最终于 `08:24:03 UTC` 被取消。后端 run 上传的 4 个临时 artifacts 已删除，后端仓库 `actions/artifacts` 为 `0`。本次结果说明 workflow-only 变更不能直接从 fingerprint 中剔除，且后端 native 编译资源瓶颈需要单独处理。
- 2026-06-16：后端 commit `7518705` 为 `backend-native-artifact.yml` 的所有 release native build 步骤补充单步超时和失败诊断。Linux native build step 超时为 45 分钟，Windows native build step 超时为 60 分钟；Maven 输出同步写入 `target/native-diagnostics/<build-id>/maven.log`，失败或超时时将 Maven 日志尾部和 runner 资源快照写入 job summary，不额外上传诊断 artifact。当前只做静态与脚本级验证，远端卡住场景需下一次 preview release 验证。
- 2026-06-16：按用户确认优先使用本机 Windows 完整编译环境验证 native 构建。`backend-core-service` 无 build report baseline 成功：总耗时 03:31，native-image 3m06s，Peak RSS 11.01GB，reachable 48,603 types / 263,399 methods，reflection 16,792 types，image 221.79MB；Top code origins 包括 Hibernate 20.17MB、Nacos client 7.47MB、H2 7.25MB、fastjson2 3.87MB。`backend-all-in-one -Pnative,native-windows-ci` baseline 成功：总耗时 02:53，native-image 2m32s，Peak RSS 12.36GB，reachable 41,212 types / 219,375 methods，reflection 14,127 types，image 185.52MB。`backend-all-in-one` 带 `-H:Emit=build-report=...` 成功并生成本机 HTML report；`backend-core-service` 带相同 build report 参数失败于 GraalVM 25 `ResourcesFeature.beforeAnalysis` 解析 legacy `resource-config.json` 时的 `LegacyResourceConfigurationParser` NPE。初步判断：`core-service` 远端 110 分钟停滞不是本机必现的代码级慢编译；后续结构性优化应关注服务端启动器依赖、legacy native metadata、数据访问层和可达图收窄，而不是只调整 runner。
- 2026-06-16：本机 Windows 对 `backend-core-service` 追加 `-Ob` 验证通过，native-image 时间从 3m06s 降到 2m14s，Peak RSS 从 11.01GB 降到 8.86GB，镜像从 221.79MB 降到 168.08MB；`-H:NumberOfThreads=8` native-image 时间 4m27s、Peak RSS 10.56GB、GC 3567 次，收益不足且显著变慢，未采用。`-Ob` 的核心代价是以运行性能换构建速度，当前不接入 release 默认构建；Full、services 和本地默认 native 构建均保持原优化级别。
- 逐条命令输出、临时失败细节和完整 run 日志不再保留在 active plan；可复用命令/环境踩坑沉淀到 `docs/AGENT_WORKFLOW.md` 或脚本。

## 验证结果

- 本计划有效验证以当前摘要为准：`actionlint` 覆盖后端 native workflow、release start、release assemble、debug reuse、公开端资产检查和 app-token check workflow；`git diff --check` 与后端子仓库 diff check 通过，仅保留 Git for Windows 换行提示。本轮 publish/stable-preview 改造仍需完成本地静态校验和后续真实 tag-only 远端验证。
- 后端 native 超时诊断验证：`actionlint services/backend/.github/workflows/backend-native-artifact.yml` 通过；两个新增 PowerShell 脚本语法解析通过；`write-native-build-diagnostics.ps1` 已用临时目录本机试跑，能输出资源快照和 Maven 日志尾部占位；`quality-gate.ps1 -Scope backend -NoBuild` 通过。
- 本机 Windows native 基线与调参验证：`backend-core-service` 无 build report native 构建通过；`backend-all-in-one -Pnative,native-windows-ci` 无 build report native 构建通过；`backend-all-in-one` 带 `-H:Emit=build-report=...` native 构建通过并生成本机 HTML report；`backend-core-service` 带 build report 失败于 GraalVM 25 legacy resource-config 解析 NPE，失败报告位于本机 `services/backend/backend-core-service/target/svm_err_b_20260616T173004.686_pid44744.md`；`backend-core-service` 临时追加 `-Ob` native 构建通过并确认 Peak RSS 下降到 8.86GB，但因运行性能代价不采用；`-H:NumberOfThreads=8` 诊断构建通过但耗时变长、降内存有限，未采用。
- 后端 native services 并行构建远端验证：GitHub-hosted run `27202869734` 通过，三个 Linux service binary job 并行成功，最终 `backend-services-linux-x64` artifact 下载、聚合、sha256/size、禁止文件扫描和两层 manifest 校验通过。
- 历史 Release asset 复用验证：本地 draft minimal/reuse 脚本 dry-run 通过；GitHub-hosted run `27209181697` 和 `27209326174` 分别验证历史 draft 创建与历史后端 native asset 复用；远端 manifest 回读确认 `historical-release-asset` 来源和 `backendNativeFingerprint`。
- 发布控制面验证：`check-release-app-token.yml` run `27402944650` 通过；`Release Start` 手动 dry-run run `27403306816` 通过，确认 dry-run 只预演后端来源判断，不触发主仓库 assemble、后端 App token 或后端 resolver。
- 公开端资产检查：run `27528781158` 确认 Desktop Full Linux AppImage 合成资源 smoke 通过；同一 run 暴露 Windows Online 打包脚本受旧缓存 NSIS 产物干扰，当前已补按版本精确匹配和 fixture 回归；run `27529656045` 与 `27600342351` 已确认全部 job 通过，且后者不再上传临时 Actions artifact。
- 真实 preview tag 验证：`v0.0.0-preview.1` 对应 `release-start` run `27532492338`、后端 resolver run `27532509974` 和主仓库 assemble run `27534125174`。该链路已证明后端 native、Web、Desktop Online/Full 构建、draft 创建和资产上传可达；失败点限定在 publish 前远端 manifest 校验传参，已按单目录扫描方式修复。`v0.0.0-preview.2` 对应 `release-start` run `27535070134`、后端 resolver run `27535085705` 和主仓库 assemble run `27536663826`，已成功 publish 为 prerelease，未标记 Latest，远端 manifest 校验通过且 Desktop asset channel 为 `preview`。`v0.0.0-preview.3` 对应 Release Start run `27592731539`，未进入后端 resolver 或 assemble，失败点限定在历史复用失败 fallback 步骤。
- 真实 Full Linux AppImage 验证：`v0.0.0-preview.2` 在本机 Ubuntu WSL 可启动 Desktop UI，但内置 `backend-full` sidecar 启动失败于 Jackson 2/3 `ObjectMapper` 类型不匹配。`v0.0.0-preview.5` 已在同一 WSL 环境通过真实 AppImage 启动与 API smoke，确认后端 Jackson 修复进入 release native/AppImage 产物。
- 本地质量门禁：根仓库 backend scope 已补 Boot 4 Jackson 静态检查和 all-in-one AOT/package smoke；docs scope 覆盖关键文档、release manifest、Desktop Release asset 打包 fixture、OpenAPI 契约、OpenAPI 类型生成和 Web 类型对齐检查。

## 剩余风险

- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- GraalVM `-Ob` 能降低 builder 内存和构建耗时，但会影响 native 运行时吞吐；当前明确不作为 release 默认方案，后续只可作为本地诊断或经性能验证后的临时应急选项。
- 完整真实 tag-only 预览发布已由 `v0.0.0-preview.2` 验证通过；主仓库 tag start、后端 release resolve、主仓库 release assemble、Web node-server asset、Desktop Online asset、Desktop Full asset 构建、远端 asset 回读 manifest 校验、preview 发布和 publish 已有第一片。
  Desktop Full Linux 真实 AppImage 已在 `v0.0.0-preview.5` 通过 sidecar/API smoke；Desktop Online 远端配置和远端 Rust BFF 认证转发已实现。失败 draft 人工清理演练、stable 正式发布验证、release artifact 上下文一致性和真实安装包矩阵验证仍未完成。App 当前暂不进入发布闭环。
- OpenAPI snapshot hash 已由 `scripts/openapi-snapshot-hash.ps1` 固化，当前 hash 由 release start 自动计算。
- 后端 workflow 控制平面仍通过后端仓库 `main` 上的 workflow 文件启动；源码 checkout 已锁定 `backend_commit`，但如果未来需要复现旧 workflow 逻辑本身，需要另行设计 workflow 版本化或 release 分支策略。
- 主仓库 release start 当前通过 `workflow_dispatch` 触发后续 workflow；若给很旧的 root commit 打 tag，而该 tag 对应提交本身没有当前发布 workflow，需要改用当前 `main` 上的手动入口或后续设计 workflow 版本化策略。
- `backend-services-windows-x64` 仍默认不跑，本轮仅验证 workflow 静态结构和 Windows 聚合打包脚本路径。
- 测试 draft Release `v0.0.0-services-parallel.2` 和 `v0.0.0-services-parallel.3` 已清理；后续如果再次做远端 release 验证，仍需在完成后删除测试 draft 和确认 tag ref 不存在。

## 相关 commit

- `c8d2aea 功能：并行构建后端 services native`（`services/backend`）
- `e7815f1 功能：记录 native 构建额度与复用策略`（根仓库）
- `d09384c 修复：稳定 Desktop 发布资产打包`（根仓库）
- `0f520ab 功能：支持按范围构建后端 native`（`services/backend`）
- `b5759ac 修复：修正后端 artifact 下载 action 版本`（`services/backend`）
- 历史复用契约、校验脚本、正式发布设计和日常操作手册更新由本计划后续提交记录补齐。
