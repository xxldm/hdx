# constants

本目录用于稳定协议常量说明，例如错误码、权限 code、actor type 和跨端状态枚举。

当前不提供可导入代码。新增常量前必须确认消费者、命名规则、是否由后端 OpenAPI 或后端契约生成，以及对应验证方式。

## 错误响应契约

后端公开 REST API 的业务错误响应使用稳定错误码加中文 fallback message：

```json
{
  "code": "AUTH_INVALID_CREDENTIALS",
  "message": "账号或密码错误。"
}
```

- `code` 是跨端稳定协议字段，UI 应优先按 `code` 做本地化文案映射。
- `message` 是中文 fallback 文案，用于兜底展示和排障阅读，不作为 UI 国际化事实源。
- Web BFF 自己的边界错误使用 `code` 表示 BFF 错误类型；透传后端错误码时使用 `upstreamCode` 保存后端原始 `code`。

当前已登记的后端错误码：

| code | 来源 | 语义 |
| --- | --- | --- |
| `AUTH_INVALID_CREDENTIALS` | `backend-auth-service` | 账号或密码错误，不能泄露账号是否存在。 |
| `AUTH_LOGIN_COOLDOWN` | `backend-auth-service` | 登录失败次数过多，进入冷却窗口。 |
| `AUTH_REFRESH_TOKEN_INVALID` | `backend-auth-service` | refresh token 无效、过期、已消费或会话不可用。 |
| `AUTH_REQUEST_INVALID` | `backend-auth-service` | 认证请求字段语义无效，例如客户端类型不支持。 |
| `AUTH_REVOCATION_UNAVAILABLE` | `backend-auth-service` | 登录会话撤销状态暂时不可写入或不可用。 |
| `REQUEST_BODY_INVALID` | `backend-auth-service` | JSON 请求体无法读取或格式无效。 |
| `VALIDATION_FAILED` | `backend-auth-service`、`backend-core` | 请求参数未通过边界校验。 |
| `CURRENT_ACTOR_UNAVAILABLE` | `backend-core` | 当前请求没有可用登录身份。 |
| `TOOL_DEFINITION_ALREADY_EXISTS` | `backend-core` | 工具定义键已存在。 |

当前剩余缺口：

- `backend-gateway` 的 JWT 撤销过滤器仍使用 Servlet `sendError` 返回中文错误；后续需要单独改为 JSON `ApiErrorResponse`，再登记网关专属错误码。
