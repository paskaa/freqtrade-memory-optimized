#!/usr/bin/env bash
# 在 freqtrade 更新后重新应用本次改动：
#   1) API gzip 压缩（webserver.py）
#   2) handle_onexchange_order 重复插入订单的修复（freqtradebot.py）
#   3) FreqUI 新前端（成交历史去重下载 + 刷新间隔/条数设置）
#
# 用法：bash apply_runtime.sh [site-packages 路径]
#   默认 /root/ft_userdata/.venv/lib/python3.12/site-packages
# 幂等：已打过补丁则自动跳过；应用前用 grep 判断，不依赖 patch 的模糊匹配。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="${1:-/root/ft_userdata/.venv/lib/python3.12/site-packages}"
FT="$SITE/freqtrade"
UI="$FT/rpc/api_server/ui/installed"
STAMP="$(date +%Y%m%d_%H%M%S)"

[ -d "$FT" ] || { echo "找不到 $FT —— site-packages 路径不对？" >&2; exit 1; }

apply_hunk() {         # $1=文件  $2=已存在标记  $3=补丁文件  $4=说明
  local file="$1" marker="$2" diff="$3" desc="$4"
  [ -f "$file" ] || { echo "    缺少 $file" >&2; return 1; }
  if grep -q "$marker" "$file"; then
    echo "    $desc：已应用，跳过"
    return 0
  fi
  cp -p "$file" "$file.bak_$STAMP"
  if patch --forward --silent --no-backup-if-mismatch -p0 "$file" < "$diff"; then
    echo "    $desc：已应用（备份 $file.bak_$STAMP）"
  else
    echo "    $desc：打补丁失败，请人工检查 $file（原文件已备份）" >&2
    return 1
  fi
}

echo "==> 1/3 给 API server 打 gzip 补丁"
apply_hunk "$FT/rpc/api_server/webserver.py" "GZipMiddleware" \
  "$HERE/freqtrade-runtime-gzip.diff" "gzip 中间件"

echo "==> 2/3 给 handle_onexchange_order 打重复插入修复"
apply_hunk "$FT/freqtradebot.py" "is already stored for" \
  "$HERE/freqtrade-runtime-onexchange-order.diff" "onexchange order 修复"

for f in "$FT/rpc/api_server/webserver.py" "$FT/freqtradebot.py"; do
  python3 -m py_compile "$f" || { echo "    语法校验失败: $f" >&2; exit 1; }
done
echo "    语法校验通过"

echo "==> 3/3 部署 FreqUI 前端（成交历史去重下载 + 刷新间隔/条数设置）"
[ -d "$UI" ] || { echo "    找不到 $UI" >&2; exit 1; }
[ -f "$UI/index.html" ] && cp -p "$UI/index.html" "$UI/index.html.bak_$STAMP"
tar xzf "$HERE/web_ui_dist.tar.gz" -C "$UI"
echo "    index.html 现引用: $(grep -o 'assets/index-[A-Za-z0-9_-]*\.js' "$UI/index.html")"
echo "    （旧 hash 的 assets 不会被清除，属正常）"

echo
echo "完成。变更 1/2 需重启生效：systemctl restart freqtrade"
echo "UI 无需重启（静态文件实时读取），浏览器强刷即可。"
echo "验证：curl -sD - -o /dev/null -H 'Accept-Encoding: gzip' -u <user>:<pass> \\"
echo "        http://127.0.0.1:28082/api/v1/trades?limit=500 | grep -i content-encoding"
