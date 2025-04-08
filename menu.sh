#!/bin/bash

PORTS_FILE="/opt/rustyssl/ports"

# Função para verificar se uma porta está em uso
is_port_in_use() {
    local port=$1
    
    if netstat -tuln 2>/dev/null | grep -q ":[0-9]*$port\b"; then
        return 0  
    elif ss -tuln 2>/dev/null | grep -q ":[0-9]*$port\b"; then
        return 0  
    else
        return 1 
    fi
}


# Função para abrir uma porta de proxy
add_proxy_port() {
    local port=$1

    if is_port_in_use $port; then
        echo "A PORTA $port JÁ ESTÁ EM USO."
        return
    fi

    local command="/opt/rustyssl/proxyssl --proxy-port $port"
    local service_file_path="/etc/systemd/system/proxyssl${port}.service"
    local service_file_content="[Unit]
Description=RustySSL${port}
After=network.target

[Service]
LimitNOFILE=infinity
LimitNPROC=infinity
LimitMEMLOCK=infinity
LimitSTACK=infinity
LimitCORE=0
LimitAS=infinity
LimitRSS=infinity
LimitCPU=infinity
LimitFSIZE=infinity
Type=simple
ExecStart=${command}
Restart=always

[Install]
WantedBy=multi-user.target"

    echo "$service_file_content" | sudo tee "$service_file_path" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable "proxyssl${port}.service"
    sudo systemctl start "proxyssl${port}.service"

    # Salvar a porta no arquivo
    echo $port >> "$PORTS_FILE"
    echo "Porta $port ABERTA COM SUCESSO."
}

# Função para fechar uma porta de proxy
del_proxy_port() {
    local port=$1

    sudo systemctl disable "proxyssl${port}.service"
    sudo systemctl stop "proxyssl${port}.service"
    sudo rm -f "/etc/systemd/system/proxyssl${port}.service"
    sudo systemctl daemon-reload

    # Remover a porta do arquivo
    sed -i "/^$port$/d" "$PORTS_FILE"
    echo "Porta $port FECHADA COM SUCESSO."
}

#FUNÇÃO PARA DESINSTALAR RUSTY PROXY
uninstall_rustyssl() {
    echo "DESINSTALANDO PROXYSSL, AGUARDE..."
    sleep 3
    clear

#REMOVER TODOS OS SERVIÇOS
    if [ -s "$PORTS_FILE" ]; then
        while read -r port; do
            del_proxy_port $port
        done < "$PORTS_FILE"
    fi
	
	#REMOVER BINÁRIOS, ARQUIVOS E DIRETÓRIOS
    sudo rm -rf /opt/rustyssl
    sudo rm -f "$PORTS_FILE"

    echo -e "\033[0;34m---------------------------------------------------------\033[0m"
    echo -e "\033[40;1;37m           SSL DESINSTALADO COM SUCESSO.          \E[0m"
    echo -e "\033[0;34m---------------------------------------------------------\033[0m"
    sleep 4
    clear
}

executar_comando() {
    local comando="$1"
    local mensagem="$2"
    local delay=0.1
    local percent=0
    local bar=""

    echo -e "${YELLOW}${mensagem:0:50}${NC}"
    echo -n ' '
    
    eval "$comando" & local cmd_pid=$!
    
    while kill -0 $cmd_pid 2>/dev/null; do
        percent=$((percent + 1))
        if [ $percent -ge 100 ]; then
            percent=100
        fi
        echo -ne "       \r$percent% [${bar:0:$((percent / 5))}]"
        sleep $delay
        bar=$(printf "%-30s" | tr ' ' '#')
    done

    wait $cmd_pid
    if [ $? -eq 0 ]; then
        percent=100
        echo -ne "       \r$percent% [${bar:0:20}]\n"
    else
        echo -e "\r${RED}Erro ao executar o comando.${NC}"
    fi
    
    echo
    sleep 1
}

