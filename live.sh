#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ===== CONFIG =====
URL="https://beautifulpeople.goodcdn.cf/globo-sp/tracks-v1a1/mono.ts.m3u8"
HOST="beautifulpeople.goodcdn.cf"
UA="Mozilla/5.0 (Android 14; Termux)"
REF="https://beautifulpeople.goodcdn.cf/"
HTTP_PORT=8080
# ==================

say() { printf '%s\n' "$*" >&2; }

# --- Resolve IP via DoH (Cloudflare 1.1.1.1, sem usar DNS do sistema) ---
resolve_ip() {
  local host="$1"
  # Cloudflare DoH retorna JSON; pegamos o primeiro A
  # Ex.: https://1.1.1.1/dns-query?name=example.com&type=A
  local json
  json="$(curl -s --retry 3 --retry-delay 1 \
    -H 'accept: application/dns-json' \
    "https://1.1.1.1/dns-query?name=${host}&type=A")" || return 1

  # Extrai o primeiro "data":"x.x.x.x"
  echo "$json" | grep -oE '"data":"([0-9]{1,3}\.){3}[0-9]{1,3}"' | head -1 | sed 's/.*"data":"\([^"]*\)".*/\1/'
}

say "🔎 Resolvendo IP para $HOST via DoH (Cloudflare)…"
IP="$(resolve_ip "$HOST" || true)"

if [[ -z "${IP:-}" ]]; then
  say "❌ Falha ao resolver via DoH. Abortei."
  exit 1
fi
say "✅ IP: $IP"

# --- Preparação de pastas / server local ---
mkdir -p hls
# derruba http.server antigo se houver
pkill -f "python3 -m http.server ${HTTP_PORT}" >/dev/null 2>&1 || true
( cd hls && nohup python3 -m http.server "${HTTP_PORT}" >/dev/null 2>&1 & )
sleep 2

# --- Baixa a playlist forçando conectar no IP, mantendo SNI/Host ---
# Usamos --connect-to para não depender de DNS e ainda manter o Host/SNI corretos
say "⬇️  Baixando playlist com curl --connect-to (bypass DNS, SNI ok)…"
curl -sS --retry 3 --retry-delay 1 \
  -A "$UA" -e "$REF" \
  --connect-to "${HOST}:443:${IP}:443" \
  -L "$URL" -o hls/remote.m3u8

# Validação simples
if ! grep -qE '\.ts($|\?)' hls/remote.m3u8; then
  say "❌ Playlist baixada não parece conter segmentos .ts. Conteúdo:"
  head -n 50 hls/remote.m3u8 >&2
  exit 1
fi

# --- Constrói BASE (prefixo absoluto) e reescreve caminhos relativos ---
BASE="$(echo "$URL" | sed -E 's@^(https://[^/]+/.*/)[^/]+$@\1@')"
# Reescreve linhas não-comentadas que terminam com .m3u8 ou .ts para URLs absolutas,
# sem alterar linhas que já são absolutas (começam com http)
sed -E "
  s@^([^#hH].*\.m3u8)([[:space:]]*)$@${BASE}\1\2@g;
  s@^([^#hH].*\.ts)([[:space:]]*)$@${BASE}\1\2@g;
" hls/remote.m3u8 > hls/fixed.m3u8

# --- Inicia o FFmpeg lendo a playlist local (mas puxando os .ts por HTTPS) ---
say "▶️  Iniciando FFmpeg…"
ffmpeg \
  -user_agent "$UA" \
  -headers "Referer: $REF\r\nHost: $HOST\r\nOrigin: $REF\r\n" \
  -protocol_whitelist "file,crypto,http,https,tcp,tls" \
  -i "hls/fixed.m3u8" \
  -c:v copy -c:a copy \
  -f hls \
  -hls_time 4 \
  -hls_list_size 5 \
  -hls_flags delete_segments \
  -hls_segment_filename "hls/seg-%03d.ts" \
  "hls/playlist.m3u8" &

sleep 3
say "✅ FFmpeg rodando. Abrindo no player…"
termux-open-url "http://127.0.0.1:${HTTP_PORT}/playlist.m3u8"
