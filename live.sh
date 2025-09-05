# Inicia o FFmpeg com os headers e grava a playlist no formato HLS
ffmpeg \
-headers "referer: https://embed.embedtv.net/\r\nuser-agent: Mozilla/5.0" \
-i "https://aws.vidfox.cloud/globo-sp/index.m3u8" \
-c:v copy -c:a copy \
-f hls \
-hls_time 4 \
@@ -32,3 +32,4 @@ sleep 5
# Abre o link local no navegador padrão (VLC ou browser)
termux-open-url "http://127.0.0.1:8080/playlist.m3u8"
