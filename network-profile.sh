#!/bin/bash
# Limpiamos la pantalla
clear
echo "------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------"
echo " ██████╗ ██████╗  ██████╗ ███████╗██╗██╗     ███████╗    ███╗   ██╗███████╗████████╗██╗    ██╗ ██████╗ ██████╗ ██╗  ██╗ "
echo " ██╔══██╗██╔══██╗██╔═══██╗██╔════╝██║██║     ██╔════╝    ████╗  ██║██╔════╝╚══██╔══╝██║    ██║██╔═══██╗██╔══██╗██║ ██╔╝ "
echo " ██████╔╝██████╔╝██║   ██║█████╗  ██║██║     █████╗      ██╔██╗ ██║█████╗     ██║   ██║ █╗ ██║██║   ██║██████╔╝█████╔╝  "
echo " ██╔═══╝ ██╔══██╗██║   ██║██╔══╝  ██║██║     ██╔══╝      ██║╚██╗██║██╔══╝     ██║   ██║███╗██║██║   ██║██╔══██╗██╔═██╗  "
echo " ██║     ██║  ██║╚██████╔╝██║     ██║███████╗███████╗    ██║ ╚████║███████╗   ██║   ╚███╔███╔╝╚██████╔╝██║  ██║██║  ██╗ "
echo " ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝    ╚═╝  ╚═══╝╚══════╝   ╚═╝    ╚══╝╚══╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ "
echo "------------------------------------------------------------------------------------------------------------------------"
echo "------------------------------------------------------------------------------------------------------------------------"
# Obtener la interfaz de red cableada
INTERFAZ_CABLEADA=$(ip link show | grep -E "^[0-9]+: (en|eth)" | awk -F': ' '{print $2}' | head -n 1)

# Obtener la interfaz de red inalámbrica
INTERFAZ_INALAMBRICA=$(ip link show | grep -E "^[0-9]+: wl" | awk -F': ' '{print $2}' | head -n 1)

# Verificar si se detectaron ambas interfaces
if [ -z "$INTERFAZ_CABLEADA" ]; then
    echo "No se detectó ninguna interfaz de red cableada."
fi
if [ -z "$INTERFAZ_INALAMBRICA" ]; then
    echo "No se detectó ninguna interfaz de red inalámbrica."
fi

# Mostrar las interfaces detectadas
echo "Interfaz cableada detectada: $INTERFAZ_CABLEADA"
echo "Interfaz inalámbrica detectada: $INTERFAZ_INALAMBRICA"

# Preguntar al usuario qué interfaz desea configurar
echo "--------------------------------------"
echo "¿Qué interfaz deseas configurar?"
echo "1) Cableada ($INTERFAZ_CABLEADA)"
echo "2) Inalámbrica ($INTERFAZ_INALAMBRICA)"
echo "3) Salir del Script"
echo "--------------------------------------"
read -p "Elige una opción (1, 2 o 3): " OPCION

# Comprobar si se han pasado suficientes argumentos (4: IP, MASCARA, PUERTA_DE_ENLACE, DNS)
if [ "$OPCION" -eq 1 ] || [ "$OPCION" -eq 3 ]; then
    if [ "$#" -ne 4 ]; then
        echo "Uso para red cableada: $0 <IP> <MASCARA_CIDR> <PUERTA_DE_ENLACE> <DNS>"
        echo "Ejemplo: $0 192.168.1.100 24 192.168.1.1 8.8.8.8"
        echo "Nota: La máscara debe estar en formato CIDR (por ejemplo, 24 para 255.255.255.0)"
        exit 1
    fi

    IP=$1
    MASCARA=$2
    PUERTA_DE_ENLACE=$3
    DNS=$4
fi

# Función para configurar la interfaz de red cableada
configurar_interfaz() {
    local INTERFAZ=$1
    local IP=$2
    local MASCARA=$3
    local PUERTA_DE_ENLACE=$4
    local DNS=$5

    echo "Configurando la interfaz $INTERFAZ..."
    sudo ip addr flush dev $INTERFAZ  # Limpiar la configuración previa
    sudo ip addr add $IP/$MASCARA dev $INTERFAZ  # Añadir la IP
    sudo ip link set dev $INTERFAZ up  # Levantar la interfaz
    sudo ip route add default via $PUERTA_DE_ENLACE  # Establecer la puerta de enlace

    # Configurar el DNS (temporalmente en resolv.conf)
    echo "Configurando el servidor DNS..."
    echo "nameserver $DNS" | sudo tee /etc/resolv.conf > /dev/null

    # Mostrar la configuración
    echo "Configuración completada para $INTERFAZ:"
    ip addr show $INTERFAZ
    cat /etc/resolv.conf
}

