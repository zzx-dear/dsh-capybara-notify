# dsh-capybara-notify 🦫

**水豚秘书**：给 DeepSeek Harness（DSH）装上桌面宠物通知与告警收件箱。
任务完成、需要你确认、定时巡检、每日插件推荐——都由桌面上的水豚「噜噜」用气泡 + 叮咚告诉你。

> English quickstart at the bottom.

## 功能

| 能力 | 说明 |
|---|---|
| 🔔 告警 API | `POST /api/secretary/notify`：任何脚本、任务看板、cron 都能投递，宠物弹气泡 + 叮咚 |
| 📥 收件箱 | 告警落盘 `$DSH_HOME/secretary/inbox.jsonl`，`/queue` 取最近 50 条 |
| 🧠 会话智能提醒 | 监听真实会话事件：**回合完成 → 「✅ 任务完成」**；**等待确认 → 「⚠️ 需要你确认：理由」**；**阻塞 → 「⏸ 等待继续」**（子代理静默） |
| 🦫 桌面宠物 | 透明置顶小窗（macOS）：点击穿透、拖拽跟手、位置记忆、截图隐身、launchd 托管（开机自启 + 崩溃自愈） |
| 📋 巡检脚本 | 磁盘 / HTTP / 进程存活巡检模板（超阈值才通知） |
| ⭐ 每日插件推荐 | 从 [awesome-dsh-plugin](https://awesome-dsh-plugin.com) 市场按 star 挑你没装的高口碑插件，每天推 3 款 |

## 安装

### 1. 插件本体

```sh
dsh plugin --profile <你的profile> add "github:<owner>/dsh-capybara-notify"
# 或本地开发：
dsh plugin --profile web add link:/path/to/dsh-capybara-notify
```

重启 dsh（`dsh web`）后生效。测试：

```sh
bash /path/to/dsh-capybara-notify/checks/notify.sh -t "测试" -b "噜噜在听" -l info
```

### 2. 桌面宠物（可选，macOS）

```sh
bash /path/to/dsh-capybara-notify/pet/install_pet.sh
```

脚本会：建 `.venv` 装 pywebview → 注册 launchd 服务 `com.lulu.pet`（开机自启 + 异常退出自动拉起）→ 启动宠物。

**定制宠物形象**：宠物图集来自 Codex Pet 生态（8 列 × 9 行布局）。
把你的宠物放到 `~/.codex/pets/<id>/`（`pet.json` + 图集），默认选 `capybara-ruru`，
用环境变量 `LULU_PET_ID` 指定其他 id（图集版权自负，本仓库**不附带**任何宠物素材）。

隐藏网页 GUI 里内置宠物（桌面宠物是主角）：

```sh
curl -X POST http://127.0.0.1:3080/api/pet/set-visible \
  -H 'content-type: application/json' -d '{"visible": false}'
```

### 3. 每日插件推荐（可选）

```sh
# macOS launchd，每天 09:00
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.lulu.plugin-check.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.lulu.plugin-check</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$(pwd)/checks/check_plugins.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/tmp/lulu-plugin-check.out.log</string>
  <key>StandardErrorPath</key><string>/tmp/lulu-plugin-check.err.log</string>
</dict>
</plist>
EOF
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.lulu.plugin-check.plist
```

规则：star ≥ 60（市场前 6%）→ 排除已装 → 排除推过 → 每天按口碑推 3 款；
发现新货时噜噜弹「🐹 今日推荐 3 款」，明细落 `checks/../plugin-daily.log`。

## API

### POST `/api/secretary/notify`

```json
{ "title": "磁盘告警", "body": "根分区已用 92%", "level": "info | warning | error" }
```

- `title` ≤ 60 字、`body` ≤ 500 字；气泡是单行，标题 ≤ 22 字、正文 ≤ 22 字才进气泡
- 返回 `{ "ok": true, "id": "...", "channel": "scoped-emit" }`

### GET `/api/secretary/queue`

最近 50 条告警（新的在前）：`{ "ok": true, "alerts": [...] }`

### GET `/api/secretary/health`

`{ "ok": true, "service": "dsh-capybara-notify", "inbox": "/path" }`

### 巡检脚本

```sh
checks/notify.sh -t "标题" -b "正文" -l info      # 投递一条告警
echo "hi" | checks/notify.sh -t "来自管道"        # 支持 stdin 作为正文
checks/check_http.sh https://example.com          # 站点不可达才通知
checks/check_disk.sh 90                           # 根分区超过 90% 才通知
checks/check_process.sh dsh                       # 进程不在才通知
```

## 会话智能提醒

| 时机 | 气泡 | 级别 |
|---|---|---|
| 一轮任务（turn）完成 | ✅ 任务完成 | info |
| 需要你在 GUI 确认（沙箱升级/批准等，附申请理由） | ⚠️ 需要你确认：… | warning |
| 回合被阻塞等待继续 | ⏸ 等待继续 | warning |

- 子代理（subagent）回合不响，只响主会话
- 关闭：dsh 进程环境变量 `SECRETARY_SESSION_ALERTS=0`
- 每条落盘 inbox.jsonl，可回看

## 任务看板联动

任务看板（dsh-task-board）建定时任务卡，指令让 agent 跑巡检并在异常时投递：

```
跑 bash /path/to/checks/check_disk.sh 90；超阈值时它会自动通知噜噜。
```

模板见 `examples/task-cards.md`。

## 环境变量

| 变量 | 默认 | 作用 |
|---|---|---|
| `SECRETARY_SESSION_ALERTS` | 开 | `0` 关闭会话提醒 |
| `SECRETARY_PET_FIBERS` | `pet` | 宠物服务 fiber 名（逗号分隔） |
| `SECRETARY_API` | `http://127.0.0.1:3080/api/secretary/notify` | notify.sh 投递地址 |
| `DSH_WEB_URL` | `http://127.0.0.1:3080` | 桌面宠物反代上游 |
| `LULU_SCALE` | `0.40` | 宠物缩放（0.40 ≈ 77 像素宽） |
| `LULU_PET_ID` | `capybara-ruru` | 宠物注册表 id |
| `LULU_X` / `LULU_Y` | 右下角 | 初始位置（拖拽后位置自动记忆） |

## 已知限制

- 桌面宠物仅 macOS（pywebview/WebKit 透明置顶窗）；Linux/Windows 仍可用插件 API + 任意 dsh-pet 兼容前端
- 任务看板 cron 在浏览器端：GUI 标签页需开着，错过不补
- 每次触发巡检/推荐任务会消耗 API 额度（插件本身零配额）

## English quickstart

```sh
# 1. install plugin
dsh plugin --profile web add "github:<owner>/dsh-capybara-notify"

# 2. optional desktop pet (macOS)
bash /path/to/dsh-capybara-notify/pet/install_pet.sh

# 3. send a test alert
bash /path/to/dsh-capybara-notify/checks/notify.sh -t "Hello" -b "capybara is listening" -l info
```

Alerts POST to `/api/secretary/notify`; the pet bubble + ding reads `/api/secretary/queue`.
Session-aware alerts (turn done / approval asked / turn blocked) work out of the box;
disable with env `SECRETARY_SESSION_ALERTS=0`.

## License

MIT — 见 [LICENSE](LICENSE)。宠物形象素材不包含在本仓库内，请使用你自己的 Codex Pet。
