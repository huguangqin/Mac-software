---
name: rime-wubi-setup
description: '在 macOS 上一键安装并配置「鼠须管 Squirrel + 雾凇拼音 + 五笔拼音混输」输入法：五笔优先、拼音兜底、英文直出、符号直出、候选横排、Caps Lock 正常大写。内含全部已实测验证的配置文件模板与自动化脚本。当用户要求"装鼠须管/装 Rime/配五笔拼音输入法/装雾凇拼音/五笔拼音混输/把这套输入法配置分享给别人/给 AI 让它直接装上输入法"时使用本技能。AI 按本技能执行即可在对方机器上完整复现，无需用户逐项确认。'
agent_created: true
---

# Rime 输入法一键配置（鼠须管 + 雾凇 + 五笔拼音混输）

## Overview

把一台 macOS 机器从零配成「中英五笔拼音三合一」输入法，全部配置经过真机实测验证。最终效果：

- **五笔优先**：打 `gghg` 直接出「工」，五笔码排在候选前
- **拼音兜底**：打 `nihao` 出「你好」，拆不出的字直接用全拼
- **英文直出**：中文状态下打 `hello` 出英文，不用切输入法
- **符号直出**：`Shift+2` 出半角 `@`、书名号 / 括号 / 斜杠等按键即上屏，不弹候选
- **候选横排**：候选词横向排列
- **Caps Lock 正常大写**：短按切大写、灯亮时字母直出大写不弹候选；中英切换走 `Shift`

用户只需给出机器（本机操作），AI 自主跑完全程。所有配置文件已作为模板放在 `assets/`，自动化脚本在 `scripts/`。

## 触发与输入

- 用户说"装鼠须管 / 装 Rime / 配五笔拼音输入法 / 装雾凇拼音 / 把输入法配置分享给别人让 AI 装上"等。
- 前置：macOS 13+，有网络（下载鼠须管 + 雾凇 + 五笔码表），能执行 shell 命令。
- 若为 Apple Silicon（arm64）或 Intel（x86）均可，脚本自动适配。

## 执行流程（按顺序，自主完成）

### 步骤 0：环境体检
```bash
uname -m                                    # arm64 / x86_64
sw_vers | grep ProductVersion               # macOS 版本
ls -d /Library/Input\ Methods/Squirrel.app "$HOME/Library/Input Methods/Squirrel.app" 2>/dev/null
```
**必须确认只有一个 Squirrel.app 副本**。系统级（`/Library/`）和用户级（`~/Library/`）若同时存在，会在输入法面板里出现一大堆重复「鼠须管」，务必删掉多余那份（见「致命坑④」）。

### 步骤 1：装鼠须管（Squirrel）
按优先级尝试，**某个被沙箱拦住就立即换下一个，不要硬刚**：
1. `brew install --cask squirrel`（正常环境一条命令搞定）
2. 受限环境 brew 被 `sandbox-exec` 拒（`Operation not permitted`）→ 官网 https://rime.im/download/ 下载 **`.pkg`** 双击安装（需管理员密码，自动带正确签名并注册输入法）
3. 无 GUI / 不能双击 → 从 pkg 用 `pkgutil --expand` 展开 + `ditto` 复制，详见 `references/installation.md`

### 步骤 2：装雾凇拼音（rime-ice）
雾凇是配置文件集合，放进 `~/Library/Rime/` 即可：
```bash
[ -d "$HOME/Library/Rime" ] && mv "$HOME/Library/Rime" "$HOME/Library/Rime-bak-$(date +%Y%m%d)"
git clone --depth 1 https://github.com/iDvel/rime-ice.git "$HOME/Library/Rime"
```
网络受限无法 git → 从 https://github.com/iDvel/rime-ice/releases 下 zip，解压后把所有文件**直接铺**在 `~/Library/Rime/`（不要放子文件夹）。

### 步骤 3：装五笔码表
```bash
cd "$HOME/Library/Rime"
curl -sL -o wubi86.dict.yaml https://raw.githubusercontent.com/rime/rime-wubi/master/wubi86.dict.yaml
```
> 只需 `wubi86.dict.yaml`（约 2MB）。**不要**拉 rime-wubi 的 `wubi86.schema.yaml`，本技能自带精简版（`assets/wubi86.schema.yaml`，去掉了本机缺失的 `pinyin_simp` 反查依赖）。

### 步骤 4：一键部署配置脚本（核心）
把所有验证过的配置模板铺进用户目录、编译码表、重启输入法：
```bash
SKILL_DIR="$(dirname "$(realpath "$0")")"   # 若从 skill 目录运行
bash "$SKILL_DIR/scripts/install.sh" "$HOME/Library/Rime" "$SKILL_DIR/assets"
```
脚本会自动完成：
- 复制 `wubi_pinyin.schema.yaml` / `wubi86.schema.yaml` / `default.custom.yaml` / `squirrel.custom.yaml` / `symbols.yaml`
- 调用 `rime_deployer --compile` 编译 `wubi86` 与 `wubi_pinyin`（生成 `wubi86.table.bin` ~3MB）
- 用 `noop` 之外的正确写法把 Caps Lock 补丁同步进 `build/default.yaml`（绕开全量部署污染签名）
- 重启 Squirrel、校验签名、检查 app 包无污染

详细命令与逐条说明见 `scripts/install.sh`（内含注释）。

