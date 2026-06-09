# Release Native 构建额度与复用策略

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中
- 计划来源：用户确认 `backend-services` 并行构建，并允许后端未变时复用上一版主仓库 Release asset
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

降低后端私有仓库 native-image 对发布时间和 GitHub Actions 私有额度的压力：

- `backend-services` 改为服务级并行 native 构建，再聚合为同一个平台包。
- 明确后端 native-image 是当前主要额度压力；Web、Desktop、App 和主仓库组装后续公开后可以按日常 CI 正常运行。
- 不新增候选发布分级。
- 后续真实 release workflow 在后端 native 输入未变化时，可以复用上一版或指定历史主仓库 Release 中的后端 native asset。

## 非目标

- 本轮不实现主仓库真实 release workflow 的历史 Release asset 复用分支。
- 本轮不修改 GitHub Actions 计费计划、预算或 runner 类型。
- 本轮不把后端 Actions artifact 保留期改长。
- 本轮不引入 S3、RustFS、云 OSS、独立 artifact 仓库或后端 private release 作为 native 存储。
- 本轮不调整安装器签名、公证、自动更新、release notes 或版本号策略。

## repo 内范围

- `docs/adr/0014-release-native-build-budget-and-reuse-strategy.md`
- `docs/CONSTRAINTS.md`
- `docs/ARCHITECTURE.md`
- `README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/active/2026-06-09-release-native-build-budget-and-reuse.md`
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
- [ ] 触发 `services-linux-only` GitHub-hosted run，验证 matrix 并行和 `actions/download-artifact` 聚合。
- [ ] 下载 `backend-services-linux-x64` artifact 并运行 release manifest 校验。
- [ ] 后续实现主仓库真实 release workflow 的历史 Release asset 复用分支。

## 验收标准

- 默认后端 native workflow 仍产出 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` 三个最终 artifact。
- `backend-services-linux-x64` 的三个服务 native 编译在 matrix job 中并行运行，`max-parallel` 明确限制为 3。
- `backend-services-windows-x64` 仍默认关闭，仅在 `include_windows_services=true` 时按同样结构运行。
- 临时 service binary artifact 只在同一 workflow 内供聚合 job 使用，保留期仍为 1 天。
- 最终 `backend-services` archive 名称、内部结构、`backend-native-manifest.json` 和 `backend-services-manifest.json` 兼容现有 release 契约。
- 文档不再把“第一版不自动复用历史 Release 资产”描述为当前策略；当前策略应指向 ADR 0014 的 fingerprint 复用规则。

## 验证方式

- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`
- `pwsh -NoLogo -NoProfile -File services/backend/scripts/package-backend-native-artifact.ps1 ...`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples ...`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git -C services/backend diff --check`
- `git diff --check`

## 风险与阻塞

- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- `actions/download-artifact@v7.0.1` 尚需 GitHub-hosted runner 实跑确认。
- 当前 release manifest schema 还不能完整表达历史 Release asset 复用来源和 backend native fingerprint；后续实现复用分支前必须扩展 schema、样例和校验脚本。
- 旧后端 asset 的构建 `root.commit` 可能不同于新 Release 的 root commit；后续校验必须区分“当前发布事实源”和“历史后端 asset 构建来源”。

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

## 验证结果

- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`：通过。
- `git -C services/backend diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `git diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `services/backend/scripts/package-backend-native-artifact.ps1` dummy dry-run：通过，覆盖 workflow 下载路径对应的 `backend-services` `linux-x64` 和 `windows-x64` 聚合打包；Windows 本地没有 `chmod`，Linux executable 权限设置仅保留预期 warning。
- `scripts/release-manifest-check.ps1 -SkipExamples ...`：通过，分别校验 Linux/Windows 的外层 `backend-native-manifest.json`、包内 `backend-services-manifest.json`、archive sha256/size 和禁止文件扫描。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，确认关键文档可读、根仓库空白检查、release manifest 校验、OpenAPI 契约检查、OpenAPI 类型生成检查和 Web 类型对齐检查均通过。
- GitHub-hosted run `27201075082`：部分通过。`build_scope=services-linux-only` 成功限制构建范围，full Linux/Windows 和 Windows services 均跳过；三个 Linux service binary job 均成功；聚合 job 因 `actions/download-artifact@v7.0.1` 版本不存在而失败。

## 剩余风险

- `actions/download-artifact@v7.0.0` 聚合下载仍需 GitHub-hosted runner 重新实跑确认。
- 并行 services 构建降低墙钟时间，但不会降低 GitHub Actions runner 分钟总消耗，可能略增。
- 当前 release manifest schema 还不能完整表达历史 Release asset 复用来源和 backend native fingerprint；后续实现复用分支前必须扩展 schema、样例和校验脚本。
- `backend-services-windows-x64` 仍默认不跑，本轮仅验证 workflow 静态结构和 Windows 聚合打包脚本路径。

## 相关 commit

- `c8d2aea 功能：并行构建后端 services native`（`services/backend`）
- `e7815f1 功能：记录 native 构建额度与复用策略`（根仓库）
- `0f520ab 功能：支持按范围构建后端 native`（`services/backend`）
- `b5759ac 修复：修正后端 artifact 下载 action 版本`（`services/backend`）
- 当前 `build_scope` 验证切片根仓库提交：待提交。
