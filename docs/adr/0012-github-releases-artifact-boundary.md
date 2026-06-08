# ADR 0012：GitHub Releases 产物边界

- 日期：2026-06-08
- 状态：已接受

## 背景

HDX 第 9 步“部署、发布与环境管理”已确认：不做自动部署，使用 GitHub CI 生成包，并发布到公开主仓库的 GitHub Releases。

此前 ADR 0011 已确认公开主仓库 Apache-2.0、后端源码私有、公开主仓库禁止提交后端源码、JAR/WAR 和 `.class` 构建产物。后续仍需要明确：

- 后端 native 必须先于主仓库 Full 包完成，避免主仓库集成过时后端。
- 主仓库 CI 不能为了构建 Full 包而 checkout 后端私有源码。
- 后端 native 产物的临时交接位置必须固定，避免引入多套 artifact 存储策略。
- 主仓库 Releases 是否包含后端 native 包，以及后端微服务如何在 Release 页面中保持清晰。
- Web、Desktop 和 App 如何参与同一 release，且不使用 `latest`。

## 决策

公开主仓库 GitHub Releases 是 HDX 唯一公开发布入口；该入口只负责公开分发包，不代表自动部署。

发布事实源：

- 每次发布以主仓库 release tag 或 root commit 作为事实源。
- Web、Desktop、shared/OpenAPI 快照和后续 App 工程均使用主仓库锁定的提交或子模块指针。
- 发布流程禁止从 Web、Desktop、后端或 App 拉取 `latest`。
- 所有产物必须能通过 `release-manifest.json` 追溯到版本、root commit、子模块 commit、OpenAPI snapshot hash、后端 commit 和 sha256。

后端 native 交接：

- 后端私有仓库 CI 是后端 native 的唯一编译者。
- 后端 CI 先编译 native archive，生成 manifest 和 sha256，再上传到 GitHub Actions artifact。
- GitHub Actions artifact 只作为临时 CI 交接点；本决策不引入 S3、RustFS、云 OSS、独立 artifact 仓库或后端 private release 作为 native 交接存储。
- 后端 CI 完成后触发主仓库 release workflow，并携带版本、root ref、manifest 标识和校验信息。
- 主仓库 release workflow 可以使用最小权限凭据下载后端 Actions artifact，但不得 checkout、复制、缓存或打包后端私有源码。

主仓库校验与组装：

- 主仓库 release workflow checkout 指定 root ref，并初始化到根仓库锁定的子模块 commit。
- 主仓库下载后端 Actions artifact 后，必须校验 manifest 中的 `version`、`rootRef`、OpenAPI/API contract hash、后端 commit、平台列表和 sha256。
- 主仓库必须扫描后端 native archive，禁止源码、JAR/WAR、`.class`、`target/classes` 和后端构建中间目录进入主仓库 Release。
- Desktop Full 内置的后端 native 必须与主仓库 Release 中公开的 `backend-full` native archive 同源，并写入 `backend-build.json` 记录后端版本、commit、root ref 和 sha256。

主仓库 Release 资产粒度：

- Release 页面只放用户或部署者直接下载的聚合产物，不按每个后端微服务拆成独立 asset。
- 后端支持微服务部署，但通过 `backend-services` 平台聚合包发布；包内部保留微服务粒度。
- `backend-full` 表示用户可见的本地完整后端 native 包；当前内部模块名 `backend-all-in-one` 暂不因本 ADR 重命名。
- App 不内置后端，不提供移动端 Full/all-in-one 包；App 第一阶段只发布 Online 客户端，第二阶段只规划离线缓存和离线草稿。

第一版 Release asset 命名基线：

```text
hdx-web-v0.1.0.zip

hdx-desktop-online-windows-x64-v0.1.0.msi
hdx-desktop-online-linux-x64-v0.1.0.AppImage

hdx-desktop-full-windows-x64-v0.1.0.msi
hdx-desktop-full-linux-x64-v0.1.0.AppImage

hdx-backend-full-windows-x64-v0.1.0.zip
hdx-backend-full-linux-x64-v0.1.0.tar.gz

hdx-backend-services-windows-x64-v0.1.0.zip
hdx-backend-services-linux-x64-v0.1.0.tar.gz

SHA256SUMS
release-manifest.json
```

