# 架构 / Architecture

```
                 ┌─────────────────────────────────────────────┐
                 │            DSH host（dsh web）              │
                 │                                             │
  cron/脚本 ───► │ POST /api/secretary/notify                  │
 任务看板 agent   │       │                                     │
                 │       ▼                                     │
                 │  inbox.jsonl（$DSH_HOME/secretary/）        │
                 │       │                                     │
                 │       ├── pushToPet：合成 activity/status    │
                 │       │   （cordis 过滤器 → fiber "pet"）   │
                 │       └── GET /api/secretary/queue          │
                 │                                             │
  真实会话事件 ─► │ ctx.on("session/event")                     │
  (turn/end,     │   └─ 完成/确认/阻塞 → deliver()             │
   approval/asked)                                            │
                 └───────────────┬─────────────────────────────┘
                                 │ http://127.0.0.1:3080
                 ┌───────────────▼─────────────────────────────┐
                 │   桌面宠物（pywebview，端口 3099 反代）      │
                 │                                             │
                 │  精灵窗：轮询 /api/pet/state 驱动动画        │
                 │  气泡窗：轮询 /api/secretary/queue           │
                 │          → 新告警 = 气泡 + 叮咚             │
                 │                                             │
                 │  launchd（com.lulu.pet）：开机自启 + 自愈    │
                 └─────────────────────────────────────────────┘
```

## 关键设计

1. **定向推送**：`ctx.emit` 合成 session 事件时挂
   `Symbol.for("cordis.filter")` 过滤器（`fiber.name === "pet"`），
   只有宠物服务收到，会话持久化/遥测监听器不会被合成 session 打扰。
2. **气泡双通道**：立即推送（宠物相位动画）+ 收件箱落盘（桌面宠物轮询队列
   弹气泡/响铃）。即使推送失败，告警也已落盘可回看。
3. **宠物与 web 解耦**：宠物经 3099 反代访问 3080，web 重启期间页面每 3 秒
   重试加载，恢复后自动接上；宠物进程由 launchd 托管，与 web 进程树无关。
4. **零密钥**：插件不读任何凭据；宠物上游地址等全部环境变量化。
