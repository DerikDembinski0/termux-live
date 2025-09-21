#!/data/data/com.termux/files/usr/bin/bash
set -e

# ====== CONFIG ======
URL="https://beautifulpeople.goodcdn.cf/globo-sp/tracks-v1a1/mono.ts.m3u8"
HOST="beautifulpeople.goodcdn.cf"
# Se precisar forçar IP (DNS problem), use o IP que viu no DevTools:
RESOLVE_IP="172.67.201.5"   # ajuste se mudar
UA="Mozilla/5.0 (Android 14; Termux) AppleWebKit/537.36 (KHTML, like Gecko) Mobile"
REF="https://beautifulpeople.goodcdn.cf/"
# ====================

echo "🔴 Restream HLS -> VLC (FFmpeg + http.server)"

mkdir -p hls
cd hls
# Sobe um HTTP local para o VLC abrir
pkill -f "python3 -m http.server 8080" >/dev/null 2>&1 || true
nohup python3 -m http.server 8080 >/dev/null 2>&1 &
cd ..

sleep 2

# Função para abrir no VLC/navegador
open_local() {
  sleep 3
  termux-open-url "http://127.0.0.1:8080/playlist.m3u8"
}

# ===== Tentativa A: direto da URL =====
echo "▶️  Tentando direto com FFmpeg…"
set +e
ffmpeg \
-user_agent "$UA" \
-headers "Referer: $REF\r\nOrigin: $REF" \
-i "$URL" \
-c:v copy -c:a copy \
-f hls -hls_time 4 -hls_list_size 5 \
-hls_flags delete_segments \
-hls_segment_filename "hls/seg-%03d.ts" \
"hls/playlist.m3u8" &
PID_FFMPEG=$!
set -e

sleep 3
if ps -p $PID_FFMPEG >/dev/null 2>&1; then
  echo "✅ FFmpeg rodando (modo direto)."
  open_local
  exit 0
else
  echo "⚠️  Direto falhou. Tentando fallback com --resolve…"
fi

# ===== Tentativa B: fallback com curl --resolve + reescrita =====
# 1) Baixa o m3u8 mantendo o host correto mas forçando IP
curl -A "$UA" -e "$REF" \
  --resolve "$HOST:443:$RESOLVE_IP" \
  -L "$URL" -o "hls/remote.m3u8"

# 2) Descobre a base URL (tudo antes do último '/')
BASE="$(echo "$URL" | sed -E 's@^(https://[^/]+/.*/)[^/]+$@\1@')"

# 3) Reescreve linhas que terminam com .m3u8 ou .ts para absolutas
# (Se o arquivo já tiver URLs absolutas, isso não atrapalha)
sed -E "s@^([^#].*\.m3u8)@$BASE\1@g; s@^([^#].*\.ts)@$BASE\1@g" "hls/remote.m3u8" > "hls/fixed.m3u8"

# 4) Roda o FFmpeg a partir do m3u8 local (permitindo https na playlist)
ffmpeg \
-user_agent "$UA" \
-headers "Referer: $REF\r\nOrigin: $REF" \
-protocol_whitelist "file,crypto,http,https,tcp,tls" \
-i "hls/fixed.m3u8" \
-c:v copy -c:a copy \
-f hls -hls_time 4 -hls_list_size 5 \
-hls_flags delete_segments \
-hls_segment_filename "hls/seg-%03d.ts" \
"hls/playlist.m3u8" &
sleep 3
echo "✅ FFmpeg rodando (modo fallback)."
open_local
