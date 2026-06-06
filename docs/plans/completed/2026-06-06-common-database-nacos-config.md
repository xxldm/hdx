# 公共数据库 Nacos 配置

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成
- 计划来源：用户要求为多模块增加通用数据库配置，同时保留模块单独配置方案
- 创建时间：2026-06-06
- 最后更新：2026-06-06

## 目标

减少后端多服务重复维护数据库 JDBC URL 和用户名，同时保留单个模块使用独立数据库、独立用户名或独立密码的能力。

## 范围

- `backend-core-service` 与 `backend-auth-service` 的 service profile Nacos 导入顺序。
- `docs/config/nacos/` 中的 Nacos Data ID 示例。
- 根目录环境变量模板与环境配置文档。
- 后端 README 与架构文档。

## 决策

- 新增公共数据库 Data ID：`hdx-database.yml`。
- 公共数据库 Data ID 只保存非密钥配置：`spring.datasource.url` 和 `spring.datasource.username`。
- `backend-core-service` 与 `backend-auth-service` 先可选导入公共数据库 Data ID，再导入自己的服务 Data ID。
- 服务 Data ID 可以覆盖公共数据库配置，用于模块单独数据库或用户名。
- 数据库密码继续通过环境变量或部署 Secret 注入，默认使用 `HDX_POSTGRES_PASSWORD`。
- 认证服务可用 `HDX_AUTH_POSTGRES_PASSWORD` 覆盖默认密码，核心服务可用 `HDX_CORE_POSTGRES_PASSWORD` 覆盖默认密码。
- `backend-gateway` 不导入公共数据库配置。

## Checklist

- [x] 新增公共数据库 Nacos 示例。
- [x] 调整 core/auth service profile 导入顺序。
- [x] 增加模块专用数据库密码覆盖入口。
- [x] 更新环境变量模板和环境文档。
- [x] 更新后端 README 与架构说明。
- [x] 执行后端验证。
- [x] 提交后端子模块改动。
- [x] 提交根仓库文档。
- [ ] 提交根仓库子模块指针。

## 状态记录

- 2026-06-06：创建计划并开始实施公共数据库配置分层。
- 2026-06-06：完成配置与文档改动，后端 `mvn test` 通过。
- 2026-06-06：后端子模块提交 `fe98dbb`；因为直接推送 `origin/main` 需要用户再次明确授权，当前根仓库暂不提交子模块指针。

## 验证结果

- `mvn test`：通过，覆盖后端 7 个 Maven 模块。

## 剩余风险

- 尚未连接真实 Nacos 逐项验证公共 Data ID 与模块 Data ID 的覆盖顺序；需要在 Nacos 中创建或确认 `hdx-database.yml` 后，用 service profile 启动 core/auth 验证。
- `services/backend` 子模块新 commit 尚未推送，根仓库暂不能提交子模块指针；用户明确允许推送后，应先推送子模块，再提交根仓库指针。

## 相关 commit

- `fe98dbb 杂项：增加公共数据库配置入口`（`services/backend`，尚未推送）
