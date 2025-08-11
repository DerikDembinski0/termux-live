#!/bin/bash

# Cores para o terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# URL do stream
STREAM_URL="https://cdn001.sytrano.cfd/C/chefe-de-guerra-2025/01-temporada/01/stream.m3u8"

# Headers necessários
HEADERS="referer: https://www.weekseries.info/\r\norigin: https://www.weekseries.info\r\nuser-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36"

# Função para limpar a tela
clear_screen() {
    clear
}

# Função para exibir o menu
show_menu() {
    clear_screen
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    M3U8 PLAYER INTERFACE                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    echo -e "${GREEN}[1]${NC} ▶️  Reproduzir Stream"
    echo -e "${YELLOW}[2]${NC} ⚙️  Opções de Reprodução"  
    echo -e "${BLUE}[3]${NC} 📺 Reproduzir em Tela Cheia"
    echo -e "${PURPLE}[4]${NC} 🔊 Reproduzir com Volume Específico"
    echo -e "${CYAN}[5]${NC} 🎬 Reproduzir com Qualidade Específica"
    echo -e "${RED}[6]${NC} ❌ Sair"
    echo
}

# Função para exibir controles
show_controls() {
    echo -e "${YELLOW}🎮 CONTROLES DO PLAYER:${NC}"
    echo "───────────────────────────────────────"
    echo "ESPAÇO     - Play/Pause"
    echo "↑↓         - Volume +/-"  
    echo "←→         - Retroceder/Avançar 10s"
    echo "F          - Tela cheia"
    echo "Q ou ESC   - Fechar player"
    echo "───────────────────────────────────────"
    echo
}

# Função para reprodução normal
play_normal() {
    clear_screen
    echo -e "${GREEN}▶️ Iniciando reprodução...${NC}"
    echo
    show_controls
    read -p "Pressione ENTER para continuar..."
    
    ffplay -headers "$HEADERS" \
           -window_title "Chefe de Guerra - Episódio 01" \
           -autoexit "$STREAM_URL"
    
    echo
    echo -e "${GREEN}✅ Reprodução finalizada!${NC}"
    read -p "Pressione ENTER para continuar..."
}

# Função para mostrar opções
show_options() {
    clear_screen
    echo -e "${YELLOW}⚙️ OPÇÕES DE REPRODUÇÃO${NC}"
    echo "────────────────────────────────────"
    echo
    echo "Opções disponíveis para FFplay:"
    echo "• -fs : Iniciar em tela cheia"
    echo "• -volume 50 : Definir volume (0-100)"
    echo "• -vf scale=1280:720 : Redimensionar vídeo"
    echo "• -loop 0 : Loop infinito"
    echo "• -ss 00:30 : Pular para 30 segundos"
    echo
    read -p "Pressione ENTER para voltar..."
}

# Função para tela cheia
play_fullscreen() {
    clear_screen
    echo -e "${BLUE}📺 Reproduzindo em TELA CHEIA...${NC}"
    echo "Pressione ESC ou Q para sair da tela cheia"
    read -p "Pressione ENTER para continuar..."
    
    ffplay -fs \
           -headers "$HEADERS" \
           -window_title "Chefe de Guerra - Tela Cheia" \
           -autoexit "$STREAM_URL"
    
    echo -e "${GREEN}✅ Reprodução finalizada!${NC}"
    read -p "Pressione ENTER para continuar..."
}

# Função para volume específico
play_with_volume() {
    clear_screen
    echo -e "${PURPLE}🔊 CONTROLE DE VOLUME${NC}"
    read -p "Digite o volume desejado (0-100): " vol
    
    # Define volume padrão se não foi informado
    if [ -z "$vol" ]; then
        vol=50
    fi
    
    echo "Iniciando com volume $vol..."
    read -p "Pressione ENTER para continuar..."
    
    ffplay -volume "$vol" \
           -headers "$HEADERS" \
           -window_title "Chefe de Guerra - Vol: $vol" \
           -autoexit "$STREAM_URL"
    
    echo -e "${GREEN}✅ Reprodução finalizada!${NC}"
    read -p "Pressione ENTER para continuar..."
}

# Função para qualidade específica
play_with_quality() {
    clear_screen
    echo -e "${CYAN}🎬 OPÇÕES DE QUALIDADE${NC}"
    echo "─────────────────────────────────"
    echo "[1] 480p  (854x480)"
    echo "[2] 720p  (1280x720)" 
    echo "[3] 1080p (1920x1080)"
    echo "[4] Original"
    echo
    read -p "Escolha a qualidade (1-4): " qual
    
    case $qual in
        1)
            resolution="-vf scale=854:480"
            ;;
        2)
            resolution="-vf scale=1280:720"
            ;;
        3)
            resolution="-vf scale=1920:1080"
            ;;
        4)
            resolution=""
            ;;
        *)
            resolution=""
            ;;
    esac
    
    echo "Iniciando reprodução..."
    read -p "Pressione ENTER para continuar..."
    
    ffplay $resolution \
           -headers "$HEADERS" \
           -window_title "Chefe de Guerra" \
           -autoexit "$STREAM_URL"
    
    echo -e "${GREEN}✅ Reprodução finalizada!${NC}"
    read -p "Pressione ENTER para continuar..."
}

# Função principal
main() {
    # Verifica se o ffplay está instalado
    if ! command -v ffplay &> /dev/null; then
        echo -e "${RED}❌ ERRO: ffplay não encontrado!${NC}"
        echo "Instale o FFmpeg primeiro:"
        echo "• Ubuntu/Debian: sudo apt install ffmpeg"
        echo "• macOS: brew install ffmpeg"
        echo "• Arch: sudo pacman -S ffmpeg"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Escolha uma opção (1-6): " opcao
        
        case $opcao in
            1)
                play_normal
                ;;
            2)
                show_options
                ;;
            3)
                play_fullscreen
                ;;
            4)
                play_with_volume
                ;;
            5)
                play_with_quality
                ;;
            6)
                clear_screen
                echo
                echo -e "${GREEN}👋 Obrigado por usar o M3U8 Player!${NC}"
                echo
                exit 0
                ;;
            *)
                echo -e "${RED}Opção inválida!${NC}"
                read -p "Pressione ENTER para continuar..."
                ;;
        esac
    done
}

# Executar o script
main
