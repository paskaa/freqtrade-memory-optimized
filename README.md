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

