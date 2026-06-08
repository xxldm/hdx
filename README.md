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

## 本地质量门禁

根仓库提供统一的本地质量门禁入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope changed
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

后端、Web、Desktop、App 和基础设施边界的第一阶段技术方向已由 ADR 记录；部署方式和部分发布基础设施仍待决策。任何引入新技术栈或改变目录职责的动作，都应先更新 `docs/adr/` 中的决策记录。
