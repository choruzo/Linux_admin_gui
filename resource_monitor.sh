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

# Variables globales para almacenar el estado anterior de I/O
declare -A PREV_DISK_READS
declare -A PREV_DISK_WRITES
PREV_DISK_TIME=0

# Función para obtener I/O stats de un dispositivo desde /proc/diskstats
get_device_io() {
    local device=$1
    # Buscar el dispositivo en /proc/diskstats (solo el nombre base, sin /dev/)
    local stats=$(grep -w "${device}" /proc/diskstats 2>/dev/null)
    if [ -z "$stats" ]; then
        echo "0 0"
        return
    fi
    # Campos: reads completed (campo 4), writes completed (campo 8)
    local reads=$(echo "$stats" | awk '{print $4}')
    local writes=$(echo "$stats" | awk '{print $8}')
    echo "$reads $writes"
}

# Función para obtener información de discos usando df con I/O por montaje
get_disk_usage() {
    local current_time=$(date +%s)
    local time_diff=1
    
    # Calcular diferencia de tiempo si hay medición previa
    if [ $PREV_DISK_TIME -gt 0 ]; then
        time_diff=$((current_time - PREV_DISK_TIME))
        if [ $time_diff -eq 0 ]; then
            time_diff=1
        fi
    fi
    
    # Obtener listado de discos montados (excluir tmpfs, devtmpfs, y otros virtuales)
    local disk_info=$(df -h | grep -E "^/dev/" | grep -v "tmpfs")
    
    echo ""
    while IFS= read -r line; do
        local device=$(echo "$line" | awk '{print $1}')
        local mount=$(echo "$line" | awk '{print $6}')
        local size=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local avail=$(echo "$line" | awk '{print $4}')
        local percent=$(echo "$line" | awk '{print $5}')
        
        # Resolver dispositivo real si es /dev/root
        local real_device="$device"
        if [ "$device" = "/dev/root" ]; then
            real_device=$(findmnt -n -o SOURCE "$mount" 2>/dev/null || echo "$device")
        fi
        
        # Extraer nombre del dispositivo sin /dev/
        local dev_name=$(basename "$real_device")
        
        # Obtener stats actuales de I/O
        local io_stats=$(get_device_io "$dev_name")
        local current_reads=$(echo "$io_stats" | awk '{print $1}')
        local current_writes=$(echo "$io_stats" | awk '{print $2}')
        
        # Calcular I/O por segundo
        local reads_per_sec=0
        local writes_per_sec=0
        
        if [ $PREV_DISK_TIME -gt 0 ] && [ -n "${PREV_DISK_READS[$dev_name]}" ]; then
            reads_per_sec=$(( (current_reads - PREV_DISK_READS[$dev_name]) / time_diff ))
            writes_per_sec=$(( (current_writes - PREV_DISK_WRITES[$dev_name]) / time_diff ))
        fi
        
        # Guardar valores actuales para la próxima iteración
        PREV_DISK_READS[$dev_name]=$current_reads
        PREV_DISK_WRITES[$dev_name]=$current_writes
        
        # Mostrar información
        printf "  %s: %s (%s) | R: %d/s, W: %d/s\n" "$mount" "$percent" "$used" "$reads_per_sec" "$writes_per_sec"
    done <<< "$disk_info"
    
    # Actualizar tiempo de última medición
    PREV_DISK_TIME=$current_time
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
    # Obtener información de discos en formato compacto para log
    local disk_summary=$(df -h | grep -E "^/dev/" | grep -v "tmpfs" | awk '{printf "%s:%s ", $6, $5}')
    echo "$timestamp, CPU: $(get_cpu_usage), MEM: $(get_mem_usage), DISCO: $disk_summary, RED: $(get_net_usage)" >> "$LOG_FILE"
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
