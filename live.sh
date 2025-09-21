#!/data/data/com.termux/files/usr/bin/bash
set -e

# ====== CONFIG ======
URL="https://beautifulpeople.goodcdn.cf/globo-sp/tracks-v1a1/mono.ts.m3u8"
HOST="beautifulpeople.goodcdn.cf"
RESOLVE_IP="172.67.201.5"   # ajuste se mudar
UA="Mozilla/5.0 (Android 14; Termux) AppleWebKit/537.36 (KHTML, like Gecko) Mobile"
REF="https://beautifulpeople.goodcdn.cf/"
HTTP_PORT=8080
# ====================

echo "🔴 Restream HLS -> VLC (FFmpeg + http.server)"

# ---- 1) Garantir DNS resolvendo o HOST ----
echo "🔎 Testando DNS para $HOST ..."
set +e
getent hosts "$HOST" >/dev/null 2>&1 || nslookup "$HOST" >/dev/null 2>&1
DNS_OK=$?
set -e

if [ $DNS_OK -ne 0 ]; then
  echo "⚠️  DNS não resolve. Aplicando patch em $PREFIX/etc/hosts ..."
  HOSTS_FILE="$PREFIX/etc/hosts"
  mkdir -p "$(dirname "$HOSTS_FILE")"
  touch "$HOSTS_FILE"

  # remove linhas antigas do host
  grep -vE "[[:space:]]$HOST(\$|[[:space:]])" "$HOSTS_FILE" > "$HOSTS_FILE.tmp" || true
  mv "$HOSTS_FILE.tmp" "$HOSTS_FILE"

  echo "$RESOLVE_IP $HOST" >> "$HOSTS_FILE"
  echo "✅ Adicionado: $RESOLVE_IP $HOST"
else
  echo "✅ DNS ok para $HOST"
fi

# ---- 2) Servidor HTTP local para tocar no VLC ----
mkdir -p hls
pkill -f "python3 -m http.server ${HTTP_PORT}" >/dev/null 2>&1 || true
(cd hls && nohup python3 -m http.server ${HTTP_PORT} >/dev/null 2>&1 &)
sleep 2

# ---- 3) Rodar FFmpeg puxando do .m3u8 remoto ----
echo "▶️  Iniciando FFmpeg…"
set +e
ffmpeg \
-user_agent "$UA" \
-headers "Referer: $REF\r\nOrigin: $REF" \
-i "$URL" \
-c:v copy -c:a copy \
-f hls \
-hls_time 4 \
-hls_list_size 5 \
-hls_flags delete_segments \
-hls_segment_filename "hls/seg-%03d.ts" \
"hls/playlist.m3u8" &
PID=$!
set -e

sleep 3
if ps -p $PID >/dev/null 2>&1; then
  echo "✅ FFmpeg ativo (gravando em hls/playlist.m3u8)."
  termux-open-url "http://127.0.0.1:${HTTP_PORT}/playlist.m3u8"
else
  echo "❌ FFmpeg não iniciou. Mostrando últimas linhas de log:"
  tail -n 60 -f /dev/null  # ajuste se estiver rodando em outro wrapper de log
fi
