# FreqTrade Memory Optimization

This repository contains optimized freqtrade code with memory management improvements for FreqAI training.

## Modified Files

### 1. freqtrade/freqai/freqai_interface.py
- Added automatic memory cleanup after each model training
- Implemented `gc.collect()` and `malloc_trim()` to prevent memory fragmentation
- Added debug logging for training progress monitoring

### 2. freqtrade/exchange/exchange.py
- Fixed async API calls to use sync API for proxy compatibility
- Improved market loading with better error handling

### 3. freqtrade/persistence/trade_model.py
- Fixed stop_loss_pct type conversion

## How to Apply

1. Clone the original freqtrade repo
2. Copy the modified files from this repo
3. Run freqtrade with the optimizations

## Patch File

See `freqai-memory-optimization.patch` for the complete diff.

---

# 2026-09-15 — API gzip 压缩 + FreqUI 提速

针对「打开 FreqUI 时 Bot comparison / Open Trades 很久才出数据」做的改动。

### 1. freqtrade/rpc/api_server/webserver.py
- 注册 Starlette `GZipMiddleware`（>1KB 才压，compresslevel 6），新增 `enable_gzip` 配置项（默认开）
- 效果：`/api/v1/trades?limit=500` 1390095 B → 187974 B；`/status` 79.8KB → 11.4KB

### 2. FreqUI（前端，见 `patches/frequi-trade-limit-and-refresh.patch`）
- 新增设置「Maximum number of trades to load」（默认 500，`Unlimited` 恢复原行为）
- 取数改为 `order_by_id=false`（按平仓时间倒序），否则 limit 拿到的是**最老**的 500 笔
- 新增设置：自动刷新间隔（open trades/locks、trade history/balance）

## 注意：实盘跑的不是源码树

实盘 import 的是 venv 里的副本：`/root/ft_userdata/.venv/lib/python3.12/site-packages/freqtrade/`，
`/root/freqtrade` 只是源码树，不参与运行；FreqUI 静态文件也用
`…/site-packages/freqtrade/rpc/api_server/ui/installed/`。

## How to Apply（幂等，自动备份原文件）

```bash
bash patches/apply_runtime.sh          # 打 gzip 补丁 + 部署 FreqUI 产物
systemctl restart freqtrade            # gzip 需要重启；UI 静态文件不需要
```

- `patches/freqtrade-api-gzip.patch` —— 源码树上的提交（含 config_schema / docs / 测试）
- `patches/frequi-source.diff` —— FreqUI 源码改动
- 上游 PR：freqtrade/frequi#3042；`paskaa/freqtrade` 分支 `api-gzip`（freqtrade 上游 PR 待开）
- 说明见 `patches/README-2026-09-15.md`

