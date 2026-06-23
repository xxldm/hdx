# 后端数据访问准入规则

本文档记录后端业务数据访问的默认路径。修改后端 Entity、Repository、Service 持久化逻辑、migration 或冲突处理时先读本文档；认证安全底层和第三方官方 schema 的例外仍以对应 ADR 或数据模型文档为准。

Codex 开工入口在 `.codex/skills/hdx-backend-data-access/SKILL.md`，最小示例在 `.codex/skills/hdx-backend-data-access/references/examples.md`。技能只负责路由和执行清单，长期规则以本文档为事实源。

## 默认路径

- 普通 HDX 自建业务数据默认使用 JPA Entity + Spring Data Repository。
- 可变业务记录默认使用 JPA `@Version` 做乐观锁，不手动维护 `version = version + 1`。
- 查询优先使用 Spring Data 派生查询、`@EntityGraph`、JPA projection 或规范化的 Repository 方法。
- 普通读取软删除表时必须过滤 `deleted=false` 或 `deleted_at is null`，具体字段遵循所属数据模型。
- 业务冲突默认用稳定错误码和结构化响应表达；如果 UI 需要当前服务器状态，服务层可以先比较请求基础版本和实体当前版本，再返回当前实体投影。
- schema 版本和记录版本必须分开命名。协议或布局格式版本使用 `schemaVersion`、`layoutSchemaVersion` 等名称；记录并发版本使用 `version` 或实体内清晰的版本字段。

## 允许例外

以下情况可以偏离默认路径，但需要在代码、测试或相关文档中能看出理由：

- `@Query` / JPQL：复杂 projection、fetch join、批量更新、派生查询无法清楚表达的条件，或为了避免 N+1。
- `@Modifying`：批量状态更新、初始化脚本式幂等 upsert、审计或安全流程中需要一次性更新多行。
- JDBC / `JdbcClient` / `JdbcTemplate` / `JdbcOperations`：第三方官方 schema、Spring Authorization Server 协议表、安全流程 CAS 更新、token 轮换、底层启动迁移验证、测试夹具或明确性能热点。
- 原生 SQL：JPA 无法表达的数据库特性、经过验证的性能路径、migration 验证或框架官方 schema 适配。
- 悲观锁：确实需要串行化访问同一资源，且乐观锁冲突重试或 `@Version` 无法满足语义。
- 不加 `@Version`：追加型日志、审计、事件、outbox、纯从属明细表、只读参考表、第三方官方表或安全基础设施表。

## 实现前检查

动后端持久化代码前，先问这几件事：

1. 这张表是不是 HDX 自建、用户可感知、可修改、可删除或可同步的业务表？
2. 如果是，它有没有 `@Version` 或等价记录版本？如果没有，例外理由写在哪里？
3. 它是否需要软删除？普通查询是否过滤了未删除记录？
4. Repository 能否用派生查询、projection 或 `@EntityGraph` 表达？如果用了 `@Query`，为什么？
5. 是否引入了 JDBC 或原生 SQL？这是官方 schema、安全流程、CAS/批量、性能热点还是测试夹具？
6. 冲突响应是否使用稳定 `code`，并携带 UI 处理所需的当前服务器状态或摘要？
7. 对应测试是否覆盖成功保存、版本冲突、软删除过滤和唯一约束兜底路径？

## 验证入口

后端验证会运行 `scripts/check-backend-data-access.ps1 -ChangedOnly`，它只提醒变更文件里的偏离默认路径项，不直接失败。出现提醒时，智能体必须回到本文档判断是否合理；不能把提醒当作无关输出跳过。

需要全量扫描时运行：

```powershell
pwsh -NoLogo -NoProfile -File scripts/check-backend-data-access.ps1
```

需要把提醒升级成失败时运行：

```powershell
pwsh -NoLogo -NoProfile -File scripts/check-backend-data-access.ps1 -FailOnFindings
```
