# 鼠须管安装方式详解（三种，按环境选）

## 重要前提

鼠须管是**输入法**，不是普通 App：
- 它装在 `~/Library/Input Methods/`（用户级，免 root）或 `/Library/Input Methods/`（系统级，需 root）
- 不在「应用程序」文件夹里，在 Finder 里默认看不到
- 装完必须在「系统设置 → 键盘 → 输入法」里**手动添加**才会出现在输入法列表
- 首次切换/使用需授权「输入监控」：`系统设置 → 隐私与安全性 → 输入监控`

## 方式 A：Homebrew（正常环境首选）

```bash
brew install --cask squirrel
```
一条命令搞定。但在受限环境（CI / 沙箱 / 公司管控机）`brew cask` 会被 `sandbox-exec` 拒绝，报：
```
Error: Operation not permitted @ rb_sysopen / Sandbox: sandbox_apply: Operation not permitted
```
遇到这个立即换方式 B 或 C，不要反复重试 brew。

## 方式 B：官方 .pkg 双击安装（最省事、最稳）

1. 打开 https://rime.im/download/ → 下载 macOS 版（是 **`.pkg`**）
2. 双击 `.pkg` 按向导安装（需管理员密码）
3. pkg 自动带正确代码签名、自动注册输入法 → 最不容易踩签名的坑

> 实测：系统级 `/Library/Input Methods/Squirrel.app` 由 pkg 安装最稳；用户级在某些枚举时序下要注销重登才出现在面板。

## 方式 C：无 GUI / brew 被卡时，手动从 pkg 提取

关键：**提取和复制都必须保留官方代码签名**，否则 macOS 拒绝注册，输入法面板里根本搜不到「鼠须管」。

```bash
# 1) 拿官方 pkg（brew 缓存的，或官网手动下载的）
PKG=$(ls ~/Library/Caches/Homebrew/downloads/*Squirrel*.pkg 2>/dev/null | head -1)

# 2) pkgutil 正规展开（能正确处理 pbzx 压缩）；不要用 cp 裸抠 Payload
/bin/rm -rf /tmp/sq && pkgutil --expand "$PKG" /tmp/sq
APP=$(find /tmp/sq -name Squirrel.app -type d | head -1)

# 3) ditto 原样复制保留签名。千万【不要】跑 xattr -cr —— 会清掉签名扩展属性
/bin/rm -rf "$HOME/Library/Input Methods/Squirrel.app"
ditto "$APP" "$HOME/Library/Input Methods/Squirrel.app"

# 4) 校验签名有效（无报错即正常）
codesign -v "$HOME/Library/Input Methods/Squirrel.app"
```

## 只能保留一份副本

系统会枚举所有位置的 Squirrel.app，每份注册 3 个模式（主/简/繁）。两份叠加 → 输入法列表出现一大堆重复「鼠须管」。

```bash
# 检查有几份
ls -d /Library/Input\ Methods/Squirrel.app "$HOME/Library/Input Methods/Squirrel.app" 2>/dev/null
# 删掉多余那份（用 /bin/rm！见 troubleshooting.md 坑 5）
sudo /bin/rm -rf /Library/Input\ Methods/Squirrel.app          # 若要删系统级
/bin/rm -rf "$HOME/Library/Input Methods/Squirrel.app"         # 若要删用户级
# 注销 LaunchServices 旧记录并重注册
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u <被删路径>
# 验证：lsregister -dump | grep Squirrel 的 path: 不能指向 .Trash/
```

## 添加到输入源（三种装法都要做）

- `系统设置 → 键盘 → 输入法` → 左下角「+」→ 搜 `squirrel` 或 `rime` → 选「鼠须管」→ 添加
- 若面板里看不到：先整个关掉「系统设置」重开刷新缓存；仍不出现说明签名无效（重走方式 C 的 ditto 步骤，或查 troubleshooting.md 坑 4 的 app 包污染）
- 建议勾选「在菜单栏中显示输入法」

## 验证是否真的装好

别只看 `TISCreateInputSourceList`——查到 `im.rime.inputmethod.Squirrel` 只说明 TIS 知道这个 bundle，不代表已加入「添加输入法」面板。硬证据：
```bash
# LaunchServices 索引指向正确位置（不能是 .Trash/）
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump | grep -A2 Squirrel | grep path:
# HIToolbox 已启用的输入源含 rime
defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleEnabledInputSources | grep -i rime
```
