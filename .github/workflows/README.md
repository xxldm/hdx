# GitHub Actions workflows

GitHub 只会识别 `.github/workflows/` 直属目录中的 workflow 文件；调试、检查和正式发布 workflow 不能放进子目录。

## 命名约定

- `check-*`：手动验证或环境检查入口。默认不创建 Release，不上传公开产物，除非文件说明中明确写出例外。
- `debug-*`：手动调试、演练或最小闭环入口。可以创建 draft Release 或临时 asset，但不得作为正式公开发布入口。
- `ci.yml`、`release.yml` 等短名称：后续正式 CI 和正式发布入口。正式入口不使用 `check-*` 或 `debug-*` 前缀。

## 当前文件

- `check-release-app-token.yml`：验证 GitHub App token 能否读取后端仓库 workflow run、artifact 等发布所需元数据。
- `check-release-backend-artifact.yml`：验证主仓库能否通过 GitHub App token 下载并校验后端 Actions artifact。
- `debug-release-dry-run.yml`：只做 release dry-run，校验 root ref、子模块指针和 release manifest，不创建 GitHub Release。
- `debug-release-draft-minimal.yml`：从后端 Actions artifact 创建最小 draft Release，用于验证后端 native 交接闭环。
- `debug-release-draft-reuse-backend.yml`：从历史主仓库 Release asset 复用后端 native，创建最小 draft Release。
- `release-start.yml`：正式 tag start 入口第一版。真实 `v*` tag push 会计算 root/backend/OpenAPI 发布上下文，并触发后端私有仓库 release resolver；手动入口默认 dry-run，不触发后端。
- `release.yml`：正式 release assemble 入口第一版。当前接收后端 resolver payload，支持多个后端 native Actions artifact 聚合，支持从同一个历史主仓库 Release 复用多个后端 native asset，创建 draft Release、上传资产并远端回读校验；尚不支持 Web/Desktop/App 真实打包或 publish。

## 调试草稿清理

`debug-*` workflow 产生的测试 draft Release 和临时 asset 验证完成后应删除，并确认对应测试 tag ref 不再存在。真实发布流程的失败清理策略以后由正式 `release.yml` 单独定义。
