#!/bin/bash
# Instala python se não tiver
pkg install python -y

# Cria um servidor local que adiciona os headers
python3 -c "
import http.server
import urllib.request

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/stream.m3u8':
            # Adiciona os headers necessários
            req = urllib.request.Request('https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8')
            req.add_header('referer', 'https://www.weekseries.info/')
            req.add_header('origin', 'https://www.weekseries.info')
            req.add_header('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
            
            try:
                response = urllib.request.urlopen(req)
                self.send_response(200)
                self.send_header('Content-type', 'application/vnd.apple.mpegurl')
                self.end_headers()
                self.wfile.write(response.read())
            except:
                self.send_error(404)
        else:
            self.send_error(404)

server = http.server.HTTPServer(('127.0.0.1', 8080), ProxyHandler)
print('Servidor rodando em: http://127.0.0.1:8080/stream.m3u8')
print('Abra esse link no VLC ou Browser!')
server.serve_forever()
" &

# Aguarda o servidor iniciar
sleep 2

# Tenta abrir com Intent
am start -a android.intent.action.VIEW -d "http://127.0.0.1:8080/stream.m3u8" -t "video/*"
