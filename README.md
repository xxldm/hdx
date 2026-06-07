# HDX 工具箱

HDX 是一个待定框架的工具箱项目，暂定包含三个交付面：

- 后台服务端
- Web 端
- App 端

当前仓库处于占位与工程约束阶段。首要目标不是选型，而是先建立一套让后续人类与编码智能体都能稳定协作的边界、事实源和验证规则。

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

- `changed`：根据 Git 改动选择需要验证的文档、后端或 Web。
- `docs`：只检查关键文档和根仓库空白错误。
- `backend`：运行后端 Maven 检查。
- `web`：运行 Web test/typecheck/lint/build。
- `all`：运行全部本地常用检查。

完整规则见 `docs/QUALITY.md`。涉及后端 native 构建参数、AOT、RuntimeHints 或 Hibernate enhance 的改动，仍必须按后端 README 单独执行 native 验证。

## 当前状态

本项目尚未确定框架、包管理器、部署方式和具体模块实现。任何引入技术栈或改变目录职责的动作，都应先更新 `docs/adr/` 中的决策记录。
