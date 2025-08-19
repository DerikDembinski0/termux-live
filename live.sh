#!/bin/bash
set -euo pipefail

PORT=8080
M3U8_NAME="stream.m3u8"
URL="http://127.0.0.1:${PORT}/${M3U8_NAME}"

echo "🚀 Iniciando servidor proxy na porta $PORT..."

# Mata processos anteriores do Python nessa porta
pkill -f "python.*${PORT}" 2>/dev/null || true

# ---------- Servidor Python (proxy HLS) ----------
python3 - <<'PY' &
import http.server, urllib.request, urllib.parse, urllib.error
from urllib.parse import urljoin, urlparse, parse_qs, quote, unquote

PORT = 8080
BASE_URL = 'https://cloud61-l2-userfil21276-2s22-us-cloudfront-net.zumvori.cfd/I/inicia-o-2021/stream/stream.m3u8'
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

        # 1) m3u8 principal (reescreve URIs para /proxy?u=)
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

        # 2) Proxy genérico /proxy?u=<absoluto>
        if path.startswith('/proxy'):
            try:
                q = parse_qs(urlparse(path).query)
                target = q.get('u', [''])[0]
                if not target:
                    self.send_error(400, 'Parâmetro u ausente')
                    return
                target = urllib.parse.unquote(target)
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

        # 3) Fallback: caminho relativo direto
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
    print(f"✅ PROXY ATIVO → http://127.0.0.1:{PORT}/{M3U8_NAME}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
PY

SERVER_PID=$!
trap 'echo "🧹 Encerrando..."; kill $SERVER_PID 2>/dev/null || true' EXIT

# ---------- Aguarda o endpoint responder ----------
echo "⏳ Aguardando $URL ficar disponível..."
for i in {1..30}; do
  if curl -fsS "$URL" >/dev/null; then
    echo "✅ Servidor OK."
    break
  fi
  sleep 0.5
  if [[ $i -eq 30 ]]; then
    echo "❌ Timeout esperando o servidor. Abortando."
    exit 1
  fi
done

# ---------- Abre o chooser no Android (prioriza Termux) ----------
open_ok=false

# 1) Termux (recomendado)
if command -v termux-open-url >/dev/null 2>&1; then
  echo "📱 Abrindo pelo Termux (chooser)..."
  if termux-open-url "$URL"; then
    open_ok=true
  fi
fi

# 2) ADB (fallback)
if [[ "$open_ok" = false ]] && command -v adb >/dev/null 2>&1 && adb get-state 1>/dev/null 2>&1; then
  echo "📱 Abrindo via ADB (chooser forçado)..."
  if adb shell am start -a android.intent.action.VIEW \
        -d "$URL" \
        -t "application/vnd.apple.mpegurl" \
        --chooser 1>/dev/null; then
    open_ok=true
  else
    echo "⚠️ Tentando MIME alternativo..."
    adb shell am start -a android.intent.action.VIEW \
        -d "$URL" \
        -t "application/x-mpegURL" \
        --chooser || true
    open_ok=true
  fi
fi

# 3) Sem Termux/API nem ADB — instrução
if [[ "$open_ok" = false ]]; then
  echo "ℹ️ Não encontrei nem Termux:API (termux-open-url) nem ADB."
  echo "Abra manualmente no celular: $URL"
fi

echo "🎬 Seletor de apps deve aparecer agora. Pressione Ctrl+C para encerrar quando quiser."
wait $SERVER_PID






