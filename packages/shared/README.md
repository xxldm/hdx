# shared 共享层

本目录用于跨端共享契约、协议常量、端无关类型和稳定小工具。当前阶段只建立轻量目录骨架，不引入包管理器、构建工具、运行时依赖或根 workspace。

## 当前状态

- 目录已作为共享层事实源占位。
- 当前不包含可被 Web、App、desktop 或后端直接导入的运行时代码。
- 当前不提供 `package.json`、TypeScript 配置或发布流程。

## 目录

- `contracts/`：人工维护的跨端协议说明、契约片段和手工示例。
- `constants/`：稳定协议常量说明，例如错误码、权限 code、actor type 等；真正落代码前必须确认消费者和验证方式。
- `generated/`：未来 OpenAPI 或其他契约工具生成产物的候选落点；生成器、命令和提交策略确认前只能放占位说明。
- `tools/`：端无关稳定小工具的候选落点；不得放端侧运行时适配。

## 允许内容

- 端无关、运行时无关的协议说明。
- 跨端共享错误码、权限 code、协议枚举和基础类型。
- 经过确认的 OpenAPI 生成类型或生成物索引。
- 不依赖后端、Web、App 或 desktop 实现细节的小工具。

## 禁止内容

- Nuxt composable、Pinia store、Vue 组件、UI 文案或 Web BFF session/CSRF 逻辑。
- Spring DTO、JPA 实体、Repository、Controller、数据库模型或后端内部配置。
- access token、refresh token、本机 token、cookie 或平台安全存储处理逻辑。
- App、desktop、浏览器、Node、JVM 或操作系统专用适配。
- 未记录来源、命令和验证方式的生成产物。

## 变更规则

- 新增可导入代码前，必须先确认包管理、构建、测试和依赖方向。
- 新增生成产物前，必须先记录生成命令、输入 OpenAPI spec、提交策略和漂移检查。
- 新增共享常量或类型时，必须说明至少一个真实消费者，以及为什么不留在端内。
- 如果某项能力只服务单端，应留在对应端内，不进入 shared。
