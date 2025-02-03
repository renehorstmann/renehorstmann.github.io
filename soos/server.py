from http.server import SimpleHTTPRequestHandler
import socketserver

class MyRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        super().end_headers()

with socketserver.TCPServer(("", 8000), MyRequestHandler) as httpd:
    httpd.serve_forever()
