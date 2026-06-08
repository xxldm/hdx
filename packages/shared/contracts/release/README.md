# release 契约

本目录保存 HDX 发布流程使用的可机读 JSON Schema。它们是 GitHub Releases 产物边界的执行契约，配合 `docs/adr/0012-github-releases-artifact-boundary.md` 使用。

本目录只定义数据形状和字段语义，不实现 GitHub Actions workflow，也不引入 schema 校验依赖。

本地校验入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1
```

默认只校验本目录下的 schema 文件存在、可解析且 `manifestKind` 与文件职责一致。后续有真实 manifest 或候选发布包时，可以传入参数做轻量字段校验和禁止文件扫描：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/release-manifest-check.ps1 `
  -BackendNativeManifestPath path/to/backend-native-manifest.json `
  -ReleaseManifestPath path/to/release-manifest.json `
  -BackendBuildPath path/to/backend-build.json `
  -BackendServicesManifestPath path/to/backend-services-manifest.json `
  -ScanPath path/to/backend-native-or-services-package
```

## 文件职责

- `backend-native-manifest.schema.json`：约束后端私有仓库 CI 上传到 GitHub Actions artifact 的 `backend-native-manifest.json`。
- `release-manifest.schema.json`：约束公开主仓库 GitHub Release 中的 `release-manifest.json`。
- `backend-build.schema.json`：约束 Desktop Full 包内的 `backend-build.json`，用于追溯内置后端来源。
- `backend-services-manifest.schema.json`：约束 `backend-services` 平台聚合包内部的 `backend-services-manifest.json`。

## 生产者与消费者

| manifest | 生产者 | 消费者 | 存放位置 |
| --- | --- | --- | --- |
| `backend-native-manifest.json` | 后端私有仓库 native CI | 主仓库 release workflow | GitHub Actions artifact 临时交接包内 |
| `release-manifest.json` | 主仓库 release workflow | 用户、部署者、后续校验脚本 | 主仓库 GitHub Release asset |
| `backend-build.json` | 主仓库 Desktop Full 打包流程 | Desktop Full 运行时、排障人员、校验脚本 | Desktop Full 安装目录或资源目录 |
| `backend-services-manifest.json` | 后端私有仓库 native CI | 服务端部署者、校验脚本 | `backend-services` 压缩包内部 `manifest/` 目录 |

## 字段规则

- `schemaVersion` 当前固定为 `1.0`。
- `version` 必须使用 `v<major>.<minor>.<patch>` 形态，可以携带 prerelease 或 build metadata。
- `root.ref` 和所有文件名不得使用 `latest`；发布事实源必须是主仓库 release tag 或 root commit。
- `root.commit`、子模块 commit 和后端 commit 均使用 40 位小写 Git SHA。
- sha256 字段均使用 64 位小写十六进制。
- `openapiSnapshotHash` 表示参与本次发布的 OpenAPI 快照集合 hash，后续 workflow 实现时必须由主仓库和后端 CI 使用同一算法生成。
- `backend-full` 表示 Desktop Full 使用的本地完整后端 native archive。
- `backend-services` 表示服务端微服务部署用平台聚合包；Release asset 不按微服务拆分，微服务粒度记录在 `backend-services-manifest.json` 的 `services` 字段中。

## 校验边界

当前 `scripts/release-manifest-check.ps1` 已覆盖 schema JSON 解析、manifest 核心字段轻量校验和禁止文件扫描原型。后续 workflow 实现时必须至少校验：

- `backend-native-manifest.json` 的 `version`、`root.ref`、`root.commit`、`openapiSnapshotHash` 与主仓库发布上下文一致。
- `release-manifest.json` 中所有 asset 的 sha256 与真实上传文件一致。
- Desktop Full 内置 `backend-build.json` 中的 `archiveSha256` 与公开 Release 中对应 `backend-full` asset 的 sha256 一致。
- `backend-services-manifest.json` 中 `files` 列表覆盖压缩包内应被追踪的二进制、配置示例和清单文件。
- 后端 native archive 和 `backend-services` 聚合包不得包含后端源码、JAR/WAR、`.class`、`target/classes` 或后端构建中间目录。

本目录当前不包含样例 manifest。后续实现完整 workflow 或正式 schema 校验时，应补充最小有效样例和无效样例。
