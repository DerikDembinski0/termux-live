#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ===== CONFIG =====
URL="https://beautifulpeople.goodcdn.cf/globo-sp/tracks-v1a1/mono.ts.m3u8"
HOST="beautifulpeople.goodcdn.cf"
UA="Mozilla/5.0 (Android 14; Termux)"
REF="https://beautifulpeople.goodcdn.cf/"
HTTP_PORT=8080
# ==================

say(){ printf '%s\n' "$*" >&2; }

# --- Resolve IP via DNS-over-HTTPS Cloudflare ---
say "🔎 Resolvendo IP para $HOST via 1.1.1.1 (DoH)..."
IP="$(curl -s "https://1.1.1.1/dns-query?name=${HOST}&type=A" \
  -H 'accept: application/dns-json' \
  | grep -oE '"data":"([0-9]{1,3}\.){3}[0-9]{1,3}"' \
  | head -1 \
  | cut -d'"' -f4)"

if [[ -z "${IP:-}" ]]; then
  say "❌ Falha ao resolver IP."
  exit 1
fi
say "✅ IP encontrado: $IP"

# --- Preparar diretório e servidor local ---
mkdir -p hls
pkill -f "python3 -m http.server ${HTTP_PORT}" >/dev/null 2>&1 || true
( cd hls && nohup python3 -m http.server "${HTTP_PORT}" >/dev/null 2>&1 & )
sleep 2

# --- Baixar playlist .m3u8 ---
say "⬇️ Baixando playlist..."
curl -sS \
  -A "$UA" -e "$REF" \
  --connect-to "${HOST}:443:${IP}:443" \
  -L "$URL" -o hls/remote.m3u8

if ! grep -q '\.ts' hls/remote.m3u8; then
  say "❌ Playlist não contém .ts. Conteúdo inicial:"
  head -n 20 hls/remote.m3u8
  exit 1
fi

# --- Corrigir caminhos relativos ---
BASE="$(echo "$URL" | sed -E 's@^(https://[^/]+/.*/)[^/]+$@\1@')"
sed -E "s@^([^#hH].*\.ts)@$BASE\1@g" hls/remote.m3u8 > hls/fixed.m3u8

# --- Rodar FFmpeg ---
say "▶️ Iniciando FFmpeg..."
ffmpeg \
  -user_agent "$UA" \
  -headers "Referer: $REF\r\nHost: $HOST\r\n" \
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
say "✅ FFmpeg rodando. Abrindo no player..."
termux-open-url "http://127.0.0.1:${HTTP_PORT}/playlist.m3u8"
