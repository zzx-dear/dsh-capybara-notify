#!/bin/bash
# check_process.sh — 进程存活巡检模板：不在才通知
# 用法: ./checks/check_process.sh nginx "Web 服务"
set -euo pipefail
PROC="${1:?用法: check_process.sh <进程名> [描述]}"
DESC="${2:-$PROC}"

if ! pgrep -x "$PROC" >/dev/null 2>&1; then
  "$(dirname "$0")/../notify.sh" -t "进程掉线: $DESC" \
    -b "$PROC 未在运行，请检查服务状态" -l warning
  exit 1
fi
echo "进程正常: $PROC"
