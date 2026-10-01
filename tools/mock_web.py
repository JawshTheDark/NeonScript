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
import struct
import sys
import threading
import time
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
        elif p == "/file.zip":
            self.send_body("application/zip", b"PK\x05\x06" + b"\0" * 18)
        else:
            self.send_body("text/plain", b"not found", status=404, honour_range=False)
            return

    do_HEAD = do_GET


if __name__ == "__main__":
    srv = ThreadingHTTPServer(("127.0.0.1", PORT), H)
    log("# mock web listening on 127.0.0.1:%d" % PORT)
    srv.serve_forever()
