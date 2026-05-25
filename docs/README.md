# 文档索引

本文档目录是 HDX 工具箱的事实源。仓库内项目文档默认使用中文编写。

## 核心文档

- `CONSTRAINTS.md`：项目约束。
- `ARCHITECTURE.md`：暂定架构。
- `QUALITY.md`：质量门禁。
- `HARNESS_ENGINEERING.md`：Harness Engineering 实践到本项目约束的映射。
- `adr/`：架构决策记录。
- `plans/`：执行计划与技术债记录。

## 维护规则

- 新增长期规则时，优先更新核心文档。
- 新增或改变技术选型时，必须新增 ADR。
- 文档过期时，按缺陷处理。
- 大型工作应在 `plans/active/` 中创建计划，完成后移动到 `plans/completed/`。
