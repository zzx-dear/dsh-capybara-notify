# 任务卡模板 — 贴到「任务看板」的卡片里

## 卡 1：磁盘巡检（每晚 23:00）

- **cron**: `0 23 * * *`
- **模式**: 默认（Code Mode）
- **工作区**: `/Users/zzx/deekseek`
- **权限**: `read-only`（巡检只读；通知走 HTTP 无需写权限）
- **任务指令**（贴进任务描述）:

```
运行 /Users/zzx/deekseek/secretary/checks/check_disk.sh / 85
如果脚本退出码非 0（已发出通知），不要重复通知；
如果通知脚本本身失败（HTTP 非 200），把失败原因写入 /Users/zzx/deekseek/secretary/out/disk-report.log 并重试一次。
```

## 卡 2：站点可用性巡检（每 30 分钟）

- **cron**: `*/30 * * * *`
- **权限**: `read-only`
- **任务指令**:

```
运行 /Users/zzx/deekseek/secretary/checks/check_http.sh <你的目标URL> 200
同上，脚本退出码非 0 时不要重复通知。
```

## 卡 3：SSH 服务器巡检（每天 09:00，需 dsh-ssh 已配置主机）

- **cron**: `0 9 * * *`
- **权限**: `danger-full-access`（ssh_exec 需要）
- **任务指令**:

```
用 ssh_list 查看配置的主机；对每台主机执行
"df -h / && uptime && systemctl is-system-running"，
若有磁盘超 85%、负载异常或服务失败，
调用 bash 运行:
  /Users/zzx/deekseek/secretary/notify.sh -t "服务器告警" -b "<主机>: <问题摘要>" -l error
全部正常则静默结束，不要通知。
```

## 手动测试一张卡

新建卡片，cron 留空（手动触发），指令就写：

```
bash /Users/zzx/deekseek/secretary/notify.sh -t "噜噜上线测试" -b "秘书系统正常运转" -l info
```

跑通后：右下角宠物跳一跳、头顶气泡显示「🔔 噜噜上线测试」、播放叮咚提示音。
