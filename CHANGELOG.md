# Changelog

本文件记录 dsh-capybara-notify 的重要变更。格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### Added

- 告警收件箱 API：`POST /api/secretary/notify`、`GET /api/secretary/queue`、`GET /api/secretary/health`
- 会话智能提醒：回合完成 / 等待用户确认（附申请理由）/ 回合阻塞；子代理静默；`SECRETARY_SESSION_ALERTS=0` 可关
- 桌面宠物（macOS pywebview）：透明置顶双窗、点击穿透、拖拽跟手、位置记忆、截图隐身、launchd 托管（开机自启 + 崩溃自愈）、web 断线自愈
- 巡检脚本：`notify.sh` + 磁盘 / HTTP / 进程存活模板
- 每日插件推荐：`check_plugins.sh` 按市场 star 挑未安装高口碑插件，每天 3 款
- 定向推送：cordis 过滤器合成 activity/status 事件，宠物服务 fiber 名可经 `SECRETARY_PET_FIBERS` 扩展
- CI 工作流：JS / Python / Shell 语法检查

### Changed

- 全部路径环境变量化（`DSH_WEB_URL` / `LULU_PET_ID` / `LULU_SCALE` / `SECRETARY_API`…），零硬编码、零密钥