atualizar_script() {
    uninstall_rustyssl
	bash <(wget -qO- https://raw.githubusercontent.com/vmell0/RustySSL/refs/heads/main/install.sh)
}

#FUNÇÃO PARA REINICIAR TODAS AS PORTAS PROXYS ABERTAS
restart_all_proxies() {
    if [ ! -s "$PORTS_FILE" ]; then
        echo "NENHUMA PORTA ENCONTRADA PARA REINICIAR."
        return
    fi

    echo "REINICIANDO TODAS AS PORTAS..."
    while read -r line; do
        port=$(echo "$line" | awk '{print $1}')
        del_proxy_port "$port"
        add_proxy_port "$port"
    done < "$PORTS_FILE"

    echo "✅ TODAS AS PORTAS FORAM REINICIADAS COM SUCESSO."
    sleep 3
    clear
}

# Função para exibir o menu formatado
show_menu() {
    clear
    echo -e "\E[44;1;37m          MULTI-SSL            \E[0m"
    echo -e "\033[0;36m╔════════════•⊱✦⊰•════════════╗\033[0m"
    #VERIFICADOR DE PORTAS ATIVAS
    if [ ! -s "$PORTS_FILE" ]; then
        printf "033[1;33m  NENHUMA PORTA %-34s\n" ""
    else
        while read -r line; do
            port=$(echo "$line" | awk '{print $1}')
            status=$(echo "$line" | cut -d' ' -f2-)
            printf "033[1;33m  PORTA: %-5s \033[1;32m%s\033[0m\n" "$port"
        done < "$PORTS_FILE"
    fi
    echo -e "\033[0;36m° ° ° ° ° ° ° ° ° ° ° ° ° ° ° °\033[0m"
    echo -e "\033[1;31m[\033[1;36m01\033[1;31m] \033[1;37m• \033[1;37mABRIR PORTA \033[1;31m
[\033[1;36m02\033[1;31m] \033[1;37m• \033[1;37mFECHAR PORTA \033[1;31m
[\033[1;36m03\033[1;31m] \033[1;37m• \033[1;37mREINICIAR PORTA \033[1;31m
[\033[1;36m04\033[1;31m] \033[1;37m• \033[1;37mATUALIZAR SCRIPT \033[1;31m
[\033[1;36m05\033[1;31m] \033[1;37m• \033[1;37mREMOVER SCRIPT \033[1;31m
[\033[1;36m00\033[1;31m] \033[1;37m• \033[1;37mVOLTAR \033[1;31m"
    echo -e "\033[0;36m╚════════════•⊱✦⊰•════════════╝\033[0m"
    echo -ne "  \033[1;31m➤ \033[1;32mOPÇÃO\033[1;33m\033[1;31m\033[1;37m: ";
    read option
    case $option in
        1 | 01)
		    echo ""
            read -p "PORTA: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "DIGITE UMA PORTA VÁLIDA."
                read -p "PORTA: " port
            done
            add_proxy_port $port "$status"
			echo -e "\n\033[1;31m✅ PORTA ATIVADA COM SUCESSO."
			sleep 2
            ;;
        2 | 02)
		    echo ""
            read -p "PORTA: " port
            while ! [[ $port =~ ^[0-9]+$ ]]; do
                echo "DIGITE UMA PORTA VÁLIDA."
                read -p "PORTA: " port
            done
            del_proxy_port $port
			echo -e "\n\033[1;31m✅ PORTA DESATIVADA."
			sleep 2
            ;;
		3 | 03)
		    clear
            restart_all_proxies
			echo -e "\n\033[1;31m✅ PORTAS REINICIADAS."
			sleep 2
		    ;;
		4 | 04)
		    clear
            echo ""
            executar_comando "atualizar_script &> /dev/null" "ATUALIZANDO SCRIPT"
			clear
	        menussl
		    ;;
		5 | 05)
		    clear
            uninstall_rustyssl
            read -p "◉ PRESSIONE QUALQUER TC PARA SAIR." dummy
	        clear
            exit 0
		    ;;
        0 | 00)
		    clear
            conexao
            ;;
        *)
            echo "OPÇÃO INVÁLIDA. PRESSIONE QUALQUER TECLA PARA VOLTAR AO MENU."
            read -n 1 dummy
            ;;
    esac
}



# Verificar se o arquivo de portas existe, caso contrário, criar
if [ ! -f "$PORTS_FILE" ]; then
    sudo touch "$PORTS_FILE"
fi

# Loop do menu
while true; do
    show_menu
done
