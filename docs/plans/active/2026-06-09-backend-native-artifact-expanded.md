# 后端 Native Artifact 扩展

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：进行中
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
- `docs/plans/active/2026-06-09-backend-native-artifact-expanded.md`
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
- [ ] 触发 GitHub-hosted workflow，验证默认 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64` artifact。

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

- 真正的 Windows native 构建依赖 GitHub-hosted Windows runner 的 Visual Studio C++ 工具链，`backend-full-windows-x64` 默认构建后可能暴露 runner 工具链问题，需要实跑修正。
- `backend-services` 三个服务 native 构建耗时明显高于单个 `backend-all-in-one`，本轮只让 `backend-services-windows-x64` 显式开启。
- 主仓库 release workflow 仍需后续扩展，才能一次消费 full/services 和多平台后端 artifact。

## 状态记录

- 2026-06-09：创建计划，开始扩展后端 native artifact 生产入口。
- 2026-06-09：后端打包脚本已支持 `backend-full` / `backend-services`、Linux / Windows 四种组合；workflow 已调整为默认构建 `backend-full-linux-x64`、`backend-full-windows-x64` 和 `backend-services-linux-x64`，仅 `backend-services-windows-x64` 需要 `include_windows_services=true`。
- 2026-06-09：本地 dry-run 首次在普通权限写入 `services/backend/target/package-dry-run` 时触发 sandbox `Access to the path ... is denied`，随后按 `docs/AGENT_WORKFLOW.md` 提权复跑通过。
- 2026-06-09：`services/backend` commit `4e7be9a 功能：扩展后端 native artifact 产物` 已推送到 `origin/main`。

## 验证结果

- `services/backend/scripts/package-backend-native-artifact.ps1` dummy dry-run：通过，覆盖 `backend-full` / `backend-services` 的 `linux-x64` 和 `windows-x64` 四种组合。
- `scripts/release-manifest-check.ps1 -SkipExamples ...`：通过，覆盖四个 `backend-native-manifest.json`、两个 `backend-services-manifest.json`、四个 archive 的 sha256/size 校验和禁止文件扫描。
- `actionlint services/backend/.github/workflows/backend-native-artifact.yml`：通过。
- `git -C services/backend diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `git diff --check`：通过，仅出现 Git for Windows 行尾转换提示。
- `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过。

## 剩余风险

- Windows 本地 dry-run 没有 `chmod`，Linux 包可执行权限设置在本机仅记录 warning；GitHub Ubuntu runner 上必须实际执行 `chmod`。
- 真正的 `backend-full-windows-x64` native 构建尚未在 GitHub-hosted Windows runner 实跑。
- 主仓库 release workflow 仍需后续扩展，才能一次消费 full/services 和多平台后端 artifact。

## 相关 commit

- `4e7be9a 功能：扩展后端 native artifact 产物`（`services/backend`）
- 根仓库：本计划文件所在提交。
