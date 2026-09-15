#!/usr/bin/env bash
# 在 freqtrade 更新后重新应用本次改动（API gzip + FreqUI 新前端）。
# 用法：bash apply_runtime.sh [site-packages 路径]
#   默认 /root/ft_userdata/.venv/lib/python3.12/site-packages
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="${1:-/root/ft_userdata/.venv/lib/python3.12/site-packages}"
FT="$SITE/freqtrade"
WS="$FT/rpc/api_server/webserver.py"
UI="$FT/rpc/api_server/ui/installed"
STAMP="$(date +%Y%m%d_%H%M%S)"

[ -f "$WS" ] || { echo "找不到 $WS —— site-packages 路径不对？" >&2; exit 1; }

echo "==> 1/2 给 API server 打 gzip 补丁"
if grep -q "GZipMiddleware" "$WS"; then
  echo "    已存在 GZipMiddleware，跳过"
else
  cp -p "$WS" "$WS.bak_$STAMP"
  python3 - "$WS" <<'PY'
import sys

path = sys.argv[1]
src = open(path).read()

imp = "from fastapi.middleware.cors import CORSMiddleware\n"
assert imp in src, "未找到 CORSMiddleware 的 import 行，请手动打补丁"
if "from starlette.middleware.gzip import GZipMiddleware" not in src:
    src = src.replace(
        imp, imp + "from starlette.middleware.gzip import GZipMiddleware\n", 1
    )

anchor = """        app.add_middleware(
            CORSMiddleware,
            allow_origins=config["api_server"].get("CORS_origins", []),
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
"""
assert anchor in src, "未找到 CORSMiddleware 注册块，请手动打补丁"
if "GZipMiddleware," not in src:
    src = src.replace(
        anchor,
        anchor
        + """
        if config["api_server"].get("enable_gzip", True):
            # Compress responses above 1k (Trade history can easily be multiple MB).
            app.add_middleware(
                GZipMiddleware,
                minimum_size=1024,
                compresslevel=6,
            )
""",
        1,
    )

open(path, "w").write(src)
print("    已写入 gzip 中间件")
PY
  python3 -m py_compile "$WS" && echo "    语法校验通过"
fi

echo "==> 2/2 部署 FreqUI 前端（含成交上限与刷新间隔设置）"
[ -d "$UI" ] || { echo "    找不到 $UI" >&2; exit 1; }
[ -f "$UI/index.html" ] && cp -p "$UI/index.html" "$UI/index.html.bak_$STAMP"
tar xzf "$HERE/web_ui_dist.tar.gz" -C "$UI"
echo "    index.html 现引用: $(grep -o 'assets/index-[A-Za-z0-9_-]*\.js' "$UI/index.html")"
echo "    （旧 hash 的 assets 不会被清除，属正常）"

echo
echo "完成。gzip 需要重启服务才生效：systemctl restart freqtrade"
echo "UI 无需重启（静态文件实时读取），浏览器强刷即可。"
echo "验证：curl -sD - -o /dev/null -H 'Accept-Encoding: gzip' -u <user>:<pass> \\"
echo "        http://127.0.0.1:28082/api/v1/trades?limit=500 | grep -i content-encoding"
