# 品牌资产

本目录保存 HDX 的端无关品牌源资产。

- `hdx-icon.png`：当前 HDX 产品图标源图，已裁掉右侧和底部透明尾边。

端侧运行时不直接引用其他端目录。Desktop 继续使用 Tauri 需要的 `src-tauri/icons/` 派生图标，Web 使用 `apps/web/app/assets/brand/` 内的本地打包副本。

更新品牌图标时：

1. 先更新本目录源图。
2. 同步 Web 本地副本。
3. 在 `apps/desktop` 中执行 `pnpm tauri icon ..\..\packages\shared\assets\brand\hdx-icon.png`，重新生成 `32x32.png`、`64x64.png`、`128x128.png`、`128x128@2x.png`、`icon.png`、`icon.ico` 和 `icon.icns`。
4. 清理当前 Desktop 配置未引用的 Appx、Android、iOS 额外生成物，除非后续已有对应平台打包入口。
