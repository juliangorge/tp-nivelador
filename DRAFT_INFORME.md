# DRAFT_INFORME.md

Borrador de trabajo para ir registrando, ejercicio a ejercicio, qué se implementó y
por qué. Sirve de base para el `INFORME.md` final (que se centra en protocolo de
comunicación y concurrencia, una vez que esas partes existan).

## Ejercicio N°1 — Múltiples clientes

Se definieron en `docker-compose.yaml` cinco contenedores de cliente (`client_0` a
`client_4`), todos basados en el mismo `services/client/Dockerfile`, diferenciados
por `container_name` y por la variable de entorno `AGENCY_ID` (0 a 4).

Verificación: `make down && make up` + `make logs` — los cinco clientes se conectan
al echo server y cada línea de log queda identificada con su `agency-id`. Al ser el
servidor serial (no concurrente), las conexiones se atienden una por vez
(`accept-connection` → `handle-client` por cliente), aunque las líneas de log de
distintos contenedores pueden intercalarse en la salida combinada de Docker.

### Opcional — script generador de `docker-compose.yaml`

Se agregó `scripts/generar-compose.sh`, un script bash que recibe por parámetro la
cantidad de clientes a configurar y genera un `docker-compose.yaml` con un servicio
`server` (puerto `5678` expuesto al host) y esa cantidad de servicios `client_N`
(`N` de `0` a `cantidad-1`), cada uno con su `AGENCY_ID` correspondiente.

```
Uso: scripts/generar-compose.sh <cantidad_de_clientes> [archivo_salida]
```

- Valida que el argumento sea un entero positivo (si no, error y salida no-cero).
- Por defecto escribe sobre `docker-compose.yaml`; opcionalmente puede indicarse un
  archivo de salida distinto para no pisar el existente.

Probado generando compose files con distintas cantidades de clientes (0 inválido,
3 y 5), validando el YAML resultante y levantando/bajando los contenedores
generados end-to-end (conexión y eco exitoso por cada `agency-id`).

## Ejercicio N°2 — Exposición del puerto del servidor

Se agregó `ports: - "5678:5678"` al servicio `server` en `docker-compose.yaml`.

Verificación: con los contenedores levantados, `echo "Hello World" | nc localhost
5678` desde el equipo anfitrión devuelve `Hello World`, confirmando que el proceso
del servidor dentro de Docker es alcanzable desde afuera del contenedor.

### Opcional — verificación vía netcat sin exponer puertos

Se agregó `scripts/verificar-netcat.sh [mensaje]`, que verifica el funcionamiento
del servidor sin exponer sus puertos al equipo anfitrión y sin modificar
`docker-compose.yaml`: levanta un contenedor auxiliar (`busybox`) conectado a la
misma red de Docker que el contenedor `server` (detectada dinámicamente con
`docker inspect`, sin asumir el nombre de red del proyecto) y desde ahí envía el
mensaje con `nc` directamente al hostname `server` en el puerto `5678`, comparando
la respuesta contra lo enviado.

Probado explícitamente contra una variante de `docker-compose.yaml` **sin** la
sección `ports`: se confirmó primero que `nc localhost 5678` desde el host falla
(no hay puerto expuesto) y luego que `scripts/verificar-netcat.sh` sí obtiene el
eco correcto por pasar a través de la red interna de Docker en lugar del host.

El script reintenta (hasta 5 veces, con backoff de 2s) si no obtiene la respuesta
esperada: recién después de `make up` el servidor puede tardar en aceptar
conexiones, y un único intento con timeout ajustado daba un falso negativo
(reproducido y corregido).

## Ejercicio N°3 — Lectura de `INPUT_FILE` y persistencia de `OUTPUT_FILE`

Se reescribió `client.go` (`Client.Run`): en lugar del loop de prueba de eco
(`ECHO_CLIENT_MESSAGE_AMOUNT`), ahora abre `INPUT_FILE`, lee línea por línea con
`bufio.Scanner`, envía cada línea como mensaje individual (`safe_socket.SendAll`),
recibe la respuesta del servidor y la persiste en `OUTPUT_FILE` (una línea por
respuesta). `main.go` ahora exige `INPUT_FILE`/`OUTPUT_FILE` por variable de
entorno, igual que `AGENCY_ID`/`SERVER_HOST`/`SERVER_PORT`.

Se eliminaron las constantes `ECHO_CLIENT_MESSAGE_AMOUNT`/`ECHO_CLIENT_MESSAGE_DELAY_MS`
(ya no aplican: el envío ahora está guiado por el contenido real del archivo, no
por una cantidad fija de mensajes de prueba con demora artificial).

`docker-compose.yaml` monta `./input:/input` y `./output:/output` como volúmenes
en cada cliente (en vez de copiar los CSV a la imagen), con
`INPUT_FILE=/input/input-N.csv` y `OUTPUT_FILE=/output/output-N.csv` — misma
convención que usan los compose files de los tests de la cátedra
(`tests/compose_files/*.yaml`). `scripts/generar-compose.sh` se actualizó para
generar esos mismos volúmenes/variables automáticamente.

Como el servidor todavía sólo hace eco (el protocolo real es Ejercicio N°5), el
`OUTPUT_FILE` en esta etapa contiene el eco de cada línea enviada, no todavía el
listado de ganadores.

Verificación:
- `make down && make up`: los 5 clientes terminan con exit code 0;
  `output/output-N.csv` coincide línea por línea y en contenido con
  `input/input-N.csv` (la única diferencia de tamaño en bytes es la normalización
  de fin de línea CRLF→LF que hace `bufio.Scanner`, verificado que coincide
  exactamente con la cantidad de líneas).
- Se confirmó que un cambio en un `INPUT_FILE` entre ejecuciones no requiere
  reconstruir la imagen: se agregó una línea a `input-0.csv` y se corrió
  `docker compose up client_0 --no-build --force-recreate`; el log mostró
  `bets-amount=6` (antes 5) y `output-0.csv` reflejó la línea nueva.
