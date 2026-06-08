# contracts

本目录用于人工维护的跨端协议说明、契约片段和手工示例。

当前不放后端 Java DTO、Web Zod schema 或端侧展示模型。后续如果某个协议需要多个交付面共同理解，应先在这里说明协议语义、字段边界、错误路径和验证方式，再决定是否生成或实现为可导入类型。

## 子目录

- `openapi/`：OpenAPI 契约检查输入，当前记录 Web/BFF 已依赖的后端公开路径、关键 schema 字段清单和外部入口 spec 快照。
- `release/`：GitHub Releases 与后端 native 交接使用的发布 manifest JSON Schema，覆盖 `backend-native-manifest.json`、`release-manifest.json`、`backend-build.json` 和 `backend-services-manifest.json`。
