#!/bin/bash

TOTAL_STEPS=9
CURRENT_STEP=0

show_progress() {
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo "Progresso: [${PERCENT}%] - $1"
}

error_exit() {
    echo -e "\nErro: $1"
    exit 1
}

increment_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
}

if [ "$EUID" -ne 0 ]; then
    error_exit "EXECUTE COMO ROOT"
else
    clear
    show_progress "Atualizando repositorios..."
    export DEBIAN_FRONTEND=noninteractive
    apt update -y &> /dev/null || error_exit "Falha ao atualizar os repositorios"
    increment_step

    # ---->>>> Verificação do sistema
    show_progress "Verificando o sistema..."
    if ! command -v lsb_release &> /dev/null; then
        apt install lsb-release -y &> /dev/null || error_exit "Falha ao instalar lsb-release"
    fi
    increment_step

    # ---->>>> Verificação do sistema
    OS_NAME=$(lsb_release -is)
    VERSION=$(lsb_release -rs)

    case $OS_NAME in
        Ubuntu)
            case $VERSION in
                24.*|22.*|20.*|18.*)
                    show_progress "Sistema Ubuntu suportado, continuando..."
                    ;;
                *)
                    error_exit "Versão do Ubuntu não suportada. Use 18, 20, 22 ou 24."
                    ;;
            esac
            ;;
        Debian)
            case $VERSION in
                12*|11*|10*|9*)
                    show_progress "Sistema Debian suportado, continuando..."
                    ;;
                *)
                    error_exit "Versão do Debian não suportada. Use 9, 10, 11 ou 12."
                    ;;
            esac
            ;;
        *)
            error_exit "Sistema não suportado. Use Ubuntu ou Debian."
            ;;
    esac
    increment_step

    # ---->>>> Instalação de pacotes requisitos e atualização do sistema
    show_progress "Atualizando o sistema..."
    apt upgrade -y > /dev/null 2>&1 || error_exit "Falha ao atualizar o sistema"
    apt-get install curl build-essential git -y > /dev/null 2>&1 || error_exit "Falha ao instalar pacotes"
    increment_step

    # ---->>>> Criando o diretório do script
	if [ ! -f /opt/rustyssl ]; then
    show_progress "CRIANDO DIRETÓRIO..."
    mkdir -p /opt/rustyssl > /dev/null 2>&1
    fi
	increment_step

    # ---->>>> Instalar rust
    show_progress "VERIFICANDO RUST..."
    if ! command -v rustc &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1 || error_exit "Falha ao instalar Rust"
        echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
        echo 'source "$HOME/.cargo/env"' >> ~/.zshrc
        source "$HOME/.cargo/env"
    fi
    increment_step

    # ---->>>> Instalar o RustyProxySSL
    show_progress "Compilando, isso pode levar algum tempo dependendo da maquina..."

    if [ -d "/root/RustySSL" ]; then
        rm -rf /root/RustySSL
    fi

    git clone --branch "main" https://github.com/vmell0/RustySSL.git /root/RustySSL > /dev/null 2>&1 || error_exit "Falha ao clonar"
    mv /root/RustySSL/menu.sh /opt/rustyssl/menu
    mv /root/RustySSL/Utils/cert.pem /opt/rustyssl/cert.pem
    mv /root/RustySSL/Utils/key.pem /opt/rustyssl/key.pem
    cd /root/RustySSL/RustyProxy
    cargo build --release --jobs $(nproc) > /dev/null 2>&1 || error_exit "Falha ao compilar"
    mv ./target/release/RustySSL /opt/rustyssl/multissl
    increment_step

    # ---->>>> Configuração de permissões
    show_progress "Configurando permissões..."
    chmod +x /opt/rustyssl/multissl
    chmod +x /opt/rustyssl/menu
	chmod +x /opt/rustyssl/cert.pem
	chmod +x /opt/rustyssl/key.pem
    ln -sf /opt/rustyssl/menu /usr/local/bin/menussl
    increment_step

    # ---->>>> Limpeza
    show_progress "Limpando diretórios temporários..."
    cd /root/
    rm -rf /root/RustySSL/
    increment_step

       # ---->>>> Instalação finalizada :)
clear
echo -e " "
echo -e "\033[0;34m--------------------------------------------------------------\033[0m"
echo -e "\033[40;1;37m            INSTALAÇÃO FINALIZADA COM SUCESSO                 \E[0m"
echo -e "\033[0;34m--------------------------------------------------------------\033[0m"
echo -e " "
fi