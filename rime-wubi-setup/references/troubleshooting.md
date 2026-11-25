# 致命坑与修复手册（全部真机实测）

按严重程度排序。AI 执行安装前务必扫一遍，遇到对应症状直接照做，不要重新试错。

---

## 坑 1：五笔码表 `wubi86.table.bin` 不会自动编译（五笔完全没候选）

**症状**：拼音能用，五笔打 `gghg` 没反应 / 只有单字。

**根因**：混输方案里 `table_translator@wubi` 引用 `wubi86` 属于「次翻译器」，Rime 部署时只编译激活方案的主 translator 字典，不会编译次翻译器的码表。

**修复**：
1. 保留独立的 `wubi86.schema.yaml`（主 translator 就是 `table_translator` + `dictionary: wubi86`），**去掉 `dependencies: pinyin_simp` 和 reverse_lookup 反查**（缺 pinyin_simp 字典会报错）。模板已在 `assets/wubi86.schema.yaml`。
2. 把它加入 `default.custom.yaml` 的 `schema_list`（脚本已做）。
3. 命令行强制编译：
```bash
DEP="/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
U="$HOME/Library/Rime"; SS="/Library/Input Methods/Squirrel.app/Contents/SharedSupport"
"$DEP" --compile "$U/wubi86.schema.yaml" "$U" "$SS" "$U/build"
"$DEP" --compile "$U/wubi_pinyin.schema.yaml" "$U" "$SS" "$U/build"
killall Squirrel
```
**验证**：`ls -lh ~/Library/Rime/build/wubi86.table.bin` 存在且约 3MB。不存在则五笔必定失效。

> 如果 Squirrel 装在用户级，`DEP` 路径改为 `$HOME/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer`。

---

## 坑 2：Caps Lock 短按只切中英文、不切大写（图标变大写 A）

**症状**：短按 Caps → 菜单栏输入法图标变成大写 A（其实是切到 ABC 输入法），灯不亮、打字小写；长按才大写。

**根因**：macOS 10.12+ 内置「短按 Caps Lock = 切换 ABC 输入源」机制。`defaults write com.apple.HIToolbox TISRomanSwitchState -bool false` 只改磁盘值，HIToolbox 在登录时已把旧值读进内存，运行中写 defaults 不重读，`killall cfprefsd` 也不解决。`AppleCapsLockPressAndHoldToggleOff` 更会被 HIToolbox 回写覆盖（写完变 1，过会儿又回 0）。

**修复（唯一立即生效的办法，必须用户 GUI 手动）**：
```
系统设置 → 键盘 → 输入法 → 点右侧「编辑…」→ 取消勾选「使用大写锁定键切换 ABC 输入模式」
（英文界面：Text Input → Edit… → Use the Caps Lock key to switch to and from ABC）
```
点掉对勾**立即生效，不用注销**。

- osascript 代点此复选框需「辅助功能」权限，未开会报「发生权限违例（Not authorized to send Apple events to System Events）」，只能让用户手动。
- AI 能做的是把面板打开：`open "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"`，然后给用户精确的点击路径（可配一张流程图）。

---

## 坑 3：大写锁定灯亮时，字母弹候选而不是直出大写

**症状**：Caps 灯亮、能打大写，但每个字母都进 Rime 编码弹候选，不直接上屏。

**根因**：`ascii_composer/good_old_caps_lock: true` **只有在 `Caps_Lock != noop` 时才生效**（Rime 作者 lotem 官方说明）。若设成 `noop`，Rime 完全不感知 Caps，大写状态仍当拼音处理。

**修复**（`default.custom.yaml` + 同步 `build/default.yaml`）：
```yaml
patch:
  ascii_composer/good_old_caps_lock: true
  ascii_composer/switch_key/Caps_Lock: commit_code
```
`commit_code` = 按 Caps 提交当前编码 + 切西文模式 + 开启大写锁定。
**前提是先完成坑 2 的 GUI 开关**，否则 `commit_code` 会表现为"只切中英文、灯不亮"。
中英切换仍走 `Shift_L: commit_code`，与 Caps 大写互不冲突。

**备用方案**（若这台机器上 `commit_code` 仍不干净）：不改 Caps 键，改用 recognizer 让大写字母串直出：
```yaml
recognizer:
  patterns:
    uppercase: '[A-Z]+'   # 配 key_binder 把 uppercase 段直接 commit
```
不到万不得已不用，先用 commit_code。

---

## 坑 4：部署污染 app 包破坏签名 →「重装多少次都不显示」

**症状**：明明装好了、TIS 里也有 3 个 rime 源、`enabled/selectCapable=true`，但输入法面板搜不到、菜单栏不显示，反复重装无效。

**根因**：Rime 首次部署若用户数据目录判定异常，会把编译产物（`Contents/SharedSupport/build/`、`installation.yaml`、`user.yaml`，约 28 个文件）写进 **app 包内部**。官方签名按「干净包 55 个文件」封印，多出文件 → `codesign -v` 报 `a sealed resource is missing or invalid` → 系统拒绝显示。

