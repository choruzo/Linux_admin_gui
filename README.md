# Resource Monitor

Este script, `resource_monitor.sh`, es un monitor de recursos para sistemas SUSE que muestra en la terminal información relevante sobre el uso de CPU, memoria, discos y red.

## Características

- **CPU:** Muestra el porcentaje de uso activo utilizando el comando `top`.
- **Memoria:** Muestra el porcentaje de memoria usada, total, libre y disponible usando el comando `free`.
- **Discos:** Muestra el estado de uso de los discos montados por punto de montaje con porcentaje de uso e I/O por segundo (lecturas y escrituras), utilizando `df` y `/proc/diskstats`.
- **Red:** Extrae y muestra estadísticas de red (RX y TX) de la primera interfaz activa (no loopback) consultando `/proc/net/dev`.
- **Logging:** Opción de guardar los datos en un archivo durante un tiempo definido por el usuario.
- **Interfaz gráfica en terminal:** Se refresca periódicamente la pantalla para mostrar los datos actualizados.

## Requisitos

- Sistema operativo SUSE.
- Comandos necesarios: `top`, `free`, `df`, `ip`, `findmnt`, `awk`, `grep`.
- Bash.

## Uso

```bash
./resource_monitor.sh -r <segundos> -t <segundos> -o <archivo>
```

Donde:

- `-r <segundos>`: Intervalo de refresco de la pantalla (por defecto: 2 segundos).
- `-t <segundos>`: Tiempo en segundos durante el cual se guardarán los datos en el log (0 para no grabar, por defecto: 0).
- `-o <archivo>`: Archivo de salida para guardar los datos.

### Ejemplo

Para ejecutar el monitor con un refresco de 2 segundos y guardar el log durante 30 segundos en `log.txt`, usa:

```bash
./resource_monitor.sh -r 2 -t 30 -o log.txt
```

## Notas

- El script refresca la interfaz de forma continua hasta que se alcance el tiempo de log especificado o se interrumpa manualmente (Ctrl+C).
- En caso de no especificar el log o el tiempo de duración, el monitor se ejecutará indefinidamente hasta ser interrumpido.

## Permisos

Asegúrate de darle permisos de ejecución al script:

```bash
chmod +x resource_monitor.sh
```

## Contribuciones

Si deseas mejorar este script o adaptarlo a otras distribuciones, siéntete libre de abrir una issue o enviar un pull request.

## Licencia

Este script se proporciona "tal cual", sin garantía de ningún tipo. Puedes utilizar y modificar el código según tus necesidades.
