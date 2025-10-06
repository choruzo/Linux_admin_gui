#!/bin/bash
# Monitor de recursos para SUSE con interfaz en terminal.
# Muestra información de CPU, memoria, discos y red.
# Opciones:
#   -r <segundos>   Intervalo de refresco (default: 2)
#   -t <segundos>   Tiempo a grabar datos (0 para no grabar) (default: 0)
#   -o <archivo>    Archivo de salida para guardar datos

# Uso: ./resource_monitor.sh -r 2 -t 30 -o log.txt

# Función para obtener el uso de CPU utilizando top
get_cpu_usage() {
    # Se obtiene la línea de top que muestra el uso de CPU y se parsea el porcentaje de uso
    cpu_line=$(top -bn1 | grep "Cpu(s)")
    # Ejemplo formato: Cpu(s):  5.6%us,  2.1%sy,  0.0%ni, 91.9%id,  0.3%wa,  0.0%hi,  0.1%si,  0.0%st
    cpu_usage=$(echo "$cpu_line" | awk -F',' '{print 100 - $4}' | awk '{print $1"%"}')
    echo "$cpu_usage"
}

# Función para obtener uso de memoria usando free
get_mem_usage() {
    mem_info=$(free -m | grep -i "Mem:")
    # Se espera un output tipo: Mem:  7977   6312   1664    123   432   2178
    total=$(echo "$mem_info" | awk '{print $2}')
    used=$(echo "$mem_info" | awk '{print $3}')
    free_mem=$(echo "$mem_info" | awk '{print $4}')
    # Algunas distros incluyen campos extra, se puede usar "available" si existe
    available=$(free -m | grep -i "Mem:" | awk '{if(NF>=7) print $7; else print $4}')
    # Calcular porcentaje usado
    perc=$(awk "BEGIN {printf \"%.1f\",($used/$total)*100}")
    echo "$perc% (Usado: ${used}MB, Libre: ${free_mem}MB, Dispon.: ${available}MB)"
}

# Función para obtener información de discos usando df
get_disk_usage() {
    # Se muestra el uso de discos montados (omitimos los sistemas virtuales)
    df -h --total | grep "total" | awk '{print "Total: "$2", Usado: "$3", Libre: "$4", Uso: "$5}'
}

# Función para obtener uso de red a partir de /proc/net/dev
get_net_usage() {
    # Se asume que se muestra la primera interfaz activa (no loopback)
    interface=$(ip -o addr show | awk '/state UP/ && $2!="lo"{print $2; exit}')
    if [ -z "$interface" ]; then
        echo "No detectada"
        return
    fi
    # Se obtienen estadísticas de /proc/net/dev
    rx=$(grep "$interface" /proc/net/dev | awk '{print $2}')
    tx=$(grep "$interface" /proc/net/dev | awk '{print $10}')
    echo "Interfaz: $interface, RX: $rx bytes, TX: $tx bytes"
}

# Función para guardar log de datos si se especifica archivo
guardar_log() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$timestamp, CPU: $(get_cpu_usage), MEM: $(get_mem_usage), DISCO: $(get_disk_usage), RED: $(get_net_usage)" >> "$LOG_FILE"
}

# Valores por defecto
REFRESH_INTERVAL=2
LOG_DURATION=0
LOG_FILE=""

# Parseo de argumentos
while getopts "r:t:o:" opt; do
    case $opt in
        r) REFRESH_INTERVAL=$OPTARG;;
        t) LOG_DURATION=$OPTARG;;
        o) LOG_FILE=$OPTARG;;
        *) echo "Uso: $0 [-r refresh_interval] [-t log_duration_seconds] [-o log_file]"; exit 1;;
    esac
done

# Si se activó logging, comprueba archivo y duración
if [ -n "$LOG_FILE" ] && [ "$LOG_DURATION" -gt 0 ]; then
    echo "Iniciando log en $LOG_FILE durante $LOG_DURATION segundos..."
    # Limpiar archivo de log
    : > "$LOG_FILE"
fi

# Tiempo de inicio para log
start_time=$(date +%s)

while true; do
    clear
    echo "---------------------------"
    echo " Monitor de Recursos - SUSE"
    echo "---------------------------"
    echo "Fecha: $(date +"%Y-%m-%d %H:%M:%S")"
    echo ""
    echo "CPU: $(get_cpu_usage)"
    echo "Memoria: $(get_mem_usage)"
    echo "Discos: $(get_disk_usage)"
    echo "Red: $(get_net_usage)"
    echo "---------------------------"
    
    # Guarda log si se especificó
    if [ -n "$LOG_FILE" ] && [ "$LOG_DURATION" -gt 0 ]; then
        guardar_log
        current_time=$(date +%s)
        if [ $(( current_time - start_time )) -ge $LOG_DURATION ]; then
            echo "Tiempo de log alcanzado ($LOG_DURATION segundos). Finalizando..."
            break
        fi
    fi

    sleep $REFRESH_INTERVAL
done

# Si no se especifica log, el monitor es infinito hasta interrupción.
if [ -z "$LOG_FILE" ] || [ "$LOG_DURATION" -eq 0 ]; then
    trap "echo 'Interrupción detectada. Saliendo...'; exit 0" SIGINT SIGTERM
fi
