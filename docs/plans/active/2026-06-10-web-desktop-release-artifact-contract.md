# Web/Desktop 发布产物契约与打包入口

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：计划中
- 计划来源：用户确认先整理 Web/Desktop 发布产物契约，再继续接入 release workflow
- 创建时间：2026-06-10

## 目标

在继续改 `.github/workflows/release.yml` 之前，先确定 Web 与 Desktop 的发布产物形态、命名、hash、manifest 记录和最小打包入口，避免正式 release workflow 依赖未定稿的客户端打包假设。

## 非目标

- 本计划不直接实现完整 release publish。
- 本计划不接入安装器签名、公证、自动更新或 release notes。
- 本计划不创建 App Android/HarmonyOS NEXT 工程骨架。
- 本计划不改变后端 native artifact 交接边界。
- 本计划不把 Nuxt SSR Web 强行改为静态站。

## 当前事实

- Web 位于 `apps/web/`，采用 Nuxt 4 SSR + Nuxt server BFF；浏览器不直接访问后端，token 和敏感配置留在 Nuxt server 边界内。
- Web 当前已有 `pnpm build`，但 Release 产物形态尚未定稿；因为存在 BFF/session/CSRF，不能默认按纯静态 `dist` 包处理。
- Desktop 位于 `apps/desktop/`，采用 Tauri + Rust + Vite + TypeScript，已有 Local/Online flavor 配置和 `build:local`、`build:online` 脚本。
- Desktop 当前仍是只读状态面板和 capability 空壳；Local 未打包或启动真实 `backend-all-in-one`，Online 未实现远端地址填写和持久化。
- 当前正式发布链路已有 `release-start.yml`、后端 resolver 和 `release.yml` draft assemble 第一片；仍缺 Web/Desktop/App 构建、正式 publish 和失败清理。

## 待确认问题

- Web Release asset 是否采用 Nuxt SSR server bundle archive 作为第一版产物。
- Web runtime config、远端 auth/gateway 地址和版本信息如何在发布包中表达。
- Web sourcemap 是否随正式版发布，或仅用于 prerelease/debug。
- Desktop 是否先实现 Online 包，Full 包只先固定命名与 manifest 边界。
- Desktop Windows/Linux 第一版 release asset 名称、目录结构和校验入口。
- Desktop Full 如何记录同平台 `backend-full` 来源，以及 sidecar 尚未实现时如何避免假装可用。
- `release-manifest.json` 是否需要新增 Web/Desktop asset 的固定字段，还是先沿用通用 `assets[]` 来源记录。

## 本地任务清单

- [ ] 扫描 `apps/web` 的 build 命令、输出目录、运行时配置和当前质量门禁。
- [ ] 扫描 `apps/desktop` 的 Tauri 配置、flavor build 命令、bundle 输出和当前质量门禁。
- [ ] 提出 Web 第一版发布产物契约。
- [ ] 提出 Desktop Online 第一版发布产物契约。
- [ ] 提出 Desktop Full 第一版命名、manifest 和 sidecar 占位边界。
- [ ] 检查 `release-manifest.json` schema 是否需要扩展客户端 asset 元数据。
- [ ] 更新 ADR、架构文档、Release runbook 或本计划中的结论。
- [ ] 运行 docs 范围质量门禁。

## 验收标准

- Web 发布包不能再被模糊描述为静态包；必须明确 Nuxt SSR/BFF 的第一版交付形态。
- Desktop Online 与 Desktop Full 的第一版 asset 命名、平台矩阵、校验方式和 manifest 记录方式明确。
- 后续接入 `release.yml` 时，可以按本文结论实现构建 job，而不是在 workflow 中临时猜包结构。
- 尚未实现的能力必须明确标为未实现，尤其是 Desktop Full sidecar、本机 token、远端地址配置和自动更新。

## 验证结果

- 尚未执行。本计划创建后，进入实现前至少运行 docs 范围质量门禁。

## 剩余风险

- Web SSR bundle 发布后仍需要部署方式配合；本计划只解决 Release asset 契约，不解决自动部署。
- Desktop 打包可能暴露 Tauri bundler、平台依赖或 runner 环境问题，需要在后续实现切片中单独验证。
- Desktop Full sidecar 未实现前，不应发布让用户误以为可离线使用的 Full 安装包。
- App 仍不进入本计划，后续 App Online asset 需要单独计划。

## 相关 commit

- 待补。
