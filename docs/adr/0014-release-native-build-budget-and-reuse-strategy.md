# ADR 0014：Release native 构建额度与复用策略

- 日期：2026-06-09
- 状态：已接受
- 修订：2026-07-05 收敛为公开 release 策略；后端模块名/服务名不敏感，内部职责拆分、native 参数和诊断细节迁入后端私有文档。

## 背景

后端私有仓库 native-image 构建已经验证可产出 Desktop Full 使用的本机后端 native artifact 和服务端 Services native artifact。顺序 native-image 编译耗时较长，后续服务数量增加后，单个 job 顺序编译容易触及 GitHub Actions job 超时，也会让发布等待时间不可接受。

同时，后端仓库保持私有，因此后端 native-image 构建会消耗私有仓库 GitHub Actions 额度。Web、Desktop、App 和主仓库组装后续会公开，标准 GitHub-hosted runner 日常 CI 不作为本 ADR 的主要额度压力。用户已确认不需要额外的“候选发布”分级；除 native-image 外，日常检查可以正常运行。

此前 ADR 0013 为降低第一版复杂度，禁止自动复用历史 Release 资产。随着后端 native-image 耗时和额度压力变得明确，需要用新的规则替代这条第一版限制。

## 决策

### 后端 services 并行构建

后端 Services native 构建采用“服务级并行 + 平台级聚合”：

- 后端私有仓库负责维护具体服务列表、matrix、Maven/native 参数和聚合脚本。
- 每个服务 job 只上传同一 workflow 内使用的临时 binary artifact，保留期尽量短。
- 平台聚合 job 下载临时 binary artifact，组装最终 Services native archive 和后端 native manifest。
- Services Windows native 构建保留可选入口，默认不运行。
- Desktop Full 使用的本机后端 native artifact 保持独立构建和发布边界。

这项调整主要降低发布等待时间，不承诺减少 GitHub Actions 计费分钟。多个服务并行时，总 runner 分钟可能基本持平或略增，但墙钟时间从“多个 native-image 串行累加”变为“最慢服务 native-image + 聚合打包”。

### 后端 native 额度策略

私有后端仓库的 native-image 构建只在发布需要或后端 native 输入变化时运行。后端日常 CI 可以继续运行轻量检查，但不把完整 native-image 作为每次普通提交的默认动作。

不新增“候选发布”分级。公开主仓库、Web、Desktop、App 后续公开后，除 native-image 以外的常规测试、构建、契约和组装检查可以按公开仓库 CI 正常运行；本 ADR 只对后端私有仓库 native-image 做额度约束。

### 后端未变时复用主仓库 Release asset

真实 release workflow 允许在后端 native 输入未变化时，复用最新一个合格或显式指定的历史主仓库 GitHub Release 中已经公开的后端 native asset。

复用必须满足以下条件：

- 复用来源是主仓库 GitHub Release asset，不是后端私有仓库 Actions artifact、后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库。
- 复用来源必须在解析结果中显式记录 release tag、asset name、sha256、size 和原始 release manifest，不允许使用 `latest`。
- 新 Release 必须重新上传该 asset，并在新的 `release-manifest.json` 中记录它来自哪个历史 Release、对应 asset、sha256、size、后端 commit、OpenAPI snapshot hash 和 backend native fingerprint。
- backend native fingerprint 必须完全匹配；匹配不到或无法验证时必须重新运行后端 native workflow。
- 复用旧 asset 不代表复用旧发布事实源。新的 `release-manifest.json` 仍以当前主仓库 release tag 或 root commit 作为事实源，同时记录该后端 asset 的历史构建来源。

backend native fingerprint 的具体组成和生成规则由后端私有仓库维护。公开主仓库只把 fingerprint 当作不可伪造、需精确匹配的 release 校验输入，并在 manifest/schema 中记录可公开字段。

### 正式 release workflow 中的接入方式

主仓库正式 `release.yml` 的后端资产解析 job 统一处理后端 native 来源，并向后续 job 输出同一种已校验资产目录：

- `github-actions-artifact` 来源：按显式指定的后端仓库、run id 和 artifact name 下载后端短期 Actions artifact。
- `historical-release-asset` 来源：按显式指定的历史主仓库 Release tag 和 asset name 下载历史 release manifest、后端 native manifest 和后端 native asset。
- 两种模式都必须运行 release manifest schema 校验、sha256/size 校验、OpenAPI hash 校验、禁止文件扫描和 backend native fingerprint 校验。
- 两种模式都不得 checkout 后端私有源码，也不得从后端仓库或主仓库查找 `latest`。
- Desktop Full 所需本机后端 native artifact 和 Services 服务端 native artifact 均由显式输入和 release manifest 表达。

