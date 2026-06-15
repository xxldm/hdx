# 跨模块结构优化与边界清理

- 创建日期：2026-06-15
- 当前状态：已完成并归档。
- 外部任务：无。

## 范围

- 将 OpenAPI 与 Web 类型对齐检查从 `packages/shared` 迁到脚本检查区，避免 shared 目录反向依赖 Web 实现细节。
- 将 Web API client 的返回类型从调用方散落解析收敛到 API client 入口，保留 Zod 运行时边界校验。
- 拆分 `backend-auth-service` 中过厚的 JDBC repository，按账号、会话、审计、bootstrap/角色权限职责组织。
- 拆分 Desktop Rust 中过厚的 `online_session`、`sidecar`、`bff` 模块，减少 DTO、HTTP、状态和运行时启动逻辑混杂。
- 抽取 release/quality PowerShell 脚本中的 JSON、hash、manifest 和路径辅助能力，降低重复。

## 执行策略

- 先做纯迁移和类型入口收敛，再做后端与 Desktop 结构拆分，最后处理 release 脚本公共库。
- 每个子模块改动在对应子仓库内独立验证和提交；根仓库只提交文档、脚本和子模块指针。
- 若某个拆分需要改动行为或配置语义，先停下补记录并说明风险。

## 验证计划

- Root/docs/shared 检查：`scripts/openapi-web-type-check.ps1`、`scripts/quality-gate.ps1 -Scope docs -NoBuild`。
- Web：`pnpm test`、`pnpm typecheck`、必要时 `pnpm lint`。
- Backend：优先 `mvn -pl :backend-auth-service -am test`。
- Desktop：优先 `pnpm run typecheck`、Full/Online `cargo test` 或相称 `cargo check`。
- Release 脚本：至少运行 release manifest 校验和 docs 范围质量门禁；若只抽纯函数，补对应脚本 smoke。

## 状态记录

- 2026-06-15：根据静态扫描结果创建本计划。初始目标是结构优化，不主动引入新技术栈或改变运行时行为。
- 2026-06-15：已将 OpenAPI/Web 类型兼容检查从 `packages/shared/contracts/openapi/` 迁到 `scripts/checks/`，避免 shared 目录反向依赖 Web 手写类型；`scripts/openapi-web-type-check.ps1` 已改用新位置。
- 2026-06-15：Web 子模块已提交 `dc41f0b 重构：收敛 Web API 响应解析入口`，API client 入口统一执行 Zod 解析，调用方不再重复 parse。
- 2026-06-15：Backend 子模块已提交 `8574f51 重构：拆分认证 JDBC 仓储职责`，保留 `AuthJdbcRepository` 门面并按账号、会话、审计、bootstrap/角色权限拆分实现。
- 2026-06-15：Desktop 子模块已提交 `b0cfb45 重构：拆分 Desktop Rust 运行时模块`，拆分 online session、BFF DTO/local backend 和 sidecar runtime。
- 2026-06-15：根仓库已新增 `scripts/lib/release-common.ps1` 与 `scripts/lib/quality-gate-common.ps1`，抽取 release 与 quality gate 脚本中的重复路径、JSON、hash、命令执行和 Git 状态 helper。
- 2026-06-15：Web、Backend、Desktop 三个子模块提交均已推送到各自 `origin/main`，根仓库可以安全记录对应子模块指针。
- 2026-06-15：root/docs 验证通过后，本计划移入 `docs/plans/completed/` 归档。

## 验证结果

- Web：`pnpm test` 通过，8 个测试文件 / 40 个测试；`pnpm typecheck` 通过。
- Backend：`mvn -pl :backend-auth-service -am test` 通过，27 个测试；Maven/JDK/Mockito warning 为既有环境输出。
- Desktop：`cargo fmt --manifest-path src-tauri/Cargo.toml --check`、`cargo test --manifest-path src-tauri/Cargo.toml --features flavor-full`、`cargo test --manifest-path src-tauri/Cargo.toml --features flavor-online` 与 `node_modules/.bin/tsc.cmd --noEmit` 通过；普通权限 `pnpm run typecheck` 受 Codex Windows sandbox `EPERM lstat C:\Users\zengl` 影响未作为最终判断。
- Root：`scripts/sync-active-plan-status.ps1`、PowerShell 语法解析、`scripts/openapi-web-type-check.ps1`、`scripts/release-manifest-check.ps1` 和 `scripts/quality-gate.ps1 -Scope docs -NoBuild` 均已通过。

## 剩余风险

- Desktop 普通权限 `pnpm run typecheck` 在 Codex Windows sandbox 下仍受已知 `EPERM lstat C:\Users\zengl` 环境问题影响；本轮用项目本地 `node_modules/.bin/tsc.cmd --noEmit` 作为等价 TypeScript 验证。
- Release 与 quality gate 公共库抽取为纯 helper 迁移，已由 manifest 校验、PowerShell parser 和 docs 范围质量门禁覆盖；真实 release workflow 的完整端到端发布闭环仍属于既有 release 后续事项。

## 相关 commit

- `dc41f0b 重构：收敛 Web API 响应解析入口`（`apps/web`）
- `8574f51 重构：拆分认证 JDBC 仓储职责`（`services/backend`）
- `b0cfb45 重构：拆分 Desktop Rust 运行时模块`（`apps/desktop`）
- 根仓库：本计划归档所在提交，提交信息为 `重构：收口跨模块结构优化`。
