# generated

本目录是未来生成契约产物的候选落点。

当前不提交生成物。后续如果从 OpenAPI 生成 TypeScript 类型或协议索引，必须先确定生成器、输入 spec、输出目录、提交策略和漂移检查，并在相关 ADR 或计划中记录。

## 生成前置条件

- 先建立 OpenAPI spec 快照或可重复获取命令。
- 先建立 Web 手写 Zod schema 与 OpenAPI schema 的漂移检查入口。
- 确认生成物只服务 Nuxt server BFF 或端无关协议类型，不生成浏览器直连后端的 client。
- 确认不需要把根仓库升级为 pnpm workspace；如果需要升级，必须先补充 ADR。
