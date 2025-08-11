#!/bin/bash
# Tentar abrir com Intent do Android (mostra opções de app)
am start -a android.intent.action.VIEW -d "https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8" -t "video/*"

# Se não funcionar, mostrar a URL para copiar
if [ $? -ne 0 ]; then
    echo "═══════════════════════════════════════════════════════"
    echo "Copie esta URL e cole no VLC ou Browser:"
    echo "https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8"
    echo "═══════════════════════════════════════════════════════"
fi