# Función para configurar la red inalámbrica
configurar_wifi() {
    local INTERFAZ=$1
    read -p "Introduce el SSID de la red WiFi: " SSID
    echo "Tipos de encriptación: "
    echo "1) WPA/WPA2"
    echo "2) WEP"
    echo "3) Abierta (sin cifrado)"
    read -p "Elige el tipo de encriptación (1, 2 o 3): " ENCRIPTADO

    case $ENCRIPTADO in
        1)
            ENCRYPTION_TYPE="WPA-PSK"
            read -sp "Introduce la contraseña del WiFi: " WIFI_PASSWORD
            echo
            ;;
        2)
            ENCRYPTION_TYPE="WEP"
            read -sp "Introduce la contraseña del WiFi: " WIFI_PASSWORD
            echo
            ;;
        3)
            ENCRYPTION_TYPE="NONE"
            ;;
        *)
            echo "Opción de encriptación no válida."
            exit 1
            ;;
    esac

    # Preguntar por IP, máscara, puerta de enlace y DNS para la interfaz WiFi
    read -p "Introduce la IP estática para la red WiFi: (Si es por DHCP no introduzca nada) " IP_WIFI
    read -p "Introduce la máscara de red (en formato CIDR) (Si es por DHCP no introduzca nada) : " MASCARA_WIFI
    read -p "Introduce la puerta de enlace (gateway) para la red WiFi (Si es por DHCP no introduzca nada): " GATEWAY_WIFI
    read -p "Introduce el servidor DNS para la red WiFi (Si es por DHCP no introduzca nada): " DNS_WIFI

    # Crear archivo de configuración de wpa_supplicant
    WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
    sudo bash -c "cat > $WPA_CONF" <<EOL
network={
    ssid="$SSID"
    key_mgmt=WPA-PSK
EOL

    if [ "$ENCRYPTION_TYPE" == "WPA-PSK" ]; then
        sudo bash -c "echo '    psk=\"$WIFI_PASSWORD\"' >> $WPA_CONF"
    elif [ "$ENCRYPTION_TYPE" == "WEP" ]; then
        sudo bash -c "echo '    wep_key0=\"$WIFI_PASSWORD\"' >> $WPA_CONF"
        sudo bash -c "echo '    auth_alg=OPEN' >> $WPA_CONF"
    fi

    sudo bash -c "echo '}' >> $WPA_CONF"

    # Levantar la interfaz inalámbrica y conectarse
    sudo ip link set $INTERFAZ up
    sudo wpa_supplicant -B -i $INTERFAZ -c $WPA_CONF
    sudo dhclient $INTERFAZ  # Obtener la IP vía DHCP si es necesario

    # Configurar la IP estática para la interfaz WiFi
    sudo ip addr flush dev $INTERFAZ
    sudo ip addr add $IP_WIFI/$MASCARA_WIFI dev $INTERFAZ
    sudo ip route add default via $GATEWAY_WIFI

    # Configurar el DNS
    echo "nameserver $DNS_WIFI" | sudo tee /etc/resolv.conf > /dev/null

    echo "Conexión WiFi configurada para la interfaz $INTERFAZ"
    ip addr show $INTERFAZ
    cat /etc/resolv.conf
}

# Configurar la interfaz según la opción elegida
case $OPCION in
    1)
        # Configurar solo la interfaz cableada
        if [ -n "$INTERFAZ_CABLEADA" ]; then
            configurar_interfaz $INTERFAZ_CABLEADA $IP $MASCARA $PUERTA_DE_ENLACE $DNS
        else
            echo "No se encontró ninguna interfaz cableada."
            exit 1
        fi
        ;;
    2)
        # Configurar solo la interfaz inalámbrica
        if [ -n "$INTERFAZ_INALAMBRICA" ]; then
            configurar_wifi $INTERFAZ_INALAMBRICA
        else
            echo "No se encontró ninguna interfaz inalámbrica."
            exit 1
        fi
	;;
esac
