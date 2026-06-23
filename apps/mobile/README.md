# App 端

本目录用于未来 App 端实现。第一阶段技术路线已由根仓库 `docs/adr/0009-mobile-native-online-first.md` 记录：

- Android 采用 Kotlin + Jetpack Compose，后续工程位于 `apps/mobile/android/`。
- HarmonyOS NEXT 采用 ArkTS + ArkUI，后续工程位于 `apps/mobile/harmony/`，并面向 PC、平板、手机等多设备形态适配。
- App 不复用 Desktop Tauri shell，不混入 Desktop Online。
- App 首版只做 Online only，连接远端 `backend-auth-service` 与 `backend-gateway`。
- 第二阶段只规划离线缓存和离线草稿，联网后同步提交。
- 不规划移动端 `backend-all-in-one`、本机 HTTP 后端服务或完整离线业务引擎。
- 用户数据持久化、跨设备同步和冲突处理边界见根仓库 `docs/adr/0016-user-data-persistence-and-sync-boundary.md`。
- App 可以在弱网、无网下暂存可同步草稿；重连后通过后端版本、幂等和显式冲突规则提交。

创建 Android 或 HarmonyOS NEXT 工程骨架前，需要单独计划并同步质量门禁入口。
