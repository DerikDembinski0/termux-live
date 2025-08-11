#!/bin/bash
set -euo pipefail

PORT=8080
M3U8_NAME="stream.m3u8"

echo "🚀 Iniciando servidor proxy na porta $PORT..."

# Mata processos anteriores na porta 8080
pkill -f "python.*${PORT}" 2>/dev/null || true

# ---- Servidor Python (proxy HLS) ----
python3 - <<'PY' &
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

        # m3u8 principal
        if path == f'/{M3U8_NAME}':
            try:
                url = urljoin(BASE_URL, M3U8_NAME)
                data, _ = fetch(url)
                text = data.decode('utf-8', errors='ignore')

                out_lines = []
                for line in text.splitlines():
                    if line.startswith('#'):
                        if 'EXT-X-KEY' in line and 'URI=' in line:
                            try:
                                before, rest = line.split('URI=', 1)
                                if rest.startswith('"'):
                                    q = rest.split('"')
                                    orig_uri = q[1]
                                    abs_u = urljoin(BASE_URL, orig_uri)
                                    prox = f'/proxy?u={quote(abs_u)}'
                                    line = f'{before}URI="{prox}"' + '"'.join(q[2:])
                            except Exception:
                                pass
                        out_lines.append(line)
                    elif line.strip():
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

        # Proxy genérico
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

        # Fallback: segmentos diretos
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
    print(f"✅ SERVIDOR PROXY ATIVO! URL: http://127.0.0.1:{PORT}/{M3U8_NAME}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
PY

SERVER_PID=$!
trap 'echo "🧹 Encerrando..."; kill $SERVER_PID 2>/dev/null || true' EXIT

# ---- Aguarda o servidor responder ao m3u8 ----
echo "⏳ Aguardando http://127.0.0.1:${PORT}/${M3U8_NAME} ficar disponível..."
for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${PORT}/${M3U8_NAME}" >/dev/null; then
    echo "✅ Servidor OK."
    break
  fi
  sleep 0.5
  if [[ $i -eq 30 ]]; then
    echo "❌ Timeout esperando o servidor. Abortando."
    exit 1
  fi
done

# ---- Verificações de ADB/Dispositivo ----
if ! command -v adb >/dev/null 2>&1; then
  echo "❌ adb não encontrado no PATH. Instale o Android Platform Tools."
  exit 1
fi

if ! adb get-state 1>/dev/null 2>&1; then
  echo "❌ Nenhum dispositivo ADB detectado. Conecte/autorize o telefone e tente de novo."
  exit 1
fi

# ---- Força o popup “Abrir com…” no Android ----
echo "📱 Abrindo chooser no Android para o HLS..."
if ! adb shell am start -a android.intent.action.VIEW \
   -d "http://127.0.0.1:${PORT}/${M3U8_NAME}" \
   -t "application/vnd.apple.mpegurl" \
   --chooser 1>/dev/null; then
  echo "⚠️ Falhou com application/vnd.apple.mpegurl, tentando application/x-mpegURL..."
  adb shell am start -a android.intent.action.VIEW \
     -d "http://127.0.0.1:${PORT}/${M3U8_NAME}" \
     -t "application/x-mpegURL" \
     --chooser
fi

echo "🎬 Seletor de apps aberto. Escolha o player."
wait $SERVER_PID
