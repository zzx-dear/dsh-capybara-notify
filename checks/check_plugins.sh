#!/bin/bash
# check_plugins.sh — 插件口碑巡检（launchd 每天 09:00 触发）
# 从 awesome-dsh-plugin.com 市场里，按 star 挑「你没装过、大家认可」的插件，
# 每天推荐 3 款（不重复），通知噜噜；详情落盘 ../plugin-daily.log。
# 零 API 配额、不依赖浏览器；web 未开则下一天自动补投。
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="https://awesome-dsh-plugin.com/plugins.json"
CACHE="/tmp/lulu-plugins.json"
STATE="$DIR/.plugin-check-state.json"
LOG="$DIR/plugin-daily.log"
API_HEALTH="http://127.0.0.1:3080/api/secretary/health"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# 拉取市场清单（-z：服务端未更新则 304 不重下，节省流量）
if ! curl -sfz "$CACHE" -m 25 "$REGISTRY" -o "$CACHE"; then
  [[ -f "$CACHE" ]] || log "fetch failed (no cache), retry next run"
fi
[[ -f "$CACHE" ]] || exit 0

python3 - "$CACHE" "$STATE" "$DIR" "$API_HEALTH" <<'PYEOF'
import json, os, re, subprocess, sys, datetime

cache, state_path, root, api_health = sys.argv[1:5]
MIN_STARS = 60     # 「大家认可」门槛：约占市场前 6%
TOP_N = 3          # 每天推荐款数

try:
    reg = json.load(open(cache))
except Exception:
    sys.exit(0)
plugins = [p for p in reg.get("plugins", []) if isinstance(p, dict)]

def log(msg):
    with open(os.path.join(root, "plugin-daily.log"), "a") as f:
        f.write(f"[{datetime.datetime.now():%F %T}] {msg}\n")

def alnum(s):
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())

# 展示名：registry 里常有 "owner#子路径"，取 repo 标识部分更可读
def display(p):
    n = p.get("name") or ""
    return n.split("#")[0] if "#" in n else n

# 已安装品牌名（忽略 scope 与 -/_ 差异；scope 与短名都收录）
SKIP_BRANDS = {"dshwebui"}   # dsh-web-ui 合集的其他 fork，用户已装 @linxin666 全家桶
installed = set()
try:
    pj = json.load(open(os.path.expanduser("~/.dsh/profiles/web/package.json")))
    for key in pj.get("dependencies", {}).keys():
        parts = key.split("/")
        installed.add(alnum(key))          # 全名
        installed.add(alnum(parts[-1]))    # 短名
        if len(parts) > 1:
            installed.add(alnum(parts[0])) # scope 品牌名
except Exception:
    pass

def is_installed(p):
    return (alnum(p.get("name") or "") in installed
            or alnum(display(p)) in installed
            or alnum(display(p)) in SKIP_BRANDS)

try:
    state = json.load(open(state_path))
except Exception:
    state = {}
seen = set(state.get("seen", []))
pending = state.get("pending", [])

# 候选：star 达标且未安装
eligible = [p for p in plugins if (p.get("stars") or 0) >= MIN_STARS and not is_installed(p)]

# 没有待投递的推荐 → 挑 3 款没推过的；不够则重置 seen 重新挑
if not pending:
    cands = [p for p in eligible if p.get("name") not in seen]
    cands.sort(key=lambda p: -(p.get("stars") or 0))
    if len(cands) < TOP_N:
        seen = set()
        cands = eligible
        cands.sort(key=lambda p: -(p.get("stars") or 0))
    picks = cands[:TOP_N]
    pending = [{
        "name": p.get("name"), "display": display(p),
        "stars": p.get("stars") or 0, "url": p.get("url") or "",
        "desc": (p.get("description") or {}).get("zh", "") or
                (p.get("description") or {}).get("en", ""),
        "category": p.get("category", ""),
    } for p in picks]

if not pending:
    json.dump({"seen": sorted(seen), "pending": [], "last_notified": state.get("last_notified")},
              open(state_path, "w"), ensure_ascii=False, indent=1)
    sys.exit(0)

# web 未开 → 保留 pending，下一天补投
health = subprocess.run(["curl", "-s", "-m", "3", api_health],
                        capture_output=True, text=True).stdout
if '"ok":true' not in health:
    json.dump({"seen": sorted(seen), "pending": pending, "last_notified": state.get("last_notified")},
              open(state_path, "w"), ensure_ascii=False, indent=1)
    log(f"dsh web down, {len(pending)} picks pending, retry next run")
    sys.exit(0)

# 投递：标题给款数，气泡正文只放最热的一款（22 字上限）
n = len(pending)
top = pending[0]
phrase = f"{top['display']} ⭐{top['stars']}"
if len(phrase) > 22:
    phrase = ""
title = f"🐹 今日推荐 {n} 款"
cmd = [os.path.join(root, "notify.sh"), "-t", title, "-l", "info"]
if phrase:
    cmd += ["-b", phrase]
r = subprocess.run(cmd, capture_output=True, text=True)
if r.returncode == 0:
    for p in pending:
        log(f"REC {p['display']} ⭐{p['stars']} [{p['category']}] {p['desc'][:100]} {p['url']}")
    seen |= {p["name"] for p in pending}
    state = {"seen": sorted(seen), "pending": [], "last_notified": datetime.date.today().isoformat()}
    log(f"recommended {n} plugin(s)")
else:
    state = {"seen": sorted(seen), "pending": pending, "last_notified": state.get("last_notified")}
    log(f"notify failed: {r.stderr.strip()[:200]}; retry next run")
json.dump(state, open(state_path, "w"), ensure_ascii=False, indent=1)
PYEOF