后续 App 工程进入可打包状态后，可以按同一 release 追加 Online 客户端包，例如：

```text
hdx-android-online-v0.1.0.apk
hdx-harmonyos-online-v0.1.0.app
```

`backend-services` 包内部建议结构：

```text
bin/
  hdx-gateway
  hdx-auth-service
  hdx-core-service
config/
  gateway.example.yml
  auth-service.example.yml
  core-service.example.yml
manifest/
  backend-services-manifest.json
  SHA256SUMS
```

## 备选方案

- 主仓库 Action checkout 后端源码并编译：短期流程简单，但会把私有源码读取权限扩大到公开主仓库 CI 执行面，容易通过 artifact、cache、日志或 workflow 修改泄漏源码，不采用。
- 主仓库拉取 `latest` 后端 native：实现简单，但无法保证 Full 包和后端 native 属于同一发布事实源，容易集成过时后端，不采用。
- 后端 private release 保存 native 包：可复用 GitHub Release 机制，但仍需要跨仓库读取凭据，且会形成第二个长期发布入口；用户已确认 native 交接只使用 GitHub Actions artifact，不采用。
- S3、RustFS、云 OSS 或独立 artifact 仓库保存 native 包：适合更复杂的制品管理，但当前用户确认不需要这些分支，不采用。
- 每个后端微服务单独作为 Release asset：部署粒度清楚，但 Release 页面会迅速膨胀；改为按平台聚合为 `backend-services` 压缩包，包内部保留微服务粒度。
- App 提供 Full/all-in-one 包：与 ADR 0009 冲突，移动端已确认不内置后端，不采用。

## 影响范围

- 后续 GitHub Actions workflow 必须遵守本 ADR 的顺序、artifact 交接和禁止项。
- `services/backend` 私有仓库后续需要生成后端 native archive、manifest 和 sha256，并触发主仓库 release workflow。
- 主仓库后续 release workflow 需要下载后端 Actions artifact、校验 manifest、扫描禁止文件、构建 Web/Desktop/App，并上传统一 Release asset。
- `apps/desktop` 的 Full 打包后续需要写入 `backend-build.json`，记录内置后端 native 来源。
- `docs/ARCHITECTURE.md`、`docs/CONSTRAINTS.md`、README 和后续事项总纲需要记录本发布边界。

## 验证方式

本轮文档决策验证：

- 使用 `Get-Content -Encoding UTF8` 读取本 ADR、约束、架构、README 和计划。
- 使用 `rg` 检查 GitHub Releases、Actions artifact、backend-services、backend-full、`latest`、App 不内置后端和后端源码禁止项是否可发现。
- 执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`。

后续 workflow 实现时必须补齐：

- 后端 native manifest schema 校验。
- 后端 native archive sha256 校验。
- 后端 native archive 禁止文件扫描，覆盖源码、JAR/WAR、`.class`、`target/classes` 和构建中间目录。
- Release asset 与 `release-manifest.json` 一致性检查。
- Desktop Full 内置 `backend-build.json` 与 Release 中 `backend-full` archive 的 sha256 一致性检查。

## 回滚条件

满足以下任一条件时，需要新增 ADR 替代本决策：

- 项目决定不再公开分发后端 native 二进制。
- 项目决定主仓库 CI 可以 checkout 后端私有源码，并接受对应泄漏风险。
- 项目决定引入 S3、RustFS、云 OSS、独立 artifact 仓库或后端 private release 作为 native 长期或临时交接存储。
- 项目决定 App 提供移动端 Full/all-in-one 包。
- 后端发布粒度从平台聚合包改为每个微服务独立 Release asset。

## 后续事项

- 设计并实现后端私有仓库 native CI：编译 `backend-full` 与 `backend-services`、生成 manifest、上传 Actions artifact、触发主仓库 release workflow。
- 设计并实现主仓库 release workflow：下载 artifact、校验 manifest、扫描禁止文件、构建 Web/Desktop/App、生成 `SHA256SUMS` 和 `release-manifest.json`。
- 定义 `release-manifest.json`、`backend-build.json` 和 `backend-services-manifest.json` 的 schema。
- 后续单独确认安装器签名、公证、自动更新、release notes 和版本号策略。
