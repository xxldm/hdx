# Desktop Linux 一期纳入

- 外部任务系统：无
- 外部任务链接/编号：不适用
- 外部任务是否为主计划来源：否
- 当前状态：已完成并归档
- 计划来源：用户要求 Desktop 给 Linux 也加入一期，与 Windows 并列
- 创建时间：2026-06-08
- 最后更新：2026-06-08

## 目标

将 Desktop 第一阶段平台范围从 “Windows first” 修订为 “Windows + Linux 并列一阶段”，并同步 ADR、架构、README、总纲和已归档计划中的当前事实。

## 非目标

- 本轮不创建 Linux CI、Linux 安装包、Linux 打包脚本或 Linux 桌面环境适配代码。
- 本轮不实现自启动、通知、deep link、托盘、配置目录、导入导出等真实 Linux 平台能力。
- 本轮不为 Linux 提供 wallpaper mode；该能力仍是 Windows-only。
- 本轮不决定 macOS 是否进入第一阶段。

## repo 内范围

- `docs/adr/0008-desktop-tauri-windows-linux-flavors.md`
- `docs/ARCHITECTURE.md`
- `apps/desktop/README.md`
- `docs/plans/active/2026-06-05-hdx-follow-up-roadmap.md`
- `docs/plans/completed/2026-06-08-desktop-integration-design.md`
- `docs/plans/completed/2026-06-08-desktop-tauri-skeleton.md`
- `docs/plans/completed/2026-06-08-desktop-rust-verification.md`
- `docs/plans/active/2026-06-08-desktop-linux-first-phase.md`

## 本地任务清单

- [x] 读取约束、架构、质量、Git、ADR 和计划规则。
- [x] 复核 Desktop ADR、README、总纲、已归档计划和 Rust 平台代码。
- [x] 修订 Desktop ADR，将 Linux 纳入第一阶段并更新回滚条件。
- [x] 更新架构、README、总纲和已归档计划中的平台范围。
- [x] 运行 Desktop 与 docs 验证。
- [x] 归档本计划并提交推送。

## 验收标准

- Desktop 第一阶段文档统一表达为 Windows + Linux 并列。
- Local/Online flavor 和一套代码约束不变。
- Windows-only wallpaper mode 仍明确只面向 Windows，不要求 Linux 等价能力。
- Linux 真实打包、安装器和平台能力仍记录为后续待验证事项，不被误写成已实现。

## 验证方式

- `rg -n "Windows first|首版 Windows|Windows only|0008-desktop-tauri-windows-flavors" docs apps/desktop README.md`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope desktop`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`
- `git diff --check`

## 过程记录

- 当前验证环境是 Windows，只能验证 Rust/Tauri skeleton 在 Windows 下继续通过；Linux 真实编译、WebKitGTK 依赖、打包产物、桌面文件集成、AppImage/Deb/RPM 等需要后续在 Linux 环境验证。
- 通用能力虽然进入 Windows + Linux 一期，但具体插件兼容性和桌面环境差异仍需逐项 spike。

## 状态记录

- 2026-06-08：创建计划，当前状态为“实施中”。
- 2026-06-08：已修订 ADR 0008、架构、约束、根 README、Desktop README、总纲和相关已归档计划；Desktop 第一阶段当前事实统一为 Windows + Linux 并列。
- 2026-06-08：Windows-only wallpaper mode 边界保持不变，Linux 第一阶段只覆盖通用 desktop capability 和 Local/Online flavor，不要求 Linux 等价 wallpaper mode。
- 2026-06-08：Desktop 与 docs 质量门禁均已通过；当前状态改为“已完成并归档”。

## 验证结果

- 已执行 `rg -n "0008-desktop-tauri-windows-flavors|Windows first|首版 Windows|Windows only|首版可以 Windows only|Windows 首版|后续可以补 macOS/Linux|Linux 实现空间" docs apps/desktop README.md`：未发现当前事实文档仍引用旧 ADR 文件名或把 Desktop 首版描述为 Windows only；命中项均为历史计划记录或本计划验证命令。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope desktop`：通过，覆盖 Desktop 静态骨架检查、Desktop 子仓库空白检查、TypeScript typecheck、Local flavor `cargo check` 和 Online flavor `cargo check`。
- 已执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/quality-gate.ps1 -Scope docs -NoBuild`：通过，覆盖文档 UTF-8、根仓库空白检查、OpenAPI 契约检查、OpenAPI TypeScript 类型生成检查和 Web 类型对齐检查。

## 归档备注

- 当前环境是 Windows，Linux 真实编译、WebKitGTK 依赖、打包产物、桌面文件集成、AppImage/Deb/RPM 等仍需后续在 Linux 环境验证。
- 自启动、通知、deep link、托盘、配置目录和导入导出的 Windows/Linux 插件兼容性与桌面环境差异仍需逐项 spike。
- Windows-only wallpaper mode 仍未做 Win32 spike；该能力不要求 Linux 等价实现。

## 相关 commit

- 本计划提交由 Git 历史体现，不在同一提交中回写自身 hash，避免递归提交。
