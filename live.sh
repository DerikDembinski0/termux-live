#!/usr/bin/env bash
set -euo pipefail

# ▶️ HLS local a partir de um M3U8 legal/sem DRM
M3U8_URL="https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8"

HEADERS="${HEADERS:-}"

echo "▶️ Iniciando pipeline FFmpeg → HLS local"
command -v ffmpeg >/dev/null || { echo "[X] ffmpeg não encontrado"; exit 1; }
command -v python3 >/dev/null || { echo "[X] python3 não encontrado"; exit 1; }

mkdir -p hls

cleanup() {
  echo "⏹️ Encerrando processos..."
  pkill -f "python3 -m http.server 8080" || true
  pkill -f "ffmpeg .* hls/playlist.m3u8" || true
}
trap cleanup EXIT

# Inicia servidor HTTP local na porta 8080
(cd hls && nohup python3 -m http.server 8080 >/dev/null 2>&1 &)
sleep 2

HDR_ARGS=()
if [[ -n "$HEADERS" ]]; then
  HDR_ARGS=(-headers "$HEADERS")
fi

# Inicia FFmpeg para gerar o HLS local
ffmpeg "${HDR_ARGS[@]}" \
  -i "$M3U8_URL" \
  -c:v copy -c:a copy \
  -f hls \
  -hls_time 4 \
  -hls_list_size 6 \
  -hls_flags delete_segments+independent_segments \
  -hls_segment_filename "hls/seg-%03d.ts" \
  "hls/playlist.m3u8" \
  >/dev/null 2>&1 &

# Aguarda gerar os primeiros segmentos
sleep 5

# URL local do stream
LOCAL_URL="http://127.0.0.1:8080/playlist.m3u8"

# Abre direto no player disponível
if command -v mpv >/dev/null; then
  echo "🎬 Abrindo no MPV..."
  nohup mpv "$LOCAL_URL" >/dev/null 2>&1 &
elif command -v vlc >/dev/null; then
  echo "🎬 Abrindo no VLC..."
  nohup vlc "$LOCAL_URL" >/dev/null 2>&1 &
elif command -v termux-open-url >/dev/null; then
  echo "🌐 Abrindo no navegador..."
  termux-open-url "$LOCAL_URL"
else
  echo "Abra manualmente no player: $LOCAL_URL"
fi

# Mantém rodando enquanto o ffmpeg estiver ativo
wait
