# Contributing

谢谢你有兴趣贡献！dsh-capybara-notify 是一个小项目，欢迎提 issue、PR 或改进文档。

## 快速自检

改完代码后，跑一遍语法检查：

```sh
node --check lib/index.js && node --check lib/client.js
python3 -m py_compile pet/run_pet.py
for f in checks/*.sh pet/install_pet.sh pet/start.command; do bash -n "$f"; done
```

CI（`.github/workflows/ci.yml`）会在每次 push / PR 时自动跑同样的检查。

## 目录结构

- `lib/index.js` — 插件主机侧：告警 API（notify/queue/health）+ 会话智能提醒
- `lib/client.js` — 浏览器侧：默认零侵入，可选隐藏 GUI 宠物
- `pet/` — 桌面宠物（macOS pywebview）
- `checks/` — 巡检脚本与每日插件推荐
- `examples/` — 任务看板模板、冒烟测试、市场登记文件

## 提交规范

- 一次提交做一件事，message 用英文祈使句
- 不提交任何密钥、token、或宠物素材
- 保持零硬编码路径（路径一律环境变量化）
