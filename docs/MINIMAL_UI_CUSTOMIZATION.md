# ZeroOmega 极简 UI 源码改造说明

本文档记录 `minimal-ui` 分支相对上游 `master` 的界面改造，便于后续继续 Vibe coding 或合并。

## 设计规范（Minimal）

| 项目 | 值 |
|------|-----|
| 标题字体 | PP Neue Montreal（500–700），Fontshare CDN |
| 正文字体 | Inter（400–500），Google Fonts |
| 主背景 | `#FFFFFF`（Light）/ `#111111`（Dark） |
| 文字 | `#1A1A1A`（Light）/ `#F5F5F5`（Dark） |
| 强调色 | `#3B82F6`（少量使用） |
| 圆角 | `8px` |
| 阴影 | `0 4px 12px rgba(0,0,0,0.08)` |
| 动画 | 600ms 淡入；hover 仅颜色过渡 |
| 布局 | 留白分隔，无分割线；菜单项不重叠 |

## 架构：三套样式如何协同

```
┌─────────────────────────────────────────────────────────┐
│  扩展弹窗 (popup/index.html)                             │
│  → src/popup/css/index.css（独立 CSS，构建时直接 copy）   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  完整弹窗页 / 设置页 (popup.html, options.html)         │
│  → src/less/popup.less / options.less → build/css/*.css │
│  → @import minimal.less（共享变量与 mixin）             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Light / Dark / Auto 主题（设置 → 主题 → 应用选项）      │
│  → lib/themes/default-*.css（调色板）                   │
│  → lib/themes/variable.css（语义变量映射）                │
│  → lib/themes/base.css（Bootstrap + 布局覆盖）          │
│  注入到 options.html / popup.html 的 style.om-style     │
└─────────────────────────────────────────────────────────┘
```

**重要：** 设置页在切换 Light/Dark 后必须点击「应用选项」保存 `-customCss`，否则刷新后主题丢失。

## 改动文件清单

### 新增

| 文件 | 说明 |
|------|------|
| `omega-web/src/less/minimal.less` | 极简设计 token、mixin（`.minimal-base()`、`.minimal-nav-link()`、`.minimal-stagger()`）、`om-fade-in` 动画 |

### 扩展弹窗（点击图标）

| 文件 | 改动要点 |
|------|----------|
| `omega-web/src/popup/css/index.css` | 重写为极简弹窗样式：白底、平铺菜单（`margin-bottom: 4px`，**无重叠**）、选中态蓝字+浅蓝底、分隔用 `16px` 留白 |
| `omega-web/src/popup/css/dialog.css` | 对话框/权限页统一极简按钮与卡片 |
| `omega-web/src/popup/index.html` | 增加 `ZeroOmega` 标题区 `.om-header`；引入 PP Neue Montreal；去掉 inline 灰色图标样式 |
| `omega-target-chromium-extension/overlay/popup-iframe.html` | iframe 外层改为白底、去圆角渐变（与弹窗一致） |

### Angular 页面（LESS → CSS）

| 文件 | 改动要点 |
|------|----------|
| `omega-web/src/less/popup.less` | `@import minimal.less`；`nav-pills` 平铺导航；表单/下拉用 CSS 变量 fallback |
| `omega-web/src/less/options.less` | 侧边栏/主内容区改用 `var(--defaultBackground)` 等；`64px` 主区内边距；Bootstrap 组件主题感知 |
| `omega-web/src/less/common.less` | `.profile-inline` 改为浅蓝标签样式，支持 CSS 变量 |
| `omega-web/src/popup.jade` | 增加 `.om-header`；字体 CDN preconnect |
| `omega-web/src/options.jade` | 字体 CDN preconnect |

### 内置主题系统（Light / Dark / Auto）

| 文件 | 改动要点 |
|------|----------|
| `omega-web/lib/themes/default-light.css` | 极简 Light 调色板：`#FFFFFF` 页面、`#1A1A1A` 文字、`#3B82F6` 主色；新增 `--surfaceBackground`、`--borderColor`、`--cardShadow` |
| `omega-web/lib/themes/default-dark.css` | 极简 Dark：`#111111` 页面/侧栏、`#1A1A1A` 卡片、`#F5F5F5` 文字；侧栏不再出现白卡片 |
| `omega-web/lib/themes/default-auto.css` | 与 Light/Dark 相同配色，通过 `prefers-color-scheme` 切换 |
| `omega-web/lib/themes/variable.css` | 将 base16 变量映射为语义变量（`--defaultBackground`、`--primaryColor` 等） |
| `omega-web/lib/themes/base.css` | 重写 Bootstrap 覆盖：导航选中态改为蓝字+浅底（非白字蓝底）；`side-nav` / `settings-group` 使用主题变量；popup 菜单同步 |

## 构建与本地预览

```bash
cd omega-build
npm run deps    # 首次
npm run build   # 编译 coffee/jade/less，输出到 omega-target-chromium-extension/build
npm run release # 可选：生成 dist/chromium-release.zip
```

Chrome：`chrome://extensions/` → 开发者模式 → **加载已解压的扩展程序** → 选择：

```
omega-target-chromium-extension/build
```

或打包目录：

```
dist/crx-pack
```

## 后续 Vibe coding 建议

1. **改弹窗菜单**：优先编辑 `omega-web/src/popup/css/index.css`（改完 build 即生效，无需 less）。
2. **改设置页布局**：编辑 `omega-web/src/less/options.less`，改 token 则改 `minimal.less`。
3. **改 Light/Dark 配色**：只改 `lib/themes/default-light.css` 与 `default-dark.css` 的 `:root` 块；`base.css` 一般不用动。
4. **避免回归**：不要给 `.om-nav-item` 加负 `margin`（曾导致 Glass 风格卡片重叠）；主题相关颜色用 CSS 变量，勿在 less 里写死 `#ffffff`。
5. **第三方 base16 主题**：下拉选择其他主题时仍走 `variable.css + 主题文件 + base.css`；极简布局覆盖在 `base.css` 的 `options.css` 段。

## 未纳入版本控制的产物

以下目录/文件为构建输出，已在本地生成但未提交：

- `omega-target-chromium-extension/build/`
- `dist/`（含 `ZeroOmega-3.5.0.crx`、`.pem`）

如需发布 CRX，在 `omega-build` 执行 `npm run release` 后用 Chrome `--pack-extension` 打包。
