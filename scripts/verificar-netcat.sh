#!/usr/bin/env bash
#
# Verifies that the server responds correctly via netcat, without exposing
# ports to the host machine or modifying docker-compose.yaml: it spins up
# an auxiliary container connected to the same Docker network as the
# "server" container and tests the echo from there (docker network).
#
# Usage: scripts/verificar-netcat.sh [message]

set -euo pipefail

SERVER_CONTAINER="server"
MESSAGE="${1:-Hello World}"

if ! docker inspect "$SERVER_CONTAINER" >/dev/null 2>&1; then
  echo "Error: no se encontró el contenedor '${SERVER_CONTAINER}'. Levantá el sistema con 'make up' primero." >&2
  exit 1
fi

if [ "$(docker inspect -f '{{.State.Running}}' "$SERVER_CONTAINER")" != "true" ]; then
  echo "Error: el contenedor '${SERVER_CONTAINER}' no está corriendo. Levantá el sistema con 'make up' primero." >&2
  exit 1
fi

NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$SERVER_CONTAINER")"

if [ -z "$NETWORK" ]; then
  echo "Error: no se pudo determinar la red de Docker del contenedor '${SERVER_CONTAINER}'." >&2
  exit 1
fi

echo "Probando '${SERVER_CONTAINER}' en la red '${NETWORK}' con un contenedor auxiliar (sin exponer puertos al host)..."

# Retries with backoff: right after "make up" the server may take a moment
# to accept connections, and a tight nc timeout gives a false negative.
ATTEMPTS=5
for ((i = 1; i <= ATTEMPTS; i++)); do
  RESPONSE="$(echo "$MESSAGE" | docker run --rm -i --network "$NETWORK" busybox \
    sh -c "nc -w 5 ${SERVER_CONTAINER} 5678" || true)"

  if [ "$RESPONSE" = "$MESSAGE" ]; then
    echo "OK: el servidor respondió '${RESPONSE}' (esperado: '${MESSAGE}')"
    exit 0
  fi

  if [ "$i" -lt "$ATTEMPTS" ]; then
    echo "  (intento ${i}/${ATTEMPTS} sin respuesta válida, reintentando...)"
    sleep 2
  fi
done

echo "FALLO: el servidor respondió '${RESPONSE}' (esperado: '${MESSAGE}')" >&2
exit 1
