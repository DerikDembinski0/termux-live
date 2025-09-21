#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ========= CONFIG =========
URL="https://beautifulpeople.goodcdn.cf/globo-sp/tracks-v1a1/mono.ts.m3u8"
HOST="beautifulpeople.goodcdn.cf"
UA="Mozilla/5.0 (Android 14; Termux)"
REF="https://beautifulpeople.goodcdn.cf/"
HTTP_PORT=8080

# Coloque aqui os IPs candidatos do host (primeiro = prioritário).
# O primeiro deve ser o que você viu no DevTools (Remote Address).
IP_CANDIDATES=("172.67.201.5")
# Você pode adicionar mais, ex: IP_CANDIDATES=("172.67.201.5" "104.21.32.100")
# ==========================

say(){ printf '%s\n' "$*" >&2; }

mkdir -p hls
# mata http.server antigo
pkill -f "python3 -m http.server ${HTTP_PORT}" >/dev/null 2>&1 || true
( cd hls && nohup python3 -m http.server "${HTTP_PORT}" >/dev/null 2>&1 & )
sleep 2

fetch_playlist() {
  local ip_opt="$1"
  local curl_args=(-sS --retry 2 --retry-delay 1 -A "$UA" -e "$REF" -L "$URL" -o hls/remote.m3u8)

  if [[ -n "$ip_opt" ]]; then
    # força conectar no IP mas mantendo SNI/Host (TLS válido)
    curl_args=( -sS --retry 2 --retry-delay 1 -A "$UA" -e "$REF" --connect-to "${HOST}:443:${ip_opt}:443" -L "$URL" -o hls/remote.m3u8 )
    say "⬇️  Baixando playlist via IP ${ip_opt} (connect-to)…"
  else
    say "⬇️  Tentando baixar playlist via hostname (se DNS estiver ok)…"
  fi

  if ! curl "${curl_args[@]}"; then
    return 1
  fi

  # precisa conter segmentos .ts
  grep -qE '\.ts($|\?)' hls/remote.m3u8
}

BASE="$(echo "$URL" | sed -E 's@^(https://[^/]+/.*/)[^/]+$@\1@')"

# 1) Tenta com hostname (caso o DNS funcione no seu device)
if fetch_playlist ""; then
  say "✅ Playlist baixada via hostname."
else
  say "⚠️  DNS/hostname falhou. Vou testar IPs fixos…"
  success=0
  for ip in "${IP_CANDIDATES[@]}"; do
    if fetch_playlist "$ip"; then
      say "✅ Playlist baixada via IP ${ip}."
      success=1
      break
    else
      say "❌ Falhou com IP ${ip}. Testando próximo…"
    fi
  done
  [[ $success -eq 1 ]] || { say "❌ Não consegui baixar a playlist com nenhum IP."; exit 1; }
fi

# 2) Reescreve caminhos relativos (.ts/.m3u8) para absolutos
sed -E "
  s@^([^#hH].*\.m3u8)([[:space:]]*)$@${BASE}\1\2@g;
  s@^([^#hH].*\.ts)([[:space:]]*)$@${BASE}\1\2@g;
" hls/remote.m3u8 > hls/fixed.m3u8

# 3) Inicia o FFmpeg lendo a playlist local (mas baixando .ts por HTTPS)
say '▶️  Iniciando FFmpeg…'
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
