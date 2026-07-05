# Web 端 Nuxt 架构 v1 实施计划

- 创建日期：2026-05-26
- 当前状态：已完成并归档。Web Nuxt v1 骨架、文档、自动化验证和浏览器检查已完成
- 计划来源：用户确认的“Web 端 Nuxt 架构决策计划”
- 文档语言：中文

## 目标摘要

- Web 第一阶段采用 Nuxt 4.x 默认 SSR 形态，后续保留 Electron 嵌入可能。
- UI 采用 Nuxt UI 4.x，界面定位为工具工作台，不做营销落地页。
- i18n 使用 `@nuxtjs/i18n`，默认 `zh-CN`，备用 `en-US`，通过应用内部状态切换语言，URL 不随语言变化。
- 暗黑模式默认跟随系统，并允许用户切换浅色、深色和跟随系统。
- 状态管理从第一阶段引入 Pinia，并按领域拆分 store。
- Web 边界解析与显式校验使用 Zod。
- 浏览器不直连后端；浏览器调用 Nuxt server BFF/proxy 路径，Nuxt server 再访问后端公开 REST API。
- pnpm 仅作用于 `apps/web/`，当前不把仓库根目录升级为 pnpm workspace。
- UI/UX 工作必须使用 `apps/web/.codex/skills/ui-ux-pro-max`，并把该技能加入 `apps/web/skills-lock.json`。

## 实施状态

| 编号 | 状态 | 项目 | 验收标准 |
| --- | --- | --- | --- |
| 0 | 已完成 | 持久化本实施计划 | 本文件已归档到 `docs/plans/completed/`，并保留为后续状态源。 |
| 1 | 已完成 | 新增 Web 架构 ADR | `docs/adr/0003-web-nuxt-architecture.md` 记录背景、决策、备选方案、影响范围、验证方式、回滚条件。 |
| 2 | 已完成 | 更新架构事实源 | `docs/ARCHITECTURE.md` 已记录 Web 第一阶段 Nuxt 架构、依赖方向和 BFF/proxy 边界。 |
| 3 | 已完成 | 创建 Nuxt 4 工程骨架 | `apps/web/` 包含 `package.json`、Nuxt 配置、应用入口、样式入口、页面、Pinia store、i18n 资源和测试配置。 |
| 4 | 已完成 | 实现 UI 工作台最小首屏 | 首屏使用 Nuxt UI、`UApp`、语义色、主题切换、语言切换和工具工作台布局。 |
| 5 | 已完成 | 实现 Web 边界校验与代理 | Nuxt server 暴露 `/api/hdx/v1/**`，使用私有 runtime config 调用后端 `/api/v1/**`，并用 Zod 校验输入和响应。 |
| 6 | 已完成 | 加入设计技能锁 | `apps/web/skills-lock.json` 包含 `ui-ux-pro-max`，并记录当前 `SKILL.md` SHA256。 |
| 7 | 已完成 | 更新 Web README | README 记录入口、技术栈、验证命令、设计技能和失败处理。 |
| 8 | 已完成 | 运行 Web 验证 | 已执行 `pnpm install`、`pnpm typecheck`、`pnpm lint`、`pnpm test`、`pnpm build`。 |
| 9 | 已完成 | 浏览器检查 | 已启动本地 Web 后检查首屏、主题和语言切换；URL 保持不变，当前浏览器窗口无水平溢出。 |

## 已确认约束

- 本轮只固定 Web 技术栈、工程骨架和边界，不细化 OAuth/JWT 登录、权限模型和 Electron 本机令牌获取细节。
- 后端地址、本机令牌等敏感配置只允许在 Nuxt server 私有 `runtimeConfig` 中出现。
- i18n 不使用域名、多域名或路径前缀切换语言。
- Web 后续与后端交互必须通过公开 REST API、Nuxt server 边界和 Zod schema，不允许读取后端内部模块。
- 后续如果需要从后端 OpenAPI 生成 TypeScript client，需要新增或更新 ADR。

## 状态记录

- 2026-05-26：计划已持久化，开始同步项目规则与创建 Web 工程骨架。
- 2026-05-26：已新增 Web 架构 ADR 并更新 `docs/ARCHITECTURE.md`。
- 2026-05-26：已把“需要计划的工作必须落到 `docs/plans/` 本地文件”加入 `AGENTS.md`、`docs/CONSTRAINTS.md` 与 `docs/plans/README.md`。
- 2026-05-26：已生成 `apps/web/design-system/hdx-web/`，查询关键词为 `HDX toolbox workbench SaaS dashboard professional productive`。
- 2026-05-26：已创建 Nuxt 4 Web 骨架、工作台首页、Pinia store、i18n 资源、Zod schema 和 Nuxt server BFF/proxy 路由，等待依赖安装与验证。
- 2026-05-26：已更新 `apps/web/skills-lock.json`，加入本地 `ui-ux-pro-max` 技能；已更新 `apps/web/README.md`。
- 2026-05-26：普通沙箱执行 `pnpm` 会因访问 `C:\Users\zengl` 权限失败，已按权限规则使用提权命令运行 pnpm。
- 2026-05-26：`pnpm install` 成功，实际解析版本为 Nuxt `4.4.6`、Nuxt UI `4.8.0`、`@nuxtjs/i18n` `10.4.0`、`@pinia/nuxt` `0.11.3`、Zod `4.4.3`。
- 2026-05-26：`pnpm typecheck`、`pnpm lint`、`pnpm test` 通过；当前测试 3 个文件 7 个用例通过。
- 2026-05-26：`pnpm build` 通过；构建过程中仅出现 sourcemap、依赖 PURE 注释和 Node trailing slash exports deprecation 警告。
- 2026-05-26：浏览器打开 `http://127.0.0.1:3000/` 验证通过；后端未启动时显示可理解提示，切换 English 后 URL 仍为 `/`，刷新后语言偏好和 dark 主题保留，当前浏览器窗口无水平溢出。
- 2026-05-26：浏览器检查过程中发现 store 内存在中文硬编码错误文案，已改为 i18n key 并复跑 `pnpm test`、`pnpm typecheck`、`pnpm lint`、`pnpm build` 通过。
- 2026-05-26：预览服务日志曾放在 `.output/preview-err.log`，导致后续 build 清理 `.output` 时 Windows 文件锁报错；已停止预览进程并改用 `.nuxt-preview/` 作为临时预览日志目录。
- 2026-06-07：复核本计划实施状态、Web 工程目录和后续架构事实源后，确认 Web Nuxt v1 计划已完成并移动到 `docs/plans/completed/`。
