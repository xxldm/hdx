# shared 共享层

本目录用于跨端共享契约、协议常量、端无关类型和稳定小工具。当前阶段只建立轻量目录骨架，不引入包管理器、构建工具、运行时依赖或根 workspace。

## 当前状态

- 目录已作为共享层事实源占位。
- 当前包含 OpenAPI schema TypeScript 类型生成物原型，但不包含请求 client、运行时校验器或端侧适配代码。
- 当前不提供 `package.json`、TypeScript 配置或发布流程。

## 目录

- `contracts/`：人工维护的跨端协议说明、契约片段和手工示例。
- `constants/`：稳定协议常量说明，例如错误码、权限 code、actor type 等；真正落代码前必须确认消费者和验证方式。
- `generated/`：OpenAPI 或其他契约工具生成 TypeScript 类型的候选落点；当前已有 `generated/openapi/` 类型生成物原型和漂移检查。
- `tools/`：端无关稳定小工具的候选落点；不得放端侧运行时适配。

## 允许内容

- 端无关、运行时无关的协议说明。
- 跨端共享错误码、权限 code、协议枚举和基础类型。
- 经过确认的 OpenAPI 生成 TypeScript 类型或生成物索引。
- 不依赖后端、Web、App 或 desktop 实现细节的小工具。

## 禁止内容

- Nuxt composable、Pinia store、Vue 组件、UI 文案或 Web BFF session/CSRF 逻辑。
- Spring DTO、JPA 实体、Repository、Controller、数据库模型或后端内部配置。
- access token、refresh token、本机 token、cookie 或平台安全存储处理逻辑。
- App、desktop、浏览器、Node、JVM 或操作系统专用适配。
- 未记录来源、命令和验证方式的生成产物。
- 完整 API client、请求封装、鉴权注入、缓存策略或浏览器直连后端调用逻辑。

## 变更规则

- 新增可导入代码前，必须先确认包管理、构建、测试和依赖方向。
- 新增生成产物前，必须先遵守 `docs/adr/0007-openapi-typescript-generation-strategy.md`，并记录生成命令、输入 OpenAPI spec、提交策略和漂移检查。
- 新增共享常量或类型时，必须说明至少一个真实消费者，以及为什么不留在端内。
- 如果某项能力只服务单端，应留在对应端内，不进入 shared。
