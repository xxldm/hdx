# 后端 Native Artifact CI

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：后端仓库 commit `4a869d5` 已推送，等待根仓库提交子模块指针后触发 GitHub-hosted workflow
- 计划来源：用户确认先做后端 artifact 生产入口，因为当前后端仓库还没有可供主仓库下载验证的 artifact
- 创建时间：2026-06-09
- 最后更新：2026-06-09

## 目标

在 `services/backend` 私有仓库中新增手动触发的 native artifact 生产入口，先产出最小 `backend-full-linux-x64` 包，供下一步主仓库验证跨仓库 artifact 列表读取、下载和 manifest 校验。

本轮完成后应具备：

- 后端仓库 `.github/workflows/backend-native-artifact.yml`。
- 后端仓库 `scripts/package-backend-native-artifact.ps1`。
- workflow 使用 `workflow_dispatch` 手动触发。
- workflow 构建 `backend-all-in-one` native，打包为 `hdx-backend-full-linux-x64-<version>.tar.gz`。
- workflow 生成 `backend-native-manifest.json`，记录 root ref、root commit、backend commit、run id、artifact name、OpenAPI hash、sha256 和 size。
- workflow 通过 `actions/upload-artifact` 上传 native 包和 manifest，`retention-days: 1`。
- workflow 不上传源码、JAR/WAR、`.class` 或后端构建中间目录。

## 非目标

- 本轮不实现 `backend-services` 多服务聚合包。
- 本轮不实现 Windows native artifact。
- 本轮不实现主仓库下载后端 artifact。
- 本轮不创建或上传 GitHub Release asset。
- 本轮不固化 OpenAPI snapshot 集合 hash 算法；workflow 先要求调用方显式传入。

## repo 内范围

- `services/backend/.github/workflows/backend-native-artifact.yml`
- `services/backend/scripts/package-backend-native-artifact.ps1`
- `services/backend/README.md`
- `docs/plans/active/2026-06-09-backend-native-artifact-ci.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`

## 本地任务清单

- [x] 创建本地计划。
- [x] 新增后端 native artifact workflow。
- [x] 新增后端 native artifact 打包脚本。
- [x] 更新后端 README。
- [x] 运行本地脚本 dry-run、workflow lint 和后端基础验证。
- [x] 提交并推送后端仓库。
- [x] 更新根仓库子模块指针和发布总纲。
- [ ] 触发 GitHub-hosted backend artifact workflow 并记录结果。

## 验收标准

- workflow 不依赖主仓库 checkout 后端源码。
- workflow 上传的 artifact 只包含 native archive 和 `backend-native-manifest.json`。
- `backend-native-manifest.json` 的版本、Git SHA、sha256 和 artifact 文件名符合根仓库 release contract。
- 后端 native 包禁止包含源码、JAR/WAR、`.class` 和后端构建中间目录。
- 后端 Actions artifact 保留期为 1 天。

## 验证方式

- `pwsh -NoLogo -NoProfile -File scripts/package-backend-native-artifact.ps1 ...` 使用临时可执行文件做本地 dry-run。
- `actionlint`
- `mvn validate`
- `git diff --check`
- 推送后触发 `backend-native-artifact.yml` 的 GitHub-hosted run。

## 风险与阻塞

- GitHub-hosted native build 可能因 GraalVM 版本、Maven 缓存或 runner 资源限制失败；失败时应记录 run id 和失败阶段。
- `backend-services`、Windows native artifact 和真实 GitHub Release workflow 仍未实现。
- OpenAPI snapshot 集合 hash 算法尚未固化，本轮只要求调用方显式传入 64 位 SHA-256。

## 状态记录

- 2026-06-09：创建计划，开始新增后端 native artifact 最小 CI。
- 2026-06-09：后端仓库新增 `.github/workflows/backend-native-artifact.yml`，第一版只生产 `backend-full-linux-x64`；新增 `scripts/package-backend-native-artifact.ps1` 负责打包、禁止文件扫描、sha256 和 `backend-native-manifest.json` 生成。
- 2026-06-09：本地普通权限写入 `services/backend/target/test-native` 时触发 `AccessDeniedException`，随后按 `docs/AGENT_WORKFLOW.md` 权限规则提权复跑通过；该现象归类为 target 写入 sandbox 权限问题，不是打包脚本缺陷。
- 2026-06-09：本地 Windows dry-run、linux-x64 dry-run、根仓库 release manifest 校验、`actionlint`、`mvn validate` 和后端空白检查均通过；等待提交推送后触发 GitHub-hosted native workflow。
- 2026-06-09：后端仓库提交 `4a869d5 功能：添加后端 native artifact workflow` 已推送到 `xxldm/hdx-backend/main`；根仓库准备更新 `services/backend` 子模块指针。

## 验证结果

- `actionlint .github/workflows/backend-native-artifact.yml`：通过。
- `pwsh -NoLogo -NoProfile -File scripts/package-backend-native-artifact.ps1 ... -Platform windows-x64 ... -ExecutablePath target\test-native\backend-all-in-one.exe`：普通权限因 `target/test-native` 写入被拒失败一次，提权复跑通过，生成 zip 与 `backend-native-manifest.json`。
- `pwsh -NoLogo -NoProfile -File scripts/package-backend-native-artifact.ps1 ... -Platform linux-x64 ... -ExecutablePath target\test-native\backend-all-in-one.exe`：提权通过，生成 tar.gz 与 `backend-native-manifest.json`；Windows 本地无 `chmod`，脚本按预期提示跳过本地模拟的 Linux 可执行权限设置，GitHub Ubuntu runner 仍必须执行 `chmod`。
- `pwsh -NoLogo -NoProfile -File scripts/release-manifest-check.ps1 -BackendNativeManifestPath services\backend\target\release-artifacts\backend-native-manifest.json -AssetRoot services\backend\target\release-artifacts -ScanPath services\backend\target\release-artifacts\stage\hdx-backend-full-linux-x64-v0.0.0-artifact-test.1`：通过，确认生成 manifest 符合根仓库 release contract，sha256/size 与包文件一致，禁止文件扫描通过。
- `mvn validate`：通过；保留 JDK 25 下 Maven/Jansi/Unsafe warning，不阻塞本轮验证。
- `git diff --check`：通过，仅提示 README 后续由 Git 接触时会按仓库行尾规则转换，不是空白错误。

## 剩余风险

- GitHub-hosted native build 尚未触发，仍需验证 GraalVM JDK 25、Maven native profile 和 `actions/upload-artifact@v7.0.1` 在远端 runner 上实际通过。
- `backend-services`、Windows native artifact 和主仓库跨仓库 artifact 下载验证仍未实现。
- OpenAPI snapshot 集合 hash 算法尚未固化，本轮 workflow 只要求调用方显式传入 64 位 SHA-256。

## 相关 commit

- `4a869d5 功能：添加后端 native artifact workflow`（`services/backend`）
