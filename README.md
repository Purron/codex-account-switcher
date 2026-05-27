# Codex Account Switcher

一个本地优先的 macOS 菜单栏工具，用来在多个 OpenAI Codex 账号之间快速切换。

它会保存每个账号对应的 Codex CLI 登录态和 Codex Desktop 应用状态，切换时自动退出 Codex、恢复目标账号状态并重新打开 Codex。适合同时使用个人账号、工作账号或不同团队账号的场景。

## 功能特性

- 菜单栏快速切换 Codex 账号
- 捕获当前 Codex 登录态为一个本地 profile
- 自动保存当前 profile 的最新 Codex 状态
- 切换时恢复 `~/.codex/auth.json`
- 切换时恢复 `~/Library/Application Support/Codex`
- 支持展示 CodexBar 记录的 5 小时和 1 周额度剩余百分比
- 所有 profile 数据都保存在本机，不上传到任何服务

## 项目结构

```text
.
├── CodexAccountSwitcher.swift     # macOS 菜单栏 App 源码
├── codex-account-switcher.sh      # 账号捕获和切换脚本
├── build-app.sh                   # 本地构建脚本
├── resources/                     # App 图标和 Info.plist
└── README.md
```

## 系统要求

- macOS
- 已安装 OpenAI Codex Desktop App
- 已安装 Codex CLI，并至少登录过一个账号
- Swift 编译器，通常随 Xcode Command Line Tools 提供

额度展示是可选能力。如果你安装并使用了 CodexBar，本工具会读取它的历史文件：

```text
~/Library/Application Support/com.steipete.codexbar/history/codex.json
```

没有该文件时，账号切换仍然可用，额度位置会显示 `--`。

## 快速开始

先登录第一个 Codex 账号，然后在项目目录执行：

```bash
./codex-account-switcher.sh capture personal
```

再用你的常规方式退出当前 Codex 账号并登录第二个账号，然后执行：

```bash
./codex-account-switcher.sh capture work
```

之后就可以在两个账号之间切换：

```bash
./codex-account-switcher.sh switch personal
./codex-account-switcher.sh switch work
```

查看已保存 profile：

```bash
./codex-account-switcher.sh list
```

查看当前记录的 active profile：

```bash
./codex-account-switcher.sh active
```

## 构建菜单栏 App

```bash
chmod +x build-app.sh codex-account-switcher.sh
./build-app.sh
open "build/Codex Account Switcher.app"
```

打开后，菜单栏会显示状态图标和当前账号的 5 小时额度剩余百分比，例如 `52%`。点击菜单栏图标可以：

- 切换到已保存的 profile
- 捕获当前 Codex 账号为新 profile
- 刷新额度展示
- 打开 profile 数据目录
- 打开 Codex

每个 profile 的子菜单会展示：

- 5 小时剩余百分比、刷新时间、最近更新时间
- 1 周剩余百分比、刷新时间、最近更新时间

## 数据保存位置

profile 默认保存在：

```text
~/Library/Application Support/CodexAccountSwitcher
```

每个 profile 内部结构如下：

```text
profiles/<name>/auth/auth.json
profiles/<name>/app-support/Codex
profiles/<name>/profile.env
```

## 安全说明

这个工具只在本机复制 Codex 的登录态文件和桌面端应用状态，不会读取、打印或上传 token 内容。

需要注意的是，`~/Library/Application Support/Codex` 可能包含 Cookie、Local Storage、窗口状态等桌面端状态。请只在你信任的本机环境中使用，不要把 profile 数据目录提交到 GitHub 或发送给别人。

切换已经打开的 Codex Desktop 时，必须退出并重启 Codex。Electron/Chromium 登录态不会在运行中热更新，所以本工具会在捕获和切换前主动退出 Codex。

## 脚本命令

```text
codex-account-switcher.sh capture <profile>
codex-account-switcher.sh switch <profile> [--no-open]
codex-account-switcher.sh list [--plain]
codex-account-switcher.sh active
codex-account-switcher.sh open-folder
```

支持的环境变量：

```text
SWITCHER_HOME       Profile 存储目录
CODEX_AUTH_FILE     Codex CLI auth 文件，默认 ~/.codex/auth.json
CODEX_APP_SUPPORT   Codex Desktop 状态目录，默认 ~/Library/Application Support/Codex
CODEX_APP_NAME      macOS App 名称，默认 Codex
```

## 重新捕获旧 profile

如果你用旧版本捕获过 profile，建议重新登录每个账号后用同名 profile 捕获一次：

```bash
./codex-account-switcher.sh capture personal
./codex-account-switcher.sh capture work
```

这样可以确保 `auth.json` 和 Codex Desktop 状态都是最新格式。
