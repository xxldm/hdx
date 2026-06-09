# HDX 工具箱

HDX 是一个工具箱项目，当前暂定包含四个交付面：

- 后台服务端
- Web 端
- Desktop 端
- App 端

当前仓库仍在逐步落地各端骨架。首要目标是让后续人类与编码智能体都能在清晰边界、事实源和验证规则下协作。

## 文档入口

- `AGENTS.md`：智能体工作入口与硬性规则。
- `docs/CONSTRAINTS.md`：项目约束。
- `docs/ARCHITECTURE.md`：暂定架构。
- `docs/QUALITY.md`：质量门禁。
- `docs/HARNESS_ENGINEERING.md`：Harness Engineering 约束映射。
- `docs/adr/`：架构决策记录。

## 文档语言

仓库内项目文档默认使用中文编写。外部规范名称、代码标识符、命令、错误输出、协议字段和必要引用可以保留原文。

## 许可与仓库边界

本公开主仓库采用 Apache License 2.0，详见 `LICENSE` 和 `NOTICE`。独立子模块、外部依赖、生成产物或另有声明的文件按各自许可处理。

`services/backend` 后续维持私有仓库；公开主仓库禁止提交后端源码快照、后端 Spring Boot JAR/WAR、`.class` 文件和后端构建中间产物。后端发布目标只面向 native executable archive，不发布 JAR/WAR。HDX 名称、Logo、图标和官方发布标识不随 Apache-2.0 授权给容易混淆的使用方式。

公开主仓库 GitHub Releases 后续作为唯一公开发布入口。后端私有仓库先编译 native，并只通过 GitHub Actions artifact 临时交接给主仓库；主仓库可以公开后端 native archive，但不 checkout 后端私有源码，也不发布 JAR/WAR、`.class`、源码或后端构建中间产物。发布产物边界详见 `docs/adr/0012-github-releases-artifact-boundary.md`；真实 release workflow 的跨仓库凭据与 artifact 策略详见 `docs/adr/0013-release-workflow-token-and-artifact-policy.md`，使用 GitHub App token、后端 artifact `retention-days: 1`；后端 native 构建额度与历史 Release asset 复用策略详见 `docs/adr/0014-release-native-build-budget-and-reuse-strategy.md`；日常 tag-only 发布操作见 `docs/RELEASE_RUNBOOK.md`。发布 manifest JSON Schema 位于 `packages/shared/contracts/release/`。

## 本地质量门禁

根仓库提供统一的本地质量门禁入口：

```powershell
pwsh -NoLogo -NoProfile -File scripts/quality-gate.ps1 -Scope changed
```

常用范围：

- `changed`：根据 Git 改动选择需要验证的文档、后端、Web 或 Desktop。
- `docs`：只检查关键文档和根仓库空白错误。
- `backend`：运行后端 Maven 检查。
- `web`：运行 Web test/typecheck/lint/build。
- `desktop`：检查 Desktop 骨架；未使用 `-NoBuild` 时运行 TypeScript 和 Rust flavor 检查。
- `all`：运行全部本地常用检查。

完整规则见 `docs/QUALITY.md`。涉及后端 native 构建参数、AOT、RuntimeHints 或 Hibernate enhance 的改动，仍必须按后端 README 单独执行 native 验证。

## 当前状态

后端、Web、Desktop、App、基础设施、公开许可、GitHub Releases 产物边界、release manifest schema 和真实 release workflow 凭据/artifact 策略的第一阶段技术方向已由 ADR 和 shared 契约记录；主仓库已提供 release dry-run workflow 骨架并完成 GitHub-hosted 实跑验证，但真实 GitHub Release workflow 实现、安装器签名、公证、自动更新、release notes 和版本号策略仍待决策或实施。任何引入新技术栈或改变目录职责的动作，都应先更新 `docs/adr/` 中的决策记录。
