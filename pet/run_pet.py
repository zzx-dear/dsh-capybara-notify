#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""噜噜桌面宠物 — 双透明置顶小窗（pywebview + WebKit）。

- 精灵窗（"噜噜"）：永远接管鼠标（按下即归它，背后应用收不到事件，
  不会出现"拖动变成选择文字"）；窗口紧贴宠物身体（192×208 × SCALE）。
- 气泡窗（"噜噜气泡"）：永远 ignoresMouseEvents（点击穿透），告警时浮出气泡。
- 两个窗口都设 NSWindowSharingNone：截图/录屏里不出现。
- 拖拽：后台线程全局鼠标跟踪，两个窗口一起移动。
"""
import http.server
import os
import threading
import time
import urllib.request

import webview

HERE = os.path.dirname(os.path.abspath(__file__))
PAGE = os.path.join(HERE, "pet.html")
POS_FILE = os.path.join(HERE, "lulu-pos.json")  # 位置记忆（重启后回到原位）
UPSTREAM = os.environ.get("DSH_WEB_URL", "http://127.0.0.1:3080")
PORT = 3099
# 宠物缩放（LULU_SCALE 环境变量，默认 0.40 ≈ 77 像素宽）
SCALE = float(os.environ.get("LULU_SCALE", "0.40"))
# 精灵 id（LULU_PET_ID 环境变量；缺省 capybara-ruru，无则取注册表第一个）
PET_ID = os.environ.get("LULU_PET_ID", "capybara-ruru")

SPRITE_W = int(192 * SCALE) + 6   # 精灵窗宽
SPRITE_H = int(208 * SCALE) + 4   # 精灵窗高
BUBBLE_W = 176                    # 气泡窗宽（文字空间）
BUBBLE_H = 56                     # 气泡窗高


def save_pos(sprite_win, bubble_win, screen):
    """位置记忆：拖拽结束/启动时落盘，重启后回到原位。"""
    try:
        import json
        with open(POS_FILE, "w") as f:
            json.dump({
                "screen": [screen.width, screen.height],
                "sprite": [sprite_win.x, sprite_win.y, SPRITE_W, SPRITE_H],
                "bubble": [bubble_win.x, bubble_win.y, BUBBLE_W, BUBBLE_H],
            }, f)
    except Exception:
        pass


def load_pos(screen):
    try:
        import json
        with open(POS_FILE, "r") as f:
            d = json.load(f)
        if d.get("screen") == [screen.width, screen.height]:
            return int(d["sprite"][0]), int(d["sprite"][1])
    except Exception:
        pass
    return None


class Proxy(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _serve_page(self):
        try:
            with open(PAGE, "r", encoding="utf-8") as f:
                body = f.read().replace("__SCALE__", str(SCALE)).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except OSError:
            self.send_response(500)
            self.end_headers()

    def _forward(self):
        try:
            data = None
            if self.command == "POST":
                length = int(self.headers.get("Content-Length") or 0)
                data = self.rfile.read(length) if length else None
            req = urllib.request.Request(UPSTREAM + self.path, data=data, method=self.command)
            if data is not None:
                req.add_header("Content-Type", self.headers.get("Content-Type", "application/json"))
            with urllib.request.urlopen(req, timeout=30) as r:
                body = r.read()
                self.send_response(r.status)
                self.send_header("Content-Type", r.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
        except Exception:
            try:
                self.send_response(502)
                self.send_header("Content-Length", "0")
                self.end_headers()
            except Exception:
                pass

    def do_GET(self):
        from urllib.parse import urlsplit
        if urlsplit(self.path).path in ("/", "/pet.html"):
            self._serve_page()
        else:
            self._forward()

    def do_POST(self):
        self._forward()


class Api:
    def __init__(self):
        self.windows = []

    def quit(self):
        for w in list(self.windows):
            try:
                w.destroy()
            except Exception:
                pass


class DragTracker:
    """全局鼠标跟踪：按住宠物拖动时移动两个窗口；无穿透切换（精灵窗永远接管鼠标）。"""

    def __init__(self, sprite_win, bubble_win, screen_h, on_save=None):
        self.sprite = sprite_win
        self.bubble = bubble_win
        self.screen_h = screen_h
        self.on_save = on_save
        self.drag = None
        self.was_pressed = False
        self._stop = False
        self._thread = None
        self.px = 0
        self.py = 0
        self.bx = 0
        self.by = 0

    def start(self):
        self.px, self.py = int(self.sprite.x), int(self.sprite.y)
        self.bx, self.by = int(self.bubble.x), int(self.bubble.y)
        self._stop = False
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop = True

    def _loop(self):
        from AppKit import NSEvent
        while not self._stop:
            try:
                loc = NSEvent.mouseLocation()
                mx, my = loc.x, self.screen_h - loc.y
                wx, wy = self.px, self.py
                over_sprite = (wx <= mx <= wx + SPRITE_W and wy <= my <= wy + SPRITE_H)

                pressed = bool(NSEvent.pressedMouseButtons() & 1)
                if self.drag is not None:
                    if not pressed:
                        self.drag = None
                        if self.on_save is not None:
                            self.on_save()
                    else:
                        gx, gy, px, py = self.drag
                        if abs(mx - px) + abs(my - py) > 4:
                            nx, ny = int(mx - gx), int(my - gy)
                            dx, dy = nx - self.px, ny - self.py
                            self.sprite.move(nx, ny)
                            self.bubble.move(self.bx + dx, self.by + dy)
                            self.px, self.py = nx, ny
                            self.bx += dx
                            self.by += dy
                elif over_sprite and pressed and not self.was_pressed:
                    self.drag = (mx - wx, my - wy, mx, my)
                self.was_pressed = pressed
            except Exception:
                pass
            time.sleep(0.03)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Proxy)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    api = Api()
    screen = webview.screens[0]
    saved = None if "LULU_X" in os.environ else load_pos(screen)
    sx = int(os.environ.get("LULU_X", saved[0] if saved else screen.width - SPRITE_W - 12))
    sy = int(os.environ.get("LULU_Y", saved[1] if saved else screen.height - SPRITE_H - 60))

    sprite_win = webview.create_window(
        "噜噜",
        f"http://127.0.0.1:{PORT}/pet.html?role=sprite&v={int(time.time())}&pet={PET_ID}",
        width=SPRITE_W, height=SPRITE_H,
        x=sx, y=sy,
        frameless=True,
        transparent=True,
        on_top=True,
        easy_drag=False,
        js_api=api,
    )
    bubble_win = webview.create_window(
        "噜噜气泡",
        f"http://127.0.0.1:{PORT}/pet.html?role=bubble&v={int(time.time())}&pet={PET_ID}",
        width=BUBBLE_W, height=BUBBLE_H,
        x=sx + (SPRITE_W - BUBBLE_W) // 2, y=sy - BUBBLE_H - 6,
        frameless=True,
        transparent=True,
        on_top=True,
        easy_drag=False,
        js_api=None,
    )
    api.windows = [sprite_win, bubble_win]

    tracker = DragTracker(sprite_win, bubble_win, screen.height,
                          on_save=lambda: save_pos(sprite_win, bubble_win, screen))

    def report():
        save_pos(sprite_win, bubble_win, screen)
        # 主线程：气泡窗永远穿透；两个窗口都从屏幕截取中排除
        try:
            from AppKit import NSApp
            for w in NSApp.windows():
                try:
                    title = w.title()
                    if title == "噜噜气泡":
                        w.setIgnoresMouseEvents_(True)
                    if title in ("噜噜", "噜噜气泡"):
                        w.setSharingType_(0)  # NSWindowSharingNone：截图隐身
                except Exception:
                    continue
        except Exception:
            pass
        tracker.start()

    try:
        webview.start(func=report, debug=False)
    finally:
        tracker.stop()
        server.shutdown()


if __name__ == "__main__":
    main()