历史 Release asset 复用进入正式 `release.yml` 时，第一版保持已验证的“保留历史后端 native asset 文件名”规则，不在复用流程中重命名后端 native archive。这样可以保持历史后端 native manifest 的 provenance 和 sha256/size 记录不被重写。如果后续希望按新版本重命名复用 asset，必须先新增 manifest rewrite 规则和对应校验。

## 备选方案

- 继续顺序编译 Services：实现最简单，但服务数量增加后很容易突破发布等待时间和 job 超时，不采用。
- 把每个后端微服务作为独立 Release asset：能减少聚合步骤，但会让 Release 页面和主仓库消费逻辑膨胀，且已被 ADR 0012 否决，不采用。
- 把后端 Actions artifact 保留更久用于复用：可以减少重编，但扩大私有临时 artifact 暴露窗口，并与 ADR 0013 的短保留期边界冲突，不采用。
- 使用后端 private release、S3、RustFS、云 OSS 或独立 artifact 仓库保存后端 native：会引入第二套长期制品入口，用户已确认不需要，不采用。
- 增加“候选发布”分级：可以减少正式发布风险，但用户已确认除 native-image 外公开仓库 CI 可以日常运行，不需要额外发布分级，不采用。

## 影响范围

- 后端私有仓库 workflow：负责 Services native 并行构建、临时 binary artifact、平台聚合、后端 native manifest 和 fingerprint 生成。
- 主仓库 release workflow：负责下载、校验、复用和发布后端 native asset，但不 checkout 后端私有源码。
- `packages/shared/contracts/release/`：继续承载公开 release manifest schema、样例和校验脚本所需的公开字段。
- `scripts/release-draft-reuse-backend-assets.ps1` 与主仓库 release workflow：继续表达并验证历史 Release asset 复用来源和 backend native fingerprint。
- `docs/adr/0012-github-releases-artifact-boundary.md` 与 `docs/adr/0013-release-workflow-token-and-artifact-policy.md`：仍作为发布边界和凭据事实源，本 ADR 替代其中“第一版不自动复用历史 Release 资产”的限制。

## 验证方式

公开主仓库验证：

- 使用 release manifest 校验脚本验证后端 native manifest、release manifest、sha256、size、fingerprint 和禁止文件扫描。
- 使用历史 Release asset 复用脚本基于历史 Release asset 本地夹具生成复用资产，并复跑 release manifest 校验。
- 使用 workflow 静态校验检查主仓库 release/debug workflow。
- 通用文档验证按 `docs/QUALITY.md` 和 `docs/AGENT_WORKFLOW.md` 执行。

后端私有仓库验证：

- Services 并行 workflow、native-image 参数、平台聚合脚本、native 编译、runtime smoke 和诊断命令在 `services/backend/README.md` 与 `services/backend/docs/README.md` 维护。

后续真实发布 workflow 实现复用时还必须验证：

- backend native fingerprint 完全匹配才允许复用。
- 新 Release 的 root commit 与历史后端 asset 的构建 root commit 可以被分别记录和校验。
- 复用 asset 的 sha256、size、禁止文件扫描和 release manifest 记录一致。
- 匹配不到旧 asset、旧 manifest 不兼容、OpenAPI hash 变化或 fingerprint 变化时，workflow 明确要求重跑后端 native 构建。
- 两种后端来源输出相同结构的已校验后端资产目录。
- Desktop Full 打包读取的本机后端 native archive 与最终 Release 公开的同平台 asset 完全同源。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- GitHub Actions 并行 native-image 导致稳定限流、排队或成本不可接受。
- 后端 native artifact 不能通过 fingerprint 可靠判断兼容性。
- 项目决定不再复用历史 Release asset，每次 Release 都强制重建后端 native。
- 项目决定引入长期制品仓库或后端 private release 保存后端 native。

## 后续事项

- Services Linux 并行 workflow 已完成 GitHub-hosted 实跑验证；Windows Services 包仍默认不跑，后续需要发布时再显式验证。
- `.github/workflows/release-start.yml` 第一版已支持真实 `v*` tag push，并已把历史复用判断迁回主仓库：先检查合格历史 Release，复用成功时直接触发主仓库 assemble，复用失败时才触发后端 resolver 运行 native build。
- `.github/workflows/release.yml` 第一版已支持多个后端 Actions artifact 聚合、同一个历史主仓库 Release 中多个后端 native asset 复用、Web node-server asset、Desktop Online asset、Desktop Full asset 和 `release_mode=publish`。
- 后端私有仓库 release resolve 已收缩为 native build resolver；实现细节以后端私有文档为准。
