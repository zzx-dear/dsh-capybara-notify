#!/bin/bash
# notify.sh — 秘书告警投递（curl 到本机 dsh web 的秘书插件）
# 用法:
#   ./notify.sh -t "磁盘告警" -b "根分区已用 92%" -l error
#   echo "hi" | ./notify.sh -t "来自管道的消息"
# level: info | warning | error（默认 info）
set -euo pipefail

BASE="${SECRETARY_API:-http://127.0.0.1:3080/api/secretary/notify}"
TITLE=""; BODY=""; LEVEL="info"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--title) TITLE="$2"; shift 2 ;;
    -b|--body)  BODY="$2";  shift 2 ;;
    -l|--level) LEVEL="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

case "$LEVEL" in info|warning|error) ;; *) echo "level 必须是 info|warning|error" >&2; exit 2 ;; esac

# 支持 stdin 作为正文
if [[ -z "$BODY" && ! -t 0 ]]; then
  BODY="$(cat | head -c 400)"
fi
if [[ -z "$TITLE" && -z "$BODY" ]]; then
  echo "标题与正文至少给一个" >&2; exit 2
fi

PAYLOAD="$(python3 - "$TITLE" "$BODY" "$LEVEL" <<'EOF'
import json, sys
print(json.dumps({"title": sys.argv[1], "body": sys.argv[2], "level": sys.argv[3]}, ensure_ascii=False))
EOF
)"

CODE=$(curl -s -o /tmp/secretary-notify-resp.json -w '%{http_code}' \
  -X POST "$BASE" -H 'content-type: application/json' -d "$PAYLOAD" || echo 000)
if [[ "$CODE" == "200" ]]; then
  echo "✅ 已通知噜噜: $(cat /tmp/secretary-notify-resp.json)"
else
  echo "❌ 投递失败 (HTTP $CODE): $(cat /tmp/secretary-notify-resp.json 2>/dev/null)" >&2
  echo "   提示: 确认 dsh web 已重启并加载 dsh-secretary 插件" >&2
  exit 1
fi
