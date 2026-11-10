# inputactions-gnome

在 **Fedora + GNOME Wayland** 上使用 InputActions 鼠标笔画手势，并补上 GNOME 缺失的 **实时轨迹 + 动作名 overlay**，附带托盘启停。

> A downstream distribution that adds a GNOME Shell overlay (stroke trail + live action name) and a tray toggle to [InputActions](https://github.com/InputActions). GNOME's Mutter does not implement `wlr-layer-shell`, so the official overlay cannot be shown; this project implements the same D-Bus interface in a small GNOME Shell extension.

## 效果

<img width="1280" height="800" alt="录屏-剪辑" src="https://github.com/user-attachments/assets/b578f41e-4653-4cd0-9a84-672725253c11" />

按住鼠标右键画手势：

- 屏幕上实时绘制青绿色轨迹
- 光标旁实时显示当前匹配到的动作名
- 松手执行动作；动作名再保留 0.8 秒
- 手势停下超过 2 秒自动失效，轨迹和动作名立即消失

## 功能

- 13 个手势：4 个方向 + 4 个斜向 + 5 个折线
- 斜向要求 45°±12°，略斜的水平/垂直不会误触斜向
- 浏览器专用手势（切标签、关/开/恢复标签）按 `$window_class` 只在浏览器内生效
- 托盘：轻量「启用/暂停」、真正启停服务、编辑/重载配置
- 启动器 `InputActions`：一键启动/停止整个用户态服务

## 环境要求

- Fedora 44+（脚本目前只做 Fedora 的依赖安装）
- GNOME 45–51 **Wayland**（在 GNOME 50 验证，51 已兼容）
- 可用的 `sudo`、网络
- 托盘需要 GNOME 的 **AppIndicator and KStatusNotifierItem Support** 扩展（没有也能用 overlay，只是没有托盘图标）

## 一键安装

```bash
git clone https://github.com/sherlocknieh/inputactions-gnome.git
cd inputactions-gnome
./install.sh
```

或者不克隆：

```bash
curl -fsSL https://raw.githubusercontent.com/sherlocknieh/inputactions-gnome/main/bootstrap.sh | bash
```

把 `sherlocknieh` 换成实际仓库地址。

安装完成后**注销并重新登录一次**（GNOME Wayland 下新扩展只能在登录时加载）。登录后 autostart 会自动拉起客户端和托盘。

## 登录后验证

```bash
gnome-extensions info inputactions-overlay@local      # 状态 ACTIVE
busctl --user list | grep org.inputactions.overlay    # 所有者应为 gnome-shell
pgrep -af 'inputactions-client|inputactions-tray'     # 两者都应在运行
```

然后按住右键画一下，应看到轨迹和动作名。

## 手势表

按住**右键**画，未松手就会显示匹配到的动作名，松手执行。

| 笔画 | 动作 | 范围 |
|---|---|---|
| → 右 | 右侧标签页（Ctrl+PageDown） | 浏览器 |
| ← 左 | 左侧标签页（Ctrl+PageUp） | 浏览器 |
| ↑ 上 | 滚动到顶部（Ctrl+Home） | 全局 |
| ↓ 下 | 滚动到底部（Ctrl+End） | 全局 |
| ↗ 右上 | 窗口最大化（Super+Up） | 全局 |
| ↘ 右下 | 粘贴（Super+V） | 全局 |
| ↖ 左上 | 截图（PrintScreen） | 全局 |
| ↙ 左下 | 还原窗口（Super+Down） | 全局 |
| 下 → 右（折线） | 关闭标签页（Ctrl+W） | 全局 |
| 上 → 右（折线） | 新标签页（Ctrl+T） | 浏览器 |
| 左 → 右（折线） | 后退（Alt+Left） | 全局 |
| 右 → 左（折线） | 前进（Alt+Right） | 全局 |
| 左 → 下（折线） | 恢复标签页（Ctrl+Shift+T） | 浏览器 |

浏览器判定用 `$window_class`，当前匹配：`chrome` / `chromium` / `org.mozilla.firefox`（`contains firefox`）/ `Navigator` / `brave` / `edge`。

## 自定义

配置文件：`~/.config/inputactions/config.yaml`

- 改动作：编辑对应 `id` 的 `actions`
- 改动作名：改 `id`
- 加浏览器：在 `conditions.any` 里加 `$window_class == 你的class`
- 当前窗口 class：`inputactions variables list | grep '^window_class'`

改完执行：

```bash
inputactions config reload
```

或者重启客户端（托盘「退出」再点启动器）。

## 工作原理

```
InputActions client (patched)
  ├─ evdev 抓取鼠标 / uinput 虚拟设备
  ├─ 笔画过程中实时匹配，推送动作名
  └─ D-Bus org.inputactions.overlay ──> GNOME Shell 扩展
                                         ├─ 画轨迹（global.stage）
                                         ├─ 显示动作名
                                         └─ 显示期间 disable_unredirect()
```

- 官方 overlay 依赖 `wlr-layer-shell`，GNOME 不实现；扩展在 shell 层接管 `org.inputactions.overlay` 的 `show`/`hide`/`showLabel`/`cancel`。
- 占位 `/usr/local/bin/inputactions-overlay` 只负责满足配置校验，避免官方 overlay 抢占 D-Bus 名字。
- 显示 overlay 时调用 `global.compositor.disable_unredirect()`，避免最大化/全屏窗口的 direct scanout 把轨迹盖掉。

## 本地补丁内容

`patches/client.patch` 固定应用在上游 `standalone d88c74b` / `core 2beab8c`，包含：

- `showLabel` / `cancel` overlay D-Bus 方法
- 笔画过程中每 2 个事件匹配一次，实时推送动作名
- 2 秒手势暂停超时（`GESTURE_PAUSE_TIMEOUT`）
- 斜向角度门限（`Stroke::directionMatches`，默认 45°±18°，由 `overlay.mouse_stroke.direction_tolerance` 配置）
- 轻量 `pause` / `unpause`（不重载配置、不释放设备）

## 与 Input Remapper 共存

InputActions 会独占 grab 物理鼠标/键盘，所以 Input Remapper 里建在**物理设备**上的预设必然失败
（GUI 底部 `Failed to apply preset`，日志 `Cannot grab ... Device or resource busy`）。

两种做法：

1. **推荐：不链式**。单个按键映射直接用 InputActions 的 `mouse.press` 触发器，例如中键 → `SPACE+ENTER`：

   ```yaml
   mouse:
     gestures:
       - type: press
         mouse_buttons: [ middle ]
         instant: true   # 否则默认等 200ms，快速点击会被当成普通中键透传
         actions:
           - input:
               - keyboard: [ SPACE+ENTER ]
   ```

2. **必须保留 Input Remapper 预设时**，把预设建在 `"<设备名> (InputActions output)"` 这张虚拟设备卡上，
   并且 preset 的 `input_combination` 要带该 output 节点的 `origin_hash`，否则 input-remapper 会连带
   抓同组的 `(InputActions internal)` 节点而整体失败。本仓库 `config/config.yaml` 的 `device_rules` 已加
   `- $name contains InputActions`，避免 InputActions 反过来再抓 input-remapper 的转发设备（转发设备沿用源设备名）。

   命令行启动需要 root（非 root 列不到这些虚拟设备）：

   ```bash
   sudo -A input-remapper-control --config-dir ~/.config/input-remapper-2 \
     --command start --device "2.4G Mouse (InputActions output)" --preset middle_button
   ```

## 已知限制

- 脚本目前只支持 Fedora；其他发行版需要自己改依赖和 setgid 流程。
- 补丁固定在上述提交；上游更新后可能需要 rebase `patches/client.patch`。
- GNOME 扩展是本地安装，不在 extensions.gnome.org。
- 托盘依赖 AppIndicator 扩展。
- 上游辅助扩展 `inputactions@inputactions.org` 的 metadata 可能缺少当前 shell 大版本而被判为 OUT OF DATE（表现为 `inputactions variables list` 里 `window_class` 全为 null，浏览器条件手势失效）。`install.sh` 会把它复制到用户目录并注入当前版本，升级 GNOME 后重跑安装即可。
- 安装后必须注销/重新登录一次。
- KDE / Hyprland 请直接用官方 InputActions 的 KWin/Hyprland 插件 + 官方 overlay，不要用本项目。

## 卸载

```bash
./uninstall.sh
```

然后注销/重新登录。

## 目录结构

```
install.sh               # 一键安装（固定提交 + 补丁 + 构建 + 安装）
uninstall.sh
bootstrap.sh             # curl | bash 入口
patches/client.patch     # 客户端补丁
gnome-extension/         # Shell 扩展（loader + impl-v12）
tray/                    # 托盘、服务控制、图标
config/config.yaml       # 默认手势配置
```

## 许可与致谢

- 本项目：GPL-3.0
- [InputActions](https://github.com/InputActions)（GPL-3.0）：手势引擎、安装器
- 笔画识别源自 Strokognition / wstroke / easystroke
