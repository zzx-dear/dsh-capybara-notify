#!/bin/bash
# 手动启动桌面宠物（平时由 launchd 托管，见 install_pet.sh）
cd "$(dirname "$0")"
if curl -s -m 1 http://127.0.0.1:3099/pet.html -o /dev/null 2>/dev/null; then
  echo "噜噜已在运行，无需重复启动"
  exit 0
fi
exec ./.venv/bin/python run_pet.py
