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
echo "3) Configurar DNS"
echo "4) Salir del Script"
echo "--------------------------------------"
read -p "Elige una opción (1, 2, 3 o 4): " OPCION

# Preguntar por la configuración de red si se elige la interfaz cableada
if [ "$OPCION" -eq 1 ]; then
    if [ -n "$INTERFAZ_CABLEADA" ]; then
        # Preguntar al usuario por los parámetros de configuración
        read -p "Introduce la dirección IP: (Si es por DHCP no introduzca nada) " IP
        read -p "Introduce la máscara de subred (en formato CIDR, ej. 24  paara 255.255.255.0): " MASCARA
        read -p "Introduce la puerta de enlace: (Si es por DHCP no introduzca nada " PUERTA_DE_ENLACE
        read -p "Introduce los servidores DNS (separados por espacio): " DNS
    else
        echo "No se encontró ninguna interfaz cableada."
        exit 1
    fi
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

 if [ -n "$INTERFAZ_INALAMBRICA" ]; then
        # Preguntar al usuario por los parámetros de configuración
        read -p "Introduce la dirección IP: (Si es por DHCP no introduzca nada) " IP_WIFI
        read -p "Introduce la máscara de subred (en formato CIDR, ej. 24  paara 255.255.255.0): " MASCARA_WIFI
        read -p "Introduce la puerta de enlace: (Si es por DHCP no introduzca nada " GATEWAY_WIFI
        read -p "Introduce los servidores DNS (separados por espacio): " DNS_WIFI
    else
        echo "No se encontró ninguna interfaz cableada."
        exit 1
    fi
    # Levantar la interfaz inalámbrica y conectarse
    sudo ip link set $INTERFAZ up
     #sudo wpa_supplicant -B -i $INTERFAZ -c $WPA_CONF
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
3)
	#Opcion 3 Configurar DNS
	if [ -n "$OPCION" ]; then
	echo "-----------------"
	echo "Configuracion DNS"
	echo "-----------------"
	sudo nano /etc/resolv.conf
	fi
	;;
4)
	#Opcion 4 salir del script
	if [ -n "$OPCION" ]; then
		echo "-------------------"
		echo "Saliendo del script"
		echo "-------------------"
		exit 1
	else
		echo "Saliendo del script"
	fi
	;;

*)
        echo "Opción no válida"
        echo "Saliendo del script"
	exit 1
	;;
esac
