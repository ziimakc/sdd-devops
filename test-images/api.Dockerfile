# syntax=docker/dockerfile:1
# @req SCI-ANS-001
# Minimal dummy API image for E2E infrastructure testing
FROM python:3.11-alpine

WORKDIR /app

# Install wget for healthcheck validation
RUN apk add --no-cache wget

# Create simple HTTP server script
RUN cat <<'EOF' > server.py
import http.server
import socketserver
import os

PORT = int(os.environ.get("API_PORT", 8080))

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthcheck":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"healthy"}')
        elif self.path == "/stats":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"total_files":0,"coverage":0,"traceability":0}')
        else:
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()
EOF

# Run as non-root user
RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

CMD ["python", "server.py"]