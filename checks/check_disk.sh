#!/bin/bash
# check_disk.sh — 磁盘巡检模板：超阈值才通知（静默通过）
# 用法: ./checks/check_disk.sh / 85   （挂载点 阈值%）
set -euo pipefail
DIR="${1:-/}"
THRESHOLD="${2:-85}"

USED=$(df -P "$DIR" | awk 'NR==2 {gsub("%","",$5); print $5}')
if [[ "$USED" -ge "$THRESHOLD" ]]; then
  "$(dirname "$0")/../notify.sh" -t "磁盘告警 ${USED}%" \
    -b "$DIR 已用 ${USED}%，超过阈值 ${THRESHOLD}%" -l error
  exit 1
fi
echo "磁盘正常: $DIR ${USED}%"
