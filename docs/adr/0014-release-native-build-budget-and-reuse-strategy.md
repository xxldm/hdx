# ADR 0014：Release native 构建额度与复用策略

- 日期：2026-06-09
- 状态：已接受

## 背景

后端私有仓库 native-image 构建已经验证可产出 `backend-full` Linux/Windows 和 `backend-services` Linux artifact。实际 GitHub-hosted run 显示，`backend-services` 当前只有 `backend-auth-service`、`backend-gateway` 和 `backend-core-service` 三个可执行服务，顺序 native-image 编译仍可能接近或超过一个小时；后续服务数量增加后，单个 job 顺序编译容易触及 GitHub Actions job 超时，也会让发布等待时间不可接受。

同时，后端仓库保持私有，因此后端 native-image 构建会消耗私有仓库 GitHub Actions 额度。Web、Desktop、App 和主仓库组装后续会公开，标准 GitHub-hosted runner 日常 CI 不作为本 ADR 的主要额度压力。用户已确认不需要额外的“候选发布”分级；除 native-image 外，日常检查可以正常运行。

此前 ADR 0013 为降低第一版复杂度，禁止自动复用历史 Release 资产。随着后端 native-image 耗时和额度压力变得明确，需要用新的规则替代这条第一版限制。

## 决策

### 后端 services 并行构建

`backend-services` native 构建改为服务级并行：

- 每个可执行服务使用独立 GitHub Actions matrix job 运行 `mvn -pl :<module> -am -Pnative package -DskipTests -Dnative.skip=false`。
- 当前 Linux services matrix 包含 `backend-auth-service`、`backend-gateway` 和 `backend-core-service`，`max-parallel` 为 3。
- 每个服务 job 只上传单个 native executable 作为同一 workflow 内的临时 binary artifact，`retention-days: 1`。
- 平台聚合 job 下载这些临时 binary artifact，再调用后端打包脚本组装最终 `backend-services` native archive 和 `backend-native-manifest.json`。
- `backend-services-windows-x64` 采用同样的并行结构，但仍由 `include_windows_services=true` 手动开启，默认不运行。
- `backend-full-linux-x64` 和 `backend-full-windows-x64` 保持独立 job 默认运行。

这项调整主要降低发布等待时间，不承诺减少 GitHub Actions 计费分钟。多个服务并行时，总 runner 分钟可能基本持平或略增，但墙钟时间从“多个 native-image 串行累加”变为“最慢服务 native-image + 聚合打包”。

### 后端 native 额度策略

私有后端仓库的 native-image 构建只在发布需要或后端 native 输入变化时运行。后端日常 CI 可以继续运行轻量检查，但不把完整 native-image 作为每次普通提交的默认动作。

不新增“候选发布”分级。公开主仓库、Web、Desktop、App 后续公开后，除 native-image 以外的常规测试、构建、契约和组装检查可以按公开仓库 CI 正常运行；本 ADR 只对后端私有仓库 native-image 做额度约束。

### 后端未变时复用主仓库 Release asset

真实 release workflow 后续允许在后端 native 输入未变化时，复用上一版或指定历史主仓库 GitHub Release 中已经公开的后端 native asset。

复用必须满足以下条件：

- 复用来源是主仓库 GitHub Release asset，不是后端私有仓库 Actions artifact、后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库。
- 复用来源必须显式指定 release tag、asset name、sha256、size 和原始 release manifest，不允许使用 `latest`。
- 新 Release 必须重新上传该 asset，并在新的 `release-manifest.json` 中记录它来自哪个历史 Release、对应 asset、sha256、size、后端 commit、OpenAPI snapshot hash 和 backend native fingerprint。
- 后端 native fingerprint 必须完全匹配；匹配不到或无法验证时必须重新运行后端 native workflow。
- 复用旧 asset 不代表复用旧发布事实源。新的 `release-manifest.json` 仍以当前主仓库 release tag 或 root commit 作为事实源，同时记录该后端 asset 的历史构建来源。

backend native fingerprint 至少包含：

