# 后端 Native Artifact 扩展

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户确认删除测试 draft Release 后继续推进真实 Release 资产形态
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

把后端私有仓库 native artifact 生产入口从第一版 `backend-full-linux-x64` 扩展到更接近真实 Release 资产形态：

- `backend-full` 支持并默认构建 `linux-x64` 和 `windows-x64`。
- `backend-services` 支持并默认构建 `linux-x64`，`windows-x64` 作为手动输入可选构建。
- `backend-services` 按平台聚合 `backend-auth-service`、`backend-gateway` 和 `backend-core-service` native executable。
- `backend-services` 包内部生成 `manifest/backend-services-manifest.json` 和 `manifest/SHA256SUMS`。
- 后端 workflow 继续只上传 Actions artifact，保留期 1 天，不上传源码、JAR/WAR、`.class` 或后端构建中间目录。

## 非目标

- 本轮不修改主仓库 Release workflow 去消费多个后端 artifact。
- 本轮不 publish GitHub Release。
- 本轮不实现安装器签名、公证、自动更新、release notes 或版本号策略。
- 本轮不让 `backend-services` Windows native 默认运行；`backend-full` Windows native 默认运行，因为 Desktop Full Windows 安装包需要内置本机后端。

## repo 内范围

- `services/backend/.github/workflows/backend-native-artifact.yml`
- `services/backend/scripts/package-backend-native-artifact.ps1`
- `services/backend/README.md`
- `docs/plans/completed/2026-06-09-backend-native-artifact-expanded.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 扩展后端打包脚本支持 `backend-services`。
- [x] 扩展后端 workflow 支持默认 `backend-full-windows-x64`、`backend-services-linux-x64` 和可选 `backend-services-windows-x64`。
- [x] 更新后端 README 与根仓库路线图。
- [x] 本地用 dummy native executable 验证 full/services 打包脚本。
- [x] 运行 `actionlint`、release manifest 校验、docs 质量门禁和空白检查。
- [x] 提交并推送 `services/backend`。
- [x] 更新并提交根仓库子模块指针和计划记录。
- [x] 触发 GitHub-hosted workflow，验证默认 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` artifact。

## 验收标准

- `backend-services` archive 命名符合 `hdx-backend-services-<platform>-<version>.(tar.gz|zip)`。
- `backend-services` archive 内包含 `bin/`、`config/` 和 `manifest/`。
- `backend-services-manifest.json` 符合根仓库 release schema 中的字段约束。
- `backend-native-manifest.json` 可记录 `backend-full` 或 `backend-services` artifact。
- 打包脚本禁止源码、JAR/WAR、`.class` 和构建中间目录进入 archive。
- `backend-full-windows-x64` 默认运行，满足 Desktop Full Windows 打包需要。
- `backend-services-windows-x64` 不默认运行，必须通过 workflow input 显式开启。

## 验证方式

