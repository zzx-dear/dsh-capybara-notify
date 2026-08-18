#!/bin/bash
# install_pet.sh — 一键安装桌面宠物（macOS）
# 1. 创建本目录下的 .venv 并安装 pywebview
# 2. 注册 launchd 服务 com.lulu.pet（开机自启 + 崩溃自动拉起）
# 3. 启动宠物
#
# 前置：macOS；python3（>=3.9）；一个 Codex Pet 装到 ~/.codex/pets/<id>/
#   （图集 8 列 x 9 行；不装宠物也可以跑，但屏幕上是空的）
set -euo pipefail
cd "$(dirname "$0")"
PWD_DIR="$(pwd)"
PY="$(command -v python3 || command -v python)"
LABEL="com.lulu.pet"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

echo "==> 创建虚拟环境"
"$PY" -m venv .venv
./.venv/bin/pip install -q --upgrade pip
./.venv/bin/pip install -q pywebview

echo "==> 注册 launchd 服务（${LABEL}）"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${PWD_DIR}/.venv/bin/python</string>
    <string>${PWD_DIR}/run_pet.py</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${PWD_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>/tmp/lulu-pet.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/lulu-pet.err.log</string>
</dict>
</plist>
PLIST_EOF

launchctl bootout gui/$(id -u)/${LABEL} 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST"

echo
echo "✅ 噜噜已启动（launchd 托管：开机自启、异常退出自动拉起）"
echo
echo "接下来建议："
echo "  1. 在网页 GUI 隐藏内置宠物："
echo "     curl -X POST http://127.0.0.1:3080/api/pet/set-visible \\"
echo "       -H 'content-type: application/json' -d '{\"visible\": false}'"
echo "  2. 定制宠物：把 Codex Pet 放到 ~/.codex/pets/<id>/（pet.json + 图集，"
echo "     8 列 x 9 行），默认选 id=capybara-ruru，否则用 LULU_PET_ID 指定"
echo "  3. 大小：LULU_SCALE=0.40（默认约 77 像素宽），可改"
echo "  4. 手动退出：右键宠物或点 ✕；下次登录自动回来"
