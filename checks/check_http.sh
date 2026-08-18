#!/bin/bash
# check_http.sh — 站点/API 可用性巡检模板：不可达或状态码异常才通知
# 用法: ./checks/check_http.sh https://example.com/health 200,301
set -euo pipefail
URL="${1:?用法: check_http.sh <url> [期望状态码,逗号分隔]}"
WANT="${2:-200}"

CODE=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$URL" || echo 000)
if ! echo "$WANT" | tr ',' '\n' | grep -qx "$CODE"; then
  "$(dirname "$0")/../notify.sh" -t "站点异常 HTTP $CODE" \
    -b "$URL 返回 $CODE（期望 $WANT）" -l error
  exit 1
fi
echo "站点正常: $URL → $CODE"
