#!/usr/bin/env bash
#
# Generates docker-compose.yaml with the given number of clients.
#
# Usage: scripts/generar-compose.sh <client_count> [output_file]

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Uso: $0 <cantidad_de_clientes> [archivo_salida]" >&2
  exit 1
fi

CLIENT_COUNT="$1"
OUTPUT_FILE="${2:-docker-compose.yaml}"

if ! [[ "$CLIENT_COUNT" =~ ^[0-9]+$ ]] || [ "$CLIENT_COUNT" -lt 1 ]; then
  echo "Error: <cantidad_de_clientes> debe ser un entero positivo" >&2
  exit 1
fi

{
  echo "services:"
  echo "  server:"
  echo "    build:"
  echo "      context: ./services/server"
  echo "      dockerfile: Dockerfile"
  echo "    container_name: server"
  echo "    ports:"
  echo "      - \"5678:5678\""
  echo "    environment:"
  echo "      - PYTHONUNBUFFERED=1"
  echo "      - SERVER_HOST=server"
  echo "      - SERVER_PORT=5678"

  for ((i = 0; i < CLIENT_COUNT; i++)); do
    echo ""
    echo "  client_${i}:"
    echo "    build:"
    echo "      context: ./services/client"
    echo "      dockerfile: Dockerfile"
    echo "    container_name: client_${i}"
    echo "    depends_on:"
    echo "      - server"
    echo "    environment:"
    echo "      - AGENCY_ID=${i}"
    echo "      - SERVER_HOST=server"
    echo "      - SERVER_PORT=5678"
    echo "      - INPUT_FILE=/input/input-${i}.csv"
    echo "      - OUTPUT_FILE=/output/output-${i}.csv"
    echo "    volumes:"
    echo "      - ./input:/input"
    echo "      - ./output:/output"
  done
} > "$OUTPUT_FILE"

echo "Generado ${OUTPUT_FILE} con 1 server y ${CLIENT_COUNT} cliente(s)."
