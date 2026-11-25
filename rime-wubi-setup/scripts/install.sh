#!/bin/bash
# Rime 输入法一键配置脚本（鼠须管 + 雾凇 + 五笔拼音混输）
# 用法: bash install.sh <RIME_USER_DIR> <ASSETS_DIR>
#   RIME_USER_DIR  通常为 $HOME/Library/Rime
#   ASSETS_DIR     skill 的 assets 目录（含 5 个已验证配置模板）
# 依据 troubleshooting.md 的坑 1/3/4/5/7 编写。

set -e

RIME_DIR="${1:-$HOME/Library/Rime}"
ASSETS="${2:-$(cd "$(dirname "$0")/../assets" && pwd)}"

echo "== Rime 一键配置 =="
echo "用户目录: $RIME_DIR"
echo "模板目录: $ASSETS"
echo

# ---------- 0. 前置校验 ----------
if [ ! -d "$RIME_DIR" ]; then
  echo "✗ 用户目录不存在: $RIME_DIR"
  echo "  请先执行步骤 2 安装雾凇: git clone --depth 1 https://github.com/iDvel/rime-ice.git $RIME_DIR"
  exit 1
fi
# 找 rime_deployer（系统级优先，其次用户级）
if [ -x "/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer" ]; then
  DEP="/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
  APP="/Library/Input Methods/Squirrel.app"
elif [ -x "$HOME/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer" ]; then
  DEP="$HOME/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
  APP="$HOME/Library/Input Methods/Squirrel.app"
else
  echo "✗ 找不到 rime_deployer，请先安装鼠须管（步骤 1）"
  exit 1
fi
SS="$(dirname "$DEP")/../SharedSupport"
echo "deployer: $DEP"
echo "shared:   $SS"

# ---------- 1. 确认五笔词库存在 ----------
if [ ! -f "$RIME_DIR/wubi86.dict.yaml" ]; then
  echo "→ 下载五笔86词库..."
  curl -sL -o "$RIME_DIR/wubi86.dict.yaml" \
    https://raw.githubusercontent.com/rime/rime-wubi/master/wubi86.dict.yaml
fi
ls -lh "$RIME_DIR/wubi86.dict.yaml" | awk '{print "  词库:", $5, $NF}'

# ---------- 2. 铺配置模板 ----------
echo "→ 写入配置模板..."
for f in wubi_pinyin.schema.yaml wubi86.schema.yaml default.custom.yaml \
         squirrel.custom.yaml symbols.yaml; do
  [ -f "$ASSETS/$f" ] || { echo "✗ 缺模板: $ASSETS/$f"; exit 1; }
  cp "$ASSETS/$f" "$RIME_DIR/$f"
  echo "  ✓ $f"
done

# ---------- 3. 触发全量部署，生成 build/default.yaml（坑 7）----------
# Squirrel --reload = 菜单「重新部署」，会合并 default.custom.yaml 并生成 build/default.yaml
# 若用户尚未添加输入法，--reload 可能不生效，属正常；尝一次即可，不阻塞
echo "→ 全量部署（生成 build/default.yaml）..."
SQUIRREL="$(dirname "$DEP")/Squirrel"
"$SQUIRREL" --reload 2>/dev/null && sleep 2 || true

# ---------- 3b. 同步 Caps Lock 补丁到 build/default.yaml（坑 3/7）----------
# 全量部署会把 default.custom.yaml 合并进去（已是 commit_code），这里二次确保一致
mkdir -p "$RIME_DIR/build"
if [ -f "$RIME_DIR/build/default.yaml" ]; then
  python3 - "$RIME_DIR/build/default.yaml" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p, encoding='utf-8').read()
t = re.sub(r'^(\s*good_old_caps_lock:).*$', r'\1 true', t, flags=re.M)
t = re.sub(r'^(\s*Caps_Lock:).*$', r'\1 commit_code', t, flags=re.M)
open(p, 'w', encoding='utf-8').write(t)
print("  ✓ build/default.yaml Caps 补丁已同步 (commit_code)")
PY
else
  echo "  ! build/default.yaml 尚未生成（用户添加输入法并首次部署后会出现，届时 default.custom.yaml 的 Caps 补丁会自动合并）"
fi

# ---------- 4. 强制编译三个码表（坑 1）----------
echo "→ 编译码表..."
compile() {
  local schema="$1" label="$2"
  echo "  编译 $label ..."
  "$DEP" --compile "$RIME_DIR/$schema" "$RIME_DIR" "$SS" "$RIME_DIR/build" 2>&1 | sed 's/^/    /'
  local rc=${PIPESTATUS[0]}
  [ "$rc" -eq 0 ] && echo "  ✓ $label 编译成功" || echo "  ✗ $label 编译失败 (exit=$rc)"
}
compile "wubi86.schema.yaml"        "五笔码表"
# melt_eng 也是次翻译器：需单独编译它的 schema 才会生成 melt_eng.table.bin（否则英文混输失效）
if [ -f "$RIME_DIR/melt_eng.schema.yaml" ]; then
  compile "melt_eng.schema.yaml" "英文词库"
else
  echo "  ! 缺 melt_eng.schema.yaml（雾凇应自带），英文混输可能失效"
fi
compile "wubi_pinyin.schema.yaml"   "混输方案"

# ---------- 5. 验证码表产物 ----------
echo "→ 验证产物..."
ok=1
for bin in wubi86.table.bin melt_eng.table.bin rime_ice.table.bin; do
  if [ -f "$RIME_DIR/build/$bin" ]; then
    ls -lh "$RIME_DIR/build/$bin" | awk '{print "  ✓", $5, $NF}'
  else
    echo "  ✗ 缺 $bin"
    ok=0
  fi
done

# ---------- 6. 重启输入法 + 签名校验 ----------
echo "→ 重启 Squirrel..."
killall Squirrel 2>/dev/null && echo "  已结束进程" || echo "  进程未运行（首次添加输入法时会自动拉起）"
sleep 1
open "$APP" 2>/dev/null && echo "  已启动" || echo "  未能自动启动（请从输入法菜单切换触发）"
sleep 2
pgrep -fl MacOS/Squirrel | head -1 || echo "  ! 进程未运行"

echo "→ 签名校验..."
if codesign --verify --deep --strict "$APP" 2>/dev/null; then
  echo "  ✓ 签名正常"
else
  echo "  ✗ 签名异常！可能部署污染了 app 包，见 troubleshooting.md 坑 4"
fi
if ls -la "$APP/Contents/" 2>/dev/null | grep -qiE 'installation|user.yaml|build'; then
  echo "  ✗ app 包内有污染文件，见 troubleshooting.md 坑 4"
else
  echo "  ✓ app 包无污染"
fi

echo
if [ "$ok" -eq 1 ]; then
  echo "== 配置完成 =="
  echo "还需用户手动两步（命令行改不动）："
  echo "  1. 系统设置→键盘→输入法→+ 添加「鼠须管」"
  echo "  2. 输入法→编辑…→取消勾选「使用大写锁定键切换 ABC 输入模式」"
else
  echo "== 部分码表缺失，请按 troubleshooting.md 排查 =="
fi