**诊断**：
```bash
APP="/Library/Input Methods/Squirrel.app"   # 或用户级路径
codesign -v "$APP"                          # 报 sealed resource 无效
ls "$APP/Contents/SharedSupport/" | grep -E 'build|installation'   # 看到这些文件时间戳=部署那一刻
plutil -p "$APP/Contents/_CodeSignature/CodeResources" | grep installation  # 无输出=签名后新增
```

**修复**（app 在 `/Library/` 需提权，用 osascript 弹密码框；**必须用 `/bin/rm` 不能用 `rm` shim**）：
```bash
osascript -e 'do shell script "/bin/rm -rf \"/Library/Input Methods/Squirrel.app/Contents/SharedSupport/build\"; /bin/rm -f \"/Library/Input Methods/Squirrel.app/Contents/SharedSupport/installation.yaml\"; /bin/rm -f \"/Library/Input Methods/Squirrel.app/Contents/SharedSupport/user.yaml\"" with administrator privileges'
codesign -v "/Library/Input Methods/Squirrel.app"   # 无报错即签名自恢复（文件数回到 55）
```
删掉后签名**自动恢复有效**（无需重签名），重启 cfprefsd / TextInputMenuAgent 让系统重扫：
```bash
killall cfprefsd; killall TextInputMenuAgent
```
**根治**：确认 `~/Library/Rime/installation.yaml` 的用户目录指向 `~/Library/Rime/` 而非 app 包，避免部署再写回 app 内。

---

## 坑 5：删除副本 / 复制文件用错命令

**5a. `rm` 被 shim 重定向到废纸篓**（WorkBuddy 等环境）：
普通 `rm -rf` 只把 Squirrel.app 移到 `~/.Trash/`，LaunchServices 仍索引废纸篓里的失效副本 → 面板永远搜不到。
用 `/bin/rm` 真删 + `lsregister -u <旧路径>` 注销 + `lsregister -R <当前路径>` 重注册。
验证：`lsregister -dump | grep Squirrel` 的 `path:` 必须指向正确位置，绝不能是 `.Trash/`。

**5b. `cp -R` + `xattr -cr` 破坏代码签名**：
从 pkg 提取 app 时这样拷会清掉签名扩展属性，系统直接不识别输入法。
正确做法：`pkgutil --expand` 展开 → `ditto` 原样复制（**不碰 `xattr -cr`**）。

**5c. 多份副本叠加**：`/Library/` 和 `~/Library/` 只能有一个 Squirrel.app，否则输入法列表一堆重复项。见 installation.md。

---

## 坑 6：符号覆盖触发 Rime 类型冲突

**症状**：方案编译失败，报 `incompatible node type: commit`。

**根因**：在 schema 里对 `import_preset: symbols` 的键做覆盖，Rime 编译期合并要求类型一致，把列表 `["＠", "☯"]` 覆盖成 map `{commit: '@'}` 类型冲突。

**修复**：放一份用户级同名预设文件 `~/Library/Rime/symbols.yaml` 整体替换（用户目录优先级高于系统 `/Library/Input Methods/Squirrel.app/Contents/SharedSupport/`），无合并冲突。模板已在 `assets/symbols.yaml`：full_shape / half_shape 两段所有符号已改为 `{commit: '原字符'}` 直接上屏。

---

## 坑 7：改全局 default 项不必全量部署

`rime_deployer --compile` 单编方案不合并 `*.custom.yaml`，而全量部署会踩坑 4 污染签名。

**做法**：改源 `default.custom.yaml` 补丁 + 直接同步 `build/default.yaml` 运行时产物，两处保持一致，然后 `killall Squirrel` 重载。脚本已内置。

---

## 坑 8：键盘重复延迟被拉到极端值（短按被判误触）

**症状**：Caps 短按完全没反应，只有长按生效（这个和坑 2 不同：坑 2 是切输入法，这个是系统把短按当误触丢弃）。

**诊断**：
```bash
defaults read -g KeyRepeat          # 正常 2~6，极端值如 90
defaults read -g InitialKeyRepeat   # 正常 15~25，极端值如 94
```
**修复**：
```bash
defaults write -g KeyRepeat -int 6
defaults write -g InitialKeyRepeat -int 15
killall cfprefsd
```
等价于「系统设置 → 键盘 → 按键重复速度/延迟」两个滑块从最慢拖回正常。

---

## 通用验证清单

```bash
U="$HOME/Library/Rime"
# 1. 三个码表都在
ls -lh "$U/build/"{wubi86,melt_eng,rime_ice}.table.bin
# 2. 签名正常、包内无污染
codesign --verify --deep --strict "/Library/Input Methods/Squirrel.app"
ls -la "/Library/Input Methods/Squirrel.app/Contents/" | grep -iE 'installation|user.yaml|build'   # 应为空
# 3. 进程在跑
pgrep -fl MacOS/Squirrel
# 4. 配置一致性
grep -n 'Caps_Lock\|good_old' "$U/default.custom.yaml" "$U/build/default.yaml"
```
用户实测：`gghg`→工（五笔）、`nihao`→你好（拼音）、`hello`→英文、`Shift+2`→`@`、`Caps` 短按→大写直出、候选横排。
