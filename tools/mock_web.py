#!/usr/bin/env python3
"""
Tiny local web server used to test NeonScript's link / image previews without touching the internet.

    python mock_web.py [port]            (default 8766, binds to 127.0.0.1 only)

    /page          HTML with <title>, og:title/description/site_name/image, HTML entities, UTF-8
    /minified      the same page as ONE very long line (title appears after 12 KB of padding)
    /image.png     a 300x200 PNG (honours Range)
    /thumb.png     the og:image, 120x90
    /redirect      302 -> /page          /loop   endless redirects
    /to-private    302 -> http://192.168.1.5/admin   (must be refused)
    /big.bin       6 MB of data that ignores Range (the size guard must stop it)
    /file.zip      a small application/zip
    anything else  404
Every request is appended to the log file given as the second argument (optional).
"""
import io
import json
import struct
import sys
import threading
import time
import urllib.parse
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8766
LOG = sys.argv[2] if len(sys.argv) > 2 else None


def png(w, h, rgb):
    """A flat-colour PNG with a lighter diagonal - no Pillow needed."""
    rows = []
    for y in range(h):
        row = bytearray([0])
        for x in range(w):
            on = abs(x - y * w // h) < 6
            row += bytes(min(255, c + 90) if on else c for c in rgb)
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


IMAGE = png(300, 200, (40, 90, 200))
THUMB = png(120, 90, (200, 60, 120))

PAGE = """<!doctype html><html><head><meta charset="utf-8">
<title>Plain title - Tom &amp; Jerry&#39;s café</title>
<meta property="og:title" content="NeonScript &mdash; the 2026 remaster">
<meta property="og:description" content="A full-feature mIRC script pack: toolbar, themes &amp; ranks. Café ✓">
<meta property="og:site_name" content="Neon Example">
<meta content='http://127.0.0.1:%d/thumb.png' property='og:image'>
<meta name="description" content="meta description fallback">
</head><body><h1>hello</h1></body></html>""" % PORT


def log(line):
    if LOG:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *a):
        pass

    def send_body(self, ctype, body, honour_range=True, status=200):
        rng = self.headers.get("Range")
        total = len(body)
        if honour_range and rng and rng.startswith("bytes="):
            a, _, b = rng[6:].partition("-")
            start = int(a or 0)
            end = min(int(b) if b else total - 1, total - 1)
            part = body[start:end + 1]
            self.send_response(206)
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, total))
        else:
            part = body
            self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(part)))
        self.end_headers()
        self.wfile.write(part)

    def do_GET(self):
        log("GET %s Range=%s UA=%s" % (self.path, self.headers.get("Range"), self.headers.get("User-Agent")))
        p = self.path.split("?")[0]
        if p == "/page":
            self.send_body("text/html; charset=utf-8", PAGE.encode("utf-8"))
        elif p == "/minified":
            body = ("<!doctype html><html><head>" + "<!--" + "x" * 12000 + "-->" + PAGE.split("<head>", 1)[1]).replace("\n", "")
            self.send_body("text/html; charset=utf-8", body.encode("utf-8"))
        elif p == "/image.png":
            self.send_body("image/png", IMAGE)
        elif p == "/thumb.png":
            self.send_body("image/png", THUMB)
        elif p == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/page")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif p == "/loop":
            self.send_response(302)
            self.send_header("Location", "/loop?%d" % int(time.time() * 1000))
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif p == "/to-private":
            self.send_response(302)
            self.send_header("Location", "http://192.168.1.5/admin")
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif p == "/big.bin":
            total = 6 * 1024 * 1024
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(total))
            self.end_headers()
            chunk = b"\0" * 65536
            try:
                for _ in range(total // 65536):
                    self.wfile.write(chunk)
                    time.sleep(0.02)
            except OSError:
                pass
        elif p.startswith("/wttr/"):
            city = urllib.parse.unquote(p[6:])
            line = city + "|Partly cloudy|+18°C|+17°C|62%|↑14km/h\n"
            self.send_body("text/plain; charset=utf-8", line.encode("utf-8"), honour_range=False)
        elif p.startswith("/dict/"):
            word = urllib.parse.unquote(p[6:])
            if word == "nothingatall":
                self.send_body("application/json", b'{"title":"No Definitions Found"}', honour_range=False, status=404)
            else:
                doc = ('[{"word":"%s","meanings":[{"partOfSpeech":"noun","definitions":[{"definition":"A chemical element, symbol Ne."},'
                       '{"definition":"A bright \\"glow\\" lamp \\u2014 caf\\u00e9 sign."},{"definition":"Third sense."},{"definition":"Fourth sense."}]},'
                       '{"partOfSpeech":"adjective","definitions":[{"definition":"Brightly coloured."}]}]}]') % word
                self.send_body("application/json", doc.encode("utf-8"), honour_range=False)
        elif p == "/mm":
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            text = q.get("q", [""])[0]
            lang = q.get("langpair", ["|xx"])[0].split("|")[-1]
            tr = "[" + lang + "] " + text + " éñ"
            doc = '{"responseData":{"translatedText":%s},"responseStatus":200}' % json.dumps(tr)
            self.send_body("application/json", doc.encode("utf-8"), honour_range=False)
        elif p == "/file.zip":
            self.send_body("application/zip", b"PK\x05\x06" + b"\0" * 18)
        else:
            self.send_body("text/plain", b"not found", status=404, honour_range=False)
            return

    def do_POST(self):
        """A stand-in LLM service: /api/chat (Ollama), /v1/chat/completions (OpenAI), /v1/messages (Anthropic)."""
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n) if n else b""
        p = self.path.split("?")[0]
        log("POST %s len=%d ctype=%s auth=%s xkey=%s ver=%s" % (
            p, n, self.headers.get("Content-Type"), self.headers.get("Authorization"),
            self.headers.get("x-api-key"), self.headers.get("anthropic-version")))
        try:
            req = json.loads(raw.decode("utf-8"))
        except Exception as exc:  # the test wants to know when the body is not valid JSON
            log("BADJSON %s" % exc)
            self.send_body("application/json", json.dumps({"error": "bad json"}).encode(), honour_range=False, status=400)
            return
        if p == "/v1/messages":
            system = req.get("system", "")
            user = req["messages"][-1]["content"]
        else:
            msgs = req.get("messages", [])
            system = msgs[0]["content"] if msgs and msgs[0]["role"] == "system" else ""
            user = msgs[-1]["content"] if msgs else ""
        log("MODEL %s" % req.get("model"))
        log("OPTIONS %s" % json.dumps(req.get("options")))
        log("SYSTEM %s" % system.replace("\n", "\\n"))
        log("USER %s" % user.replace("\n", "\\n"))
        if p == "/v1/chat/completions" and self.headers.get("Authorization") != "Bearer sk-test-123":
            body = {"error": {"message": "Incorrect API key provided.", "type": "invalid_request_error"}}
            self.send_body("application/json", json.dumps(body).encode(), honour_range=False, status=401)
            return
        if "nosuchmodel" in req.get("model", ""):
            self.send_body("application/json", json.dumps({"error": "model 'nosuchmodel' not found"}).encode(), honour_range=False, status=404)
            return
        # canned answers keyed on what the system prompt asks for; they echo pseudonyms so de-anonymising can be checked
        if "exactly one word" in system:
            ans = "ok"
        elif "summarise IRC chat" in system:
            ans = ("The channel talked about the new release.\nUser2 asked whether it works on Windows 11 and User3 said yes.\n"
                   "Still open: User1 wants a download link for \"the beta\" (a path like C:\\tmp\\x).\nUnicode: caf\u00e9 \u2713 and a $dollar and %percent and | pipe.")
        elif "summarise a person" in system:
            ans = "Two people need you:\nUser1 asked you about the logo in #design.\nUrgent: User2 in #ops."
        elif "Translate" in system:
            ans = "Hola, esto es una prueba, con comas."
        elif "volunteer IRC channel moderator" in system:
            ans = "User2 - repeated the same line 5 times - warn\nUser4 - advertising a link - kick"
        elif "turn a channel operator" in system:
            if "hostile" in user:
                cmds = ["/kick Kira $me spam", "/msg #neon hello | /quit", "/kick #other Kira", "/kick Kira %x", "/neon mass kick * -y", "/join #evil", "/kick Kira flooding"]
            else:
                cmds = ["/kick Kira flooding", "/neon quiet Zed 10m spam", "/mode #neon +m"]
            ans = "```json\n" + json.dumps({"commands": cmds, "say": "Done as asked."}) + "\n```"
        else:
            ans = "I do not know."
        if p == "/api/chat":
            out = {"model": req.get("model"), "created_at": "2026-01-01T00:00:00Z", "message": {"role": "assistant", "content": ans}, "done": True,
                   "total_duration": 123456789, "load_duration": 1234567, "prompt_eval_count": 26, "eval_count": 298}
        elif p == "/v1/messages":
            out = {"id": "msg_01", "type": "message", "role": "assistant", "content": [{"type": "text", "text": ans}], "model": req.get("model"),
                   "stop_reason": "end_turn", "usage": {"input_tokens": 10, "output_tokens": 5}}
        elif p == "/v1/chat/completions":
            out = {"id": "chatcmpl-1", "object": "chat.completion", "choices": [{"index": 0, "message": {"role": "assistant", "content": ans}, "finish_reason": "stop"}],
                   "usage": {"prompt_tokens": 9, "completion_tokens": 12}}
        else:
            self.send_body("text/plain", b"not found", status=404, honour_range=False)
            return
        self.send_body("application/json", json.dumps(out).encode("utf-8"), honour_range=False)

    do_HEAD = do_GET


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    log("# mock web listening on 127.0.0.1:%d" % PORT)
    srv.serve_forever()
