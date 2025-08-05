#!/data/data/com.termux/files/usr/bin/bash

# Título informativo no terminal
echo "🔴 Live A&E - FFmpeg + VLC"

# Verifica se a pasta 'hls' existe, senão cria
mkdir -p hls

# Inicia servidor HTTP na pasta 'hls' na porta 8080 em background
cd hls
nohup python3 -m http.server 8080 > /dev/null 2>&1 &
cd ..

# Aguarda o servidor subir
sleep 3

# Inicia o FFmpeg com os headers e grava a playlist no formato HLS
ffmpeg \
-headers "referer: https://embed.embedtv.net/\r\nuser-agent: Mozilla/5.0" \
-i "https://aws.vidfox.cloud/a-e/index.m3u8" \
-c:v copy -c:a copy \
-f hls \
-hls_time 4 \
-hls_list_size 5 \
-hls_flags delete_segments \
-hls_segment_filename hls/seg-%03d.ts \
hls/playlist.m3u8 &

# Aguarda FFmpeg gerar a playlist
sleep 5

# Tenta abrir o VLC apontando para o .m3u8
termux-open-url "http://127.0.0.1:8080/playlist.m3u8"
