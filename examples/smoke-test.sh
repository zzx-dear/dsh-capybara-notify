#!/bin/bash
# smoke-test.sh — 插件冒烟测试
# 前置：dsh web 运行中且已加载 dsh-capybara-notify 插件。
set -euo pipefail
BASE="${DSH_WEB_URL:-http://127.0.0.1:3080}"

echo "==> 1. health"
curl -sf "$BASE/api/secretary/health" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; print('  ok, service =', d['service'])"

echo "==> 2. notify（投递一条测试告警）"
RESP=$(curl -sf -X POST "$BASE/api/secretary/notify" \
  -H 'content-type: application/json' \
  -d '{"title":"冒烟测试","body":"如果噜噜弹了这个气泡就说明全链路通了","level":"info"}')
echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['ok']; print('  ok, id =', d['id'])"

echo "==> 3. queue（刚才的告警应该排第一）"
curl -sf "$BASE/api/secretary/queue" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['ok'] and len(d['alerts']) > 0
top = d['alerts'][0]
assert top['title'] == '冒烟测试', top
print('  ok, latest =', top['title'])
"

echo
echo "✅ 全链路通过：API → 收件箱 → 桌面宠物"
