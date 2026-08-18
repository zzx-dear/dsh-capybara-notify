// dsh-capybara-notify — host half.
// 任务里的 agent 通过 POST /api/secretary/notify 投递告警；
// 本插件把告警写入 $DSH_HOME/secretary/inbox.jsonl，并合成
// activity/status 会话事件，由宠物服务（fiber 名 "pet"）渲染成
// 宠物气泡 + 动画；同时监听真实会话事件（回合完成/等待确认）。
import { appendFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export const name = "secretary";
export const inject = ["webServer"];

/** level → 宠物动画相位 */
const PHASES = { info: "done", warning: "waiting", error: "failed" };
const ICONS = { info: "🔔", warning: "⚠️", error: "🚨" };
const LINE_MAX = 22;    // 气泡是 nowrap 单行，标题必须短
const PHRASE_MAX = 22;  // 气泡优先显示 phrase，正文超此长度就不进气泡
const BODY_MAX = 500;

function json(res, status, body) {
  res.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body));
}

function readJsonBody(req, res) {
  return new Promise((resolve) => {
    let size = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > 64 * 1024) {
        json(res, 400, { ok: false, error: "body-too-large" });
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (chunks.length === 0) return resolve({});
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch {
        json(res, 400, { ok: false, error: "bad-json" });
        resolve(undefined);
      }
    });
  });
}

function clip(text, max) {
  const s = String(text ?? "").replace(/\s+/g, " ").trim();
  return s.length <= max ? s : `${s.slice(0, max - 1)}…`;
}

/** 全局 cordis 过滤器符号（Symbol.for，跨模块实例安全） */
const CORDIS_FILTER = Symbol.for("cordis.filter");

/** 宠物服务的 fiber 名（可经 SECRETARY_PET_FIBERS 逗号分隔扩展） */
const PET_FIBERS = new Set(
  (process.env.SECRETARY_PET_FIBERS || "pet")
    .split(",").map((s) => s.trim()).filter(Boolean),
);

/**
 * 把一条告警推给宠物服务。
 * 合成 activity/status 事件，并挂 cordis 过滤器：只有宠物服务的监听器
 * （默认 fiber 名为 "pet"）能收到，会话持久化/遥测等其他 "session/event"
 * 监听器不会被合成 session 对象打扰。
 * 任何失败都被吞掉：告警已落 inbox，通知失败不影响 HTTP 响应。
 */
function pushToPet(ctx, session, input) {
  try {
    session[CORDIS_FILTER] = (hookCtx) => PET_FIBERS.has(hookCtx?.fiber?.name ?? "");
    ctx.emit(session, "session/event", session, {
      type: "activity/status",
      data: input,
    });
    return "scoped-emit";
  } catch (error) {
    ctx.logger?.warn?.(error instanceof Error ? error : new Error(String(error)));
    return "failed";
  }
}

/**
 * 投递一条告警：落 inbox.jsonl（桌面宠物气泡+叮咚从这里读）+ 直推宠物相位。
 * 通知失败不影响返回，告警已落盘。
 */
function deliver(ctx, session, inbox, { title, text, level }) {
  const record = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    ts: Date.now(),
    title,
    body: text,
    level,
    acked: false,
  };
  try {
    appendFileSync(inbox, `${JSON.stringify(record)}\n`);
  } catch (error) {
    return { ok: false, error: String(error) };
  }
  const phrase = text !== "" && text.length <= PHRASE_MAX ? text : undefined;
  const input = {
    phase: PHASES[level],
    line: `${ICONS[level]} ${clip(title || text, LINE_MAX)}`,
    ...(phrase === undefined ? {} : { phrase }),
  };
  const channel = pushToPet(ctx, session, input);
  return { ok: true, id: record.id, channel };
}

export function apply(ctx) {
  const home = process.env.DSH_HOME || join(homedir(), ".dsh");
  const dir = join(home, "secretary");
  mkdirSync(dir, { recursive: true });
  const inbox = join(dir, "inbox.jsonl");

  // 合成会话：dsh-pet 只需要 id 与 header.origin
  const secretarySession = { id: "secretary-inbox", header: {} };

  const routes = [
    {
      kind: "exact",
      path: "/api/secretary/notify",
      handler: async (req, res) => {
        if (req.method !== "POST") return json(res, 405, { ok: false, error: "method-not-allowed" });
        const body = await readJsonBody(req, res);
        if (body === undefined) return;
        const title = clip(body.title, 60);
        const text = clip(body.body, BODY_MAX);
        if (title === "" && text === "") return json(res, 400, { ok: false, error: "empty-message" });
        const level = PHASES[body.level] ? body.level : "info";
        const result = deliver(ctx, secretarySession, inbox, {
          title: clip(body.title, 60),
          text: clip(body.body, BODY_MAX),
          level,
        });
        if (!result.ok) return json(res, 500, result);
        json(res, 200, { ok: true, id: result.id, channel: result.channel });
      },
    },
    {
      kind: "exact",
      path: "/api/secretary/queue",
      handler: async (req, res) => {
        if (req.method !== "GET") return json(res, 405, { ok: false, error: "method-not-allowed" });
        let alerts = [];
        try {
          if (existsSync(inbox)) {
            alerts = readFileSync(inbox, "utf8")
              .split("\n")
              .filter((line) => line.trim() !== "")
              .map((line) => { try { return JSON.parse(line); } catch { return undefined; } })
              .filter(Boolean)
              .slice(-50)
              .reverse();
          }
        } catch {}
        json(res, 200, { ok: true, alerts });
      },
    },
    {
      kind: "exact",
      path: "/api/secretary/health",
      handler: async (req, res) => {
        if (req.method !== "GET") return json(res, 405, { ok: false, error: "method-not-allowed" });
        json(res, 200, { ok: true, service: "dsh-capybara-notify", inbox });
      },
    },
  ];

  ctx.effect(() => {
    const disposers = routes.map((route) => ctx.webServer.register(route));
    return () => { for (const dispose of disposers) dispose(); };
  });

  // 会话活动监听：任务完成/等待继续/需要用户确认 → 通知噜噜。
  // 环境变量 SECRETARY_SESSION_ALERTS=0 可整体关闭。
  if (process.env.SECRETARY_SESSION_ALERTS !== "0") {
    ctx.on("session/event", (session, event) => {
      if (!session || session.id === "secretary-inbox") return;
      if (session.header?.origin === "subagent") return;
      if (!event || typeof event.type !== "string") return;
      if (event.type === "turn/end") {
        const kind = event.data?.reason?.kind;
        if (kind === "completed") {
          deliver(ctx, secretarySession, inbox, { title: "✅ 任务完成", text: "", level: "info" });
        } else if (kind === "blocked") {
          deliver(ctx, secretarySession, inbox, { title: "⏸ 等待继续", text: "", level: "warning" });
        }
        return;
      }
      if (event.type === "approval/asked") {
        const reason = clip(event.data?.reason || "", PHRASE_MAX);
        const body = reason !== "" ? reason : clip(event.data?.toolName || "", PHRASE_MAX);
        deliver(ctx, secretarySession, inbox, { title: "⚠️ 需要你确认", text: body, level: "warning" });
      }
    });
  }
}
