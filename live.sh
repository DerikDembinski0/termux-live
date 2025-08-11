#!/bin/bash
echo "🚀 Iniciando servidor proxy..."

# Mata processos anteriores na porta 8080
pkill -f "python.*8080" 2>/dev/null

python3 -c "
import http.server
import urllib.request
import urllib.error

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        print(f'Requisição recebida: {self.path}')
        
        if self.path == '/stream.m3u8':
            try:
                # URL original
                url = 'https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8'
                
                # Criar requisição com headers
                req = urllib.request.Request(url)
                req.add_header('Referer', 'https://www.weekseries.info/')
                req.add_header('Origin', 'https://www.weekseries.info')
                req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36')
                
                print('Fazendo requisição para o stream...')
                response = urllib.request.urlopen(req, timeout=10)
                
                # Retornar conteúdo
                self.send_response(200)
                self.send_header('Content-Type', 'application/vnd.apple.mpegurl')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                content = response.read()
                self.wfile.write(content)
                print('Stream redirecionado com sucesso!')
                
            except urllib.error.HTTPError as e:
                print(f'Erro HTTP: {e.code} - {e.reason}')
                self.send_error(e.code, f'Erro no stream: {e.reason}')
            except Exception as e:
                print(f'Erro: {e}')
                self.send_error(500, f'Erro interno: {str(e)}')
        else:
            self.send_error(404, 'Página não encontrada')

    def log_message(self, format, *args):
        print(f'{self.address_string()} - {format%args}')

try:
    server = http.server.HTTPServer(('0.0.0.0', 8080), ProxyHandler)
    print('')
    print('🎬 SERVIDOR PROXY ATIVO!')
    print('═══════════════════════════════════════')
    print('URL LOCAL: http://127.0.0.1:8080/stream.m3u8')
    print('═══════════════════════════════════════')
    print('1. Copie a URL acima')
    print('2. Abra no VLC ou Browser')
    print('3. Ctrl+C para parar o servidor')
    print('')
    server.serve_forever()
except KeyboardInterrupt:
    print('\\nServidor parado!')
except Exception as e:
    print(f'Erro ao iniciar servidor: {e}')
"
