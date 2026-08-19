#!/bin/bash
# 一键唤醒噜噜：重建 launchd 任务（若已注销）并立即拉起
cd "$(dirname "$0")"
LABEL="com.lulu.pet"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
if [ ! -f "$PLIST" ]; then
  PWD_DIR="$(pwd)"
  cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${PWD_DIR}/.venv/bin/python</string>
    <string>${PWD_DIR}/run_pet.py</string>
  </array>
  <key>WorkingDirectory</key><string>${PWD_DIR}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>/tmp/lulu-pet.out.log</string>
  <key>StandardErrorPath</key><string>/tmp/lulu-pet.err.log</string>
</dict>
</plist>
PLIST_EOF
fi
launchctl bootstrap gui/$(id -u) "$PLIST" 2>/dev/null || true
launchctl kickstart gui/$(id -u)/${LABEL} 2>/dev/null || true
echo "噜噜回来了 🦫"