- `pwsh -NoLogo -NoProfile -File services/backend/scripts/package-backend-native-artifact.ps1 ...`
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -BackendNativeManifestPath ... -BackendServicesManifestPath ... -AssetRoot ... -ScanPath ...`
- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 风险与阻塞

- GitHub-hosted run 已验证 `backend-full-windows-x64` 默认构建可产出 artifact；后续仍需在主仓库 Desktop Full 打包流程中消费并校验该 artifact。
- `backend-services` 三个服务 native 构建耗时明显高于单个 `backend-all-in-one`；本轮实跑确认 Linux 聚合包可产出，但完整 run 耗时较长。
- 主仓库 release workflow 仍需后续扩展，才能一次消费 full/services 和多平台后端 artifact。

## 状态记录

- 2026-06-09：创建计划，开始扩展后端 native artifact 生产入口。
- 2026-06-09：后端打包脚本已支持 `backend-full` / `backend-services`、Linux / Windows 四种组合；workflow 已调整为默认构建 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64`，仅 `backend-services-windows-x64` 需要 `include_windows_services=true`。
- 2026-06-09：本地 dry-run 首次在普通权限写入 `services/backend/target/package-dry-run` 时触发 sandbox `Access to the path ... is denied`，随后按 `docs/AGENT_WORKFLOW.md` 提权复跑通过。
- 2026-06-09：`services/backend` commit `4e7be9a 功能：扩展后端 native artifact 产物` 已推送到 `origin/main`。
- 2026-06-09：根仓库 commit `0d5a2fe 功能：记录后端 native artifact 扩展` 已推送到 `origin/main`，记录本轮计划、release 契约说明和 `services/backend` 子模块指针。
- 2026-06-09：首次触发的后端 run `27193225640` 因手动输入 `openapi_snapshot_hash` 时打错字符而取消；随后用正确 hash 重新触发 run `27193262232`。
- 2026-06-09：后端 GitHub-hosted run `27193262232` 成功；默认 job 中 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` 均成功，`backend-services-windows-x64` 按 `include_windows_services=false` 跳过。
- 2026-06-09：run `27193262232` 产出 3 个 Actions artifact，均未过期且保留期为 1 天：`hdx-backend-full-native-v0.0.0-artifact-expanded.1-linux-x64`（ID `7502616410`，过期 `2026-06-10T08:38:21Z`）、`hdx-backend-full-native-v0.0.0-artifact-expanded.1-windows-x64`（ID `7502706764`，过期 `2026-06-10T08:42:39Z`）、`hdx-backend-services-native-v0.0.0-artifact-expanded.1-linux-x64`（ID `7503669675`，过期 `2026-06-10T09:25:31Z`）。

## 验证结果

- `services/backend/scripts/package-backend-native-artifact.ps1` dummy dry-run：通过，覆盖 `backend-full` / `backend-services` 的 `linux-x64` 和 `windows-x64` 四种组合。
- `scripts/release-manifest-check.ps1 -SkipExamples ...`：通过，覆盖四个 `backend-native-manifest.json`、两个 `backend-services-manifest.json`、四个 archive 的 sha256/size 校验和禁止文件扫描。
- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`：通过。
- `git -C services/backend diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `git diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。
- 后端 GitHub-hosted run `27193262232`：通过，确认默认 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` artifact 上传成功，`backend-services-windows-x64` 默认跳过。
- `gh run download 27193262232 --repo xxldm/hdx-backend --name hdx-backend-services-native-v0.0.0-artifact-expanded.1-linux-x64 --dir target/backend-artifact-check/27193262232/services-linux`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples -BackendNativeManifestPath target/backend-artifact-check/27193262232/services-linux/backend-native-manifest.json -AssetRoot target/backend-artifact-check/27193262232/services-linux -ScanPath target/backend-artifact-check/27193262232/services-linux/hdx-backend-services-linux-x64-v0.0.0-artifact-expanded.1.tar.gz`：通过。
- 解压 `hdx-backend-services-linux-x64-v0.0.0-artifact-expanded.1.tar.gz` 后，`pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples -BackendServicesManifestPath target/backend-artifact-check/27193262232/services-linux/extracted/manifest/backend-services-manifest.json -AssetRoot target/backend-artifact-check/27193262232/services-linux/extracted -ScanPath target/backend-artifact-check/27193262232/services-linux/hdx-backend-services-linux-x64-v0.0.0-artifact-expanded.1.tar.gz`：通过，确认内部 `bin/`、`config/` 和 `manifest/` 结构可校验。
- `gh run download 27193262232 --repo xxldm/hdx-backend --name hdx-backend-full-native-v0.0.0-artifact-expanded.1-windows-x64 --dir target/backend-artifact-check/27193262232/full-windows`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -SkipExamples -BackendNativeManifestPath target/backend-artifact-check/27193262232/full-windows/backend-native-manifest.json -AssetRoot target/backend-artifact-check/27193262232/full-windows -ScanPath target/backend-artifact-check/27193262232/full-windows/hdx-backend-full-windows-x64-v0.0.0-artifact-expanded.1.zip`：通过，确认 Desktop Full 需要的 Windows full artifact 可校验。

## 剩余风险

- Windows 本地 dry-run 没有 `chmod`，Linux 包可执行权限设置在本机仅记录 warning；GitHub Ubuntu runner 已在远端 run 中完成真实 Linux native 打包。
- `backend-services-linux-x64` GitHub-hosted run 总耗时明显高于 `backend-full`；后续若发布耗时不可接受，可考虑把 `backend-auth-service`、`backend-gateway` 和 `backend-core-service` native 编译拆成并行 job，再单独聚合。
- `backend-services-windows-x64` 仍未实跑，当前按用户要求默认不跑。
- 主仓库 release workflow 仍需后续扩展，才能一次消费 full/services 和多平台后端 artifact。

## 相关 commit

- `4e7be9a 功能：扩展后端 native artifact 产物`（`services/backend`）
- `0d5a2fe 功能：记录后端 native artifact 扩展`（根仓库）
- 根仓库：本计划归档提交。
