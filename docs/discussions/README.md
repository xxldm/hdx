# 未归档讨论结论

本目录只保存已经讨论确认、但还没有进入计划、ADR、接口草案、代码、测试或对应端 README 的公开结论。

## 写入规则

- 按主题拆小文件，不写大而全的长期产品说明书。
- 只记录当前结论，不记录完整聊天过程、反复取舍流水或一次性验证输出。
- 内容进入正式事实源后，从本目录删除或改成很短的入口。
- 涉及后端内部数据模型、接口草案、通知调度、权限矩阵、治理策略或实现切片时，不写在这里，改写到 `services/backend/docs/`。

## 当前暂存

- `multi-source-client-behavior.md`：多来源显示、默认保存位置、来源状态和通知偏好。
- `account-registration-oauth2-lifecycle.md`：注册配置、OAuth2 首次登录、迁出/注销账号生命周期。
- `offline-queue-conflict-and-reminders.md`：离线暂存、冲突处理、幂等写操作和本地提醒兜底。