- 后端 repository 和 backend commit。
- artifact kind：`backend-full` 或 `backend-services`。
- platform：`linux-x64` 或 `windows-x64`。
- 服务列表和服务模块到 executable 的映射。
- OpenAPI snapshot hash。
- packaging schema / manifest schema 版本。
- 打包脚本版本或等价构建逻辑标识。
- GraalVM / Java 版本。
- Maven native profile、native-image 参数、Spring AOT、RuntimeHints、reachability metadata 和相关 native metadata 配置。

当前 `backend-native-manifest.json` 中的 `root.commit` 表示该后端 asset 的构建上下文，不等于复用后新 Release 的 root commit。后续实现复用时，需要让 release manifest 和校验脚本能区分“当前发布事实源”和“历史后端 asset 构建来源”。

## 备选方案

- 继续顺序编译 `backend-services`：实现最简单，但服务数量增加后很容易突破发布等待时间和 job 超时，不采用。
- 把每个后端微服务作为独立 Release asset：能减少聚合步骤，但会让 Release 页面和主仓库消费逻辑膨胀，且已被 ADR 0012 否决，不采用。
- 把后端 Actions artifact 保留更久用于复用：可以减少重编，但扩大私有临时 artifact 暴露窗口，并与 ADR 0013 的 `retention-days: 1` 冲突，不采用。
- 使用后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库保存后端 native：会引入第二套长期制品入口，用户已确认不需要，不采用。
- 增加“候选发布”分级：可以减少正式发布风险，但用户已确认除 native-image 外公开仓库 CI 可以日常运行，不需要额外发布分级，不采用。

## 影响范围

- `services/backend/.github/workflows/backend-native-artifact.yml`：`backend-services` 需要改为服务级 matrix 并行构建，再由聚合 job 生成最终 artifact。
- `services/backend/scripts/package-backend-native-artifact.ps1`：继续作为聚合打包入口，允许从下载后的 binary artifact 路径读取服务 executable。
- `services/backend/README.md`：需要说明 services 并行构建和临时 binary artifact。
- `docs/adr/0012-github-releases-artifact-boundary.md` 与 `docs/adr/0013-release-workflow-token-and-artifact-policy.md`：仍作为发布边界和凭据事实源，本 ADR 替代其中“第一版不自动复用历史 Release 资产”的限制。
- `packages/shared/contracts/release/` 与主仓库真实 release workflow：后续需要扩展 release manifest schema、样例和校验脚本，表达历史 Release asset 复用来源和 backend native fingerprint。

## 验证方式

本轮策略和并行 workflow 验证：

- 使用 `actionlint services/backend/.github/workflows/backend-native-artifact.yml` 检查 workflow 语法。
- 使用后端打包脚本 dummy dry-run 验证 `backend-services` 聚合打包仍可从显式 executable 路径生成 archive。
- 使用根仓库 `scripts/release-manifest-check.ps1` 校验生成的 `backend-native-manifest.json` 和 `backend-services-manifest.json`。
- 执行 `pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope docs -NoBuild`。

后续真实发布 workflow 实现复用时还必须验证：

- backend native fingerprint 完全匹配才允许复用。
- 新 Release 的 root commit 与历史后端 asset 的构建 root commit 可以被分别记录和校验。
- 复用 asset 的 sha256、size、禁止文件扫描和 release manifest 记录一致。
- 匹配不到旧 asset、旧 manifest 不兼容、OpenAPI hash 变化或 fingerprint 变化时，workflow 明确要求重跑后端 native 构建。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- GitHub Actions 并行 native-image 导致稳定限流、排队或成本不可接受。
- 后端 native artifact 不能通过 fingerprint 可靠判断兼容性。
- 项目决定不再复用历史 Release asset，每次 Release 都强制重建后端 native。
- 项目决定引入长期制品仓库或后端 private release 保存后端 native。

## 后续事项

- 实跑新的 `backend-services` 并行 workflow，确认默认 Linux services artifact 可生成并被主仓库校验。
- 扩展 release manifest schema、样例和校验脚本，记录历史 Release asset 复用来源和 backend native fingerprint。
- 实现主仓库真实 release workflow 中的后端 asset 复用分支。
- 确认 release notes 和版本号策略后，把复用来源展示给用户和部署者。
