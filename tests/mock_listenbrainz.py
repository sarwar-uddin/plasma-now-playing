#!/usr/bin/env python3
"""Fake ListenBrainz API: logs each POST body as a JSON line to argv[2]."""
import sys, json
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        with open(sys.argv[2], "a") as f:
            f.write(json.dumps({"path": self.path, "auth": self.headers["Authorization"], "body": json.loads(body)}) + "\n")
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(b'{"status":"ok"}')
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
