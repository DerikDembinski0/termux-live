#!/bin/bash
echo "🚀 Iniciando servidor proxy..."

# Mata processos anteriores na porta 8080
pkill -f "python.*8080" 2>/dev/null

python3 - <<'PY'
import http.server, urllib.request, urllib.parse, urllib.error
from urllib.parse import urljoin, urlparse, parse_qs, quote, unquote

PORT = 8080
BASE_URL = 'https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/'
M3U8_NAME = 'stream.m3u8'
HEADERS = {
    'Referer': 'https://www.weekseries.info/',
    'Origin': 'https://www.weekseries.info',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127 Safari/537.36'
}

def fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as r:
        return r.read(), r.getheader('Content-Type') or ''

def guess_ct(path):
    p = path.lower()
    if p.endswith('.m3u8'):
        return 'application/vnd.apple.mpegurl'
    if p.endswith('.ts'):
        return 'video/MP2T'
    if p.endswith('.vtt'):
        return 'text/vtt; charset=utf-8'
    if p.endswith('.key'):
        return 'application/octet-stream'
    return 'application/octet-stream'

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log(self, msg): print(msg, flush=True)

    def do_GET(self):
        path = self.path
        self.log(f"Requisição recebida: {path}")

        # 1) Endpoint local do m3u8
        if path == f'/{M3U8_NAME}':
            try:
                url = urljoin(BASE_URL, M3U8_NAME)
                data, _ = fetch(url)
                text = data.decode('utf-8', errors='ignore')

                # Reescreve URIs (segmentos, chaves, legendas) para passar por /proxy?u=
                out_lines = []
                for line in text.splitlines():
                    if line.startswith('#'):
                        # Trata EXT-X-KEY URI="..."
                        if 'EXT-X-KEY' in line and 'URI=' in line:
                            # extrai valor entre aspas
                            try:
                                before, rest = line.split('URI=', 1)
                                if rest.startswith('"'):
                                    q = rest.split('"')
                                    orig_uri = q[1]
                                    abs_u = urljoin(BASE_URL, orig_uri)
                                    prox = f'/proxy?u={quote(abs_u)}'
                                    line = f'{before}URI="{prox}"' + '"'.join(q[2:])  # mantém o resto, se houver
                            except Exception:
                                pass
                        out_lines.append(line)
                    elif line.strip():
                        # Linha é um URI de mídia (relativo ou absoluto)
                        abs_u = urljoin(BASE_URL, line.strip())
                        prox = f'/proxy?u={quote(abs_u)}'
                        out_lines.append(prox)
                    else:
                        out_lines.append(line)

                body = '\n'.join(out_lines).encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Type', 'application/vnd.apple.mpegurl')
                self.send_header('Cache-Control', 'no-cache')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                self.log("Stream reescrito e servido com sucesso.")
            except Exception as e:
                self.send_error(502, f'Erro ao obter m3u8: {e}')
            return

        # 2) Endpoint genérico de proxy: /proxy?u=<url_absoluta>
        if path.startswith('/proxy'):
            try:
                q = parse_qs(urlparse(path).query)
                target = q.get('u', [''])[0]
                if not target:
                    self.send_error(400, 'Parâmetro u ausente')
                    return
                target = unquote(target)
                data, ct = fetch(target)
                self.send_response(200)
                self.send_header('Content-Type', ct or guess_ct(target))
                self.send_header('Cache-Control', 'no-cache')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except urllib.error.HTTPError as e:
                self.send_error(e.code, f'Origem: {e.reason}')
            except Exception as e:
                self.send_error(502, f'Erro no proxy: {e}')
            return

        # 3) Fallback: se o player pedir /01_000.ts etc., busca relativo ao BASE_URL
        try:
            rel = path.lstrip('/')
            target = urljoin(BASE_URL, rel)
            data, ct = fetch(target)
            self.send_response(200)
            self.send_header('Content-Type', ct or guess_ct(target))
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except urllib.error.HTTPError as e:
            self.send_error(e.code, 'Página não encontrada')
        except Exception as e:
            self.send_error(502, f'Erro: {e}')

if __name__ == '__main__':
    from socketserver import TCPServer
    srv = TCPServer(('', PORT), ProxyHandler)
    print(f"✅ SERVIDOR PROXY ATIVO!\nURL LOCAL: http://127.0.0.1:{PORT}/{M3U8_NAME}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
PY
