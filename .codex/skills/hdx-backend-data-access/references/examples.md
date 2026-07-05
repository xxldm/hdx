# 后端数据访问最小示例

这些示例只展示默认写法入口。长期规则以 `docs/BACKEND_DATA_ACCESS.md` 为事实源；涉及用户数据同步和冲突边界时同时读 ADR 0016。

## `@Version` Entity 示例

```java
import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;

@Entity
@Table(name = "user_preference")
public class UserPreference {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Version
    @Column(name = "version", nullable = false)
    private int version;

    @Column(name = "user_id", nullable = false, length = 160)
    private String userId;

    @Column(name = "deleted", nullable = false)
    private boolean deleted;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public int getVersion() {
        return version;
    }
}
```

## 派生查询 + 软删除过滤示例

```java
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface UserPreferenceRepository extends JpaRepository<UserPreference, Long> {
    Optional<UserPreference> findByUserIdAndDeletedFalse(String userId);

    boolean existsByUserIdAndDeletedFalse(String userId);

    Optional<UserPreference> findByUserIdAndDeletedAtIsNull(String userId);
}
```

如果数据模型使用 `deleted_at` 表达软删除，就用 `DeletedAtIsNull`；如果使用 `deleted` 布尔字段，就用 `DeletedFalse`。不要在普通读取里漏掉未删除过滤。

## 业务层比较 `baseVersion` 并返回 409 示例

```java
public UserPreferenceResponse updatePreference(UpdateUserPreferenceRequest request) {
    UserPreference preference = repository.findByUserIdAndDeletedFalse(request.userId())
            .orElseThrow(UserPreferenceNotFoundException::new);

    if (preference.getVersion() != request.baseVersion()) {
        throw new UserPreferenceConflictException(
                request.baseVersion(),
                preference.getVersion(),
                toResponse(preference));
    }

    preference.rename(request.displayName());
    return toResponse(repository.save(preference));
}
```

```java
@ExceptionHandler(UserPreferenceConflictException.class)
ResponseEntity<ConflictResponse<UserPreferenceResponse>> handleConflict(UserPreferenceConflictException ex) {
    ConflictResponse<UserPreferenceResponse> body = new ConflictResponse<>(
            "USER_PREFERENCE_CONFLICT",
            ex.baseVersion(),
            ex.currentVersion(),
            ex.currentValue());

    return ResponseEntity.status(HttpStatus.CONFLICT).body(body);
}
```

JPA 仍负责最终写入时的 `@Version` 乐观锁。服务层提前比较 `baseVersion` 是为了返回更清楚的 409 响应和服务器当前状态。

## 软删除读取测试示例

```java
@Test
void findByUserIdAndDeletedFalseShouldIgnoreDeletedRows() {
    UserPreference active = repository.save(newPreference("user-1"));
    active.markDeleted("user-1", clock.instant());
    repository.saveAndFlush(active);

    assertThat(repository.findByUserIdAndDeletedFalse("user-1")).isEmpty();
}
```

测试夹具可以在必要时使用 `JdbcTemplate` 准备极端数据，但面向业务的 Repository 读取仍应通过软删除过滤方法验证。
