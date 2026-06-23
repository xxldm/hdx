---
name: hdx-backend-data-access
description: "HDX backend data access guardrail for services/backend. Use when adding or changing Java Entity, Spring Data Repository, Flyway migration, JPA query, @Query, native SQL, JdbcTemplate/JdbcClient/JdbcOperations, optimistic locking, @Version, soft delete, persistence conflict handling, or backend user-data storage."
---

# HDX 后端数据访问入口

本技能只做开工入口和执行清单，长期规则以仓库文档为事实源。不要把完整规则复制到这里；规则变化时优先改文档，再同步本入口的路由。

## 开工清单

1. 先读 `docs/BACKEND_DATA_ACCESS.md`，确认当前改动属于默认 JPA 路径还是允许例外。
2. 涉及用户数据、跨端同步、布局、组件配置、模块数据或冲突处理时，再读 `docs/adr/0016-user-data-persistence-and-sync-boundary.md`。
3. 修改现有后端表、migration 或 Repository 前，读 `docs/DATA_PERSISTENCE_AUDIT.md`，确认该表的历史定位和迁移优先级。
4. 需要最小写法时，读 `references/examples.md`；它只提供模板，不替代事实源规则。
5. 完成后至少运行 `pwsh -NoLogo -NoProfile -File scripts/check-backend-data-access.ps1 -ChangedOnly`，再按改动范围运行后端验证。

## 默认倾向

- 普通 HDX 自建业务数据优先使用 JPA Entity + Spring Data Repository。
- 可变业务记录默认使用 `@Version`，避免手写版本递增或手动锁定查询。
- 普通查询优先派生查询、`@EntityGraph` 或 projection。
- 软删除表的普通读取必须过滤未删除记录。
- `@Query`、native SQL、JDBC 和悲观锁只在事实源文档列出的场景中使用，并留下能被后续维护者看懂的理由。

## 示例入口

- `references/examples.md`：`@Version` Entity、派生查询软删除过滤、baseVersion 冲突响应、软删除读取测试。
