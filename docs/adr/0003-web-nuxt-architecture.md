# ADR 0003：Web 端采用 Nuxt 架构

- 日期：2026-05-26
- 状态：已接受

## 背景

HDX 需要开始确定 Web 端第一阶段架构。后端已经确定 Java 与 Spring Cloud Alibaba 架构，并通过公开 REST API 暴露能力；Web 端需要在不耦合后端内部实现的前提下，提供工具工作台界面，并为后续服务端部署和 Electron 嵌入保留空间。

本决策影响 `apps/web/` 的框架、包管理器、UI、状态管理、国际化、数据边界和验证方式。

## 决策

- Web 端采用 Nuxt 4.x，第一阶段启用默认 SSR 形态。
- UI 采用 Nuxt UI 4.x，根组件使用 `UApp`，组件优先使用 Nuxt UI 的语义色、尺寸、变体、表单和反馈能力。
- 包管理器在 `apps/web/` 内使用 pnpm；当前不把仓库根目录升级为 pnpm workspace。
- 国际化采用 `@nuxtjs/i18n`，默认语言为 `zh-CN`，备用语言为 `en-US`。
- i18n 使用应用内部状态切换，URL 不随语言变化，策略为 `no_prefix`；不使用域名、多域名或路径前缀切换语言。
- 暗黑模式默认跟随系统，用户可在浅色、深色和跟随系统之间切换，并持久化偏好。
- 状态管理从第一阶段引入 Pinia，按领域拆分 `app/stores/*`，禁止演化为单一大 store。
- 浏览器不直连后端。Web 通过 Nuxt server 暴露 BFF/proxy 路径，例如 `/api/hdx/v1/**`，再由 Nuxt server 调用后端 `/api/v1/**`。
- 后端地址、本机 all-in-one 令牌等只允许进入 Nuxt server 私有 `runtimeConfig`，不得进入 public config 或浏览器状态。
- Web 端所有表单输入、runtime config、Nuxt server handler 输入、后端响应都必须使用 Zod 做边界解析。
- UI/UX 工作必须使用 `apps/web/.codex/skills/ui-ux-pro-max` 作为设计约束；首次 UI 实现前应生成并持久化设计系统。

## 备选方案

- Vue + Vite SPA：实现更轻，但 SSR、BFF、后续 Electron/服务端共用边界需要自行补齐。
- Nuxt + 浏览器直连后端：代码更少，但 CORS、令牌暴露、SSR 数据预取和 Electron 本机令牌边界更难收束。
- 根目录 pnpm workspace：未来共享 TypeScript 包更方便，但当前后端已经是独立 Maven 工程，本轮先降低仓库根目录影响面。
- i18n URL 前缀或域名切换：更适合公开内容站点与多语言 SEO，但 HDX 第一阶段是工具工作台，内部状态切换更符合使用场景。
- Nuxt 原语优先、暂不引入 Pinia：初期依赖更少，但登录态、偏好、工作台状态后续容易分散。

## 影响范围

- `apps/web/` 成为 Nuxt Web 应用，不再只是占位目录。
- `docs/ARCHITECTURE.md` 需要同步 Web 端职责和依赖方向。
- `apps/web/README.md` 需要记录技术栈、入口、验证命令和设计技能要求。
- 后续 Web 与后端交互必须通过公开 REST API、Nuxt server 边界和 Zod schema，不允许读取后端内部模块。
- 后续如果需要从后端 OpenAPI 生成 TypeScript client，需要新增或更新 ADR。

## 验证方式

- 文档验证：检查本 ADR、`docs/ARCHITECTURE.md` 与 `apps/web/README.md` 的 Web 技术栈描述一致。
- 工程验证：在 `apps/web/` 执行 `pnpm install`、`pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`。
- 边界验证：覆盖 Zod schema、Pinia store action、Nuxt server proxy 路由解析和响应解析的成功与失败路径。
- UI 验证：有页面实现后，用浏览器检查 375、768、1024、1440px；验证浅色、深色、跟随系统三种主题，无水平滚动和明显重叠。
- i18n 验证：切换语言时 URL 保持不变，刷新后语言偏好保留。

## 回滚条件

- Nuxt 4.x 或 Nuxt UI 4.x 在目标运行环境中出现无法规避的稳定性、构建或部署问题。
- Nuxt server BFF/proxy 无法满足服务端部署或 Electron 嵌入的安全边界。
- i18n 内部状态切换不能满足后续明确的多语言 SEO 或分享链接需求。

回滚成本包括替换 Web 工程框架、重写 Nuxt server proxy、迁移 UI 组件和调整验证脚本。若只是改 i18n URL 策略或引入 OpenAPI 生成客户端，可通过补充 ADR 小步调整。

## 后续事项

- 细化 Web 认证、OAuth/JWT 登录、权限模型和路由守卫。
- 细化 Electron 嵌入时的本机 all-in-one 会话获取与令牌传递方式。
- 根据后端 OpenAPI 成熟度评估是否生成 TypeScript client。
- 将架构边界、密钥暴露和 i18n 文案覆盖逐步转成自动化检查。