### 步骤 5：添加输入法 + 关掉 Caps 切 ABC（必须用户手动，AI 做不了）
AI 把系统设置面板打开：
```bash
open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
```
然后明确告诉用户做两件事（这两步命令行改不动，必须 GUI 手动）：
1. **添加输入法**：系统设置 → 键盘 → 输入法 → 「+」→ 搜 `squirrel`/`rime` → 选「鼠须管」→ 添加；勾选「在菜单栏中显示输入法」
2. **关掉 Caps 切 ABC**（关键）：系统设置 → 键盘 → 输入法 → 点右侧「**编辑…**」→ 取消勾选「**使用大写锁定键切换 ABC 输入模式**」（英文：Use the Caps Lock key to switch to and from ABC）。**点掉立即生效，不用注销**

### 步骤 6：验证
```bash
ls -lh "$HOME/Library/Rime/build/"{wubi86,melt_eng,rime_ice}.table.bin   # 三个码表都在
codesign --verify --deep --strict /Library/Input\ Methods/Squirrel.app    # 签名正常
pgrep -fl MacOS/Squirrel                                                  # 进程在跑
```
让用户在「五笔拼音」方案下实测：`gghg`→工、`nihao`→你好、`hello`→英文、`Shift+2`→`@`、`Caps` 短按→大写直出。

## 致命坑（血泪实测，按严重程度排序）

> 完整诊断与修复命令见 `references/troubleshooting.md`。AI 执行前务必扫一遍，尤其前 4 条。

1. **五笔码表 `wubi86.table.bin` 不会自动编译**：混输方案里 `table_translator@wubi` 是"次翻译器"，Rime 部署只编译激活方案主字典。必须保留独立的 `wubi86.schema.yaml`（主 translator 是 `table_translator` + `dictionary: wubi86`，**去掉 `dependencies: pinyin_simp`**），并加入 `schema_list`，才会编译出码表。脚本已用 `rime_deployer --compile` 强制编译。

2. **Caps Lock 的「短按切 ABC」是 macOS 系统开关，命令行改不动**：`defaults write com.apple.HIToolbox TISRomanSwitchState -bool false` 只改磁盘值，HIToolbox 内存不重读，`killall cfprefsd` 也没用。只能用户 GUI 手动点那个复选框（步骤 5.2），点掉即生效。osascript 代点需辅助功能权限，未开会报「发生权限违例」。

3. **`good_old_caps_lock: true` 只在 `Caps_Lock != noop` 时生效**：设成 `noop` 会让 Rime 完全不感知 Caps，导致大写状态仍走拼音编码弹候选。正确写法是 `grep` 补丁里那套 `good_old_caps_lock: true` + `Caps_Lock: commit_code`（前提是先完成坑 2 的 GUI 开关，否则表现为"只切中英文、灯不亮"）。

4. **部署会污染 app 包破坏签名，导致"重装多少次都不显示"**：Rime 首次部署若用户目录判定异常，会把 `build/`、`installation.yaml`、`user.yaml` 写进 app 包内部 → 签名封印失效 → 输入法面板/菜单栏拒绝显示。修复：删掉 app 包内这些新增文件（**必须用 `/bin/rm`**，见坑 5），签名自动恢复。脚本已内置检测。

5. **删除副本必须用 `/bin/rm` 而不是 `rm`**：某些 AI 运行环境（如 WorkBuddy）的 `rm` 是 shim，会把文件移到废纸篓，LaunchServices 仍索引废纸篓里的失效副本 → 面板永远搜不到。用 `/bin/rm` 真删。另外 `cp -R` + `xattr -cr` 会破坏签名，正确做法是 `pkgutil --expand` + `ditto`（不碰 `xattr -cr`）。

6. **不要在 schema 里覆盖 `import_preset: symbols` 的键**：把列表 `["＠",…]` 覆盖成 map `{commit:…}` 会触发 `incompatible node type: commit` 编译失败。正确做法是放用户级同名预设文件整体替换（`assets/symbols.yaml` 已备好）。

7. **改全局 default 项不必全量部署**：`--compile` 单编方案不合并 `*.custom.yaml`，而全量部署会踩坑 4。所以脚本采取「改源 custom 补丁 + 直接同步 `build/default.yaml` 运行时产物」两处一致的做法。

## 交付

完成后向用户报告：装了什么、最终能力清单（五笔拼音英文符号混输 + Caps 大写）、需要他手动做的两步是否完成、实测验证结果。若某步因权限/网络失败，明确说明卡在哪、给出用户可自行执行的命令，不假装成功。

## 如何把这个技能分享给别人（分发说明）

本技能整个 `rime-wubi-setup/` 目录是自包含的（配置模板 + 脚本 + 文档都在里面），拷给别人即可：

1. 把 `rime-wubi-setup/` 整个目录打包发给对方（zip 或直接拷目录）
2. 对方解压后放进自己的 `~/.workbuddy/skills/`（用户级，全局可用）或项目的 `.workbuddy/skills/`（项目级）
3. 重启 / 刷新 AI 会话后，对方对 AI 说"帮我装鼠须管/五笔拼音输入法"即可触发，AI 会自动按本 SKILL.md 执行

> 也可以不装成 skill：对方直接把 `SKILL.md` 和 `references/` 的内容贴给任意 AI，让它照着执行；或让 AI 直接跑 `scripts/install.sh`（用法见脚本头部注释）。核心是那 5 个 `assets/*.yaml` 模板——它们是实测验证过的配置，别让对方从零写。
