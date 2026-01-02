#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
NGINX_CONF="$PROJECT_DIR/nginx.conf"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Errore: file non trovato: $COMPOSE_FILE" >&2
  exit 1
fi
if [[ ! -f "$NGINX_CONF" ]]; then
  echo "Errore: file non trovato: $NGINX_CONF" >&2
  exit 1
fi

if [[ ${#} -ge 1 ]]; then
  BASE_NAME="$1"
else
  read -r -p "Nome container PHP-FPM (es. ps8-mio): " BASE_NAME
fi
BASE_NAME="${BASE_NAME// /}"

if [[ -z "$BASE_NAME" ]]; then
  echo "Errore: nome vuoto." >&2
  exit 1
fi

# Nome Docker valido (semplificato): lettere/numeri e . _ -
if [[ ! "$BASE_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "Errore: nome non valido. Usa solo lettere/numeri e . _ - (senza spazi)." >&2
  exit 1
fi

PHP_NAME="$BASE_NAME"
NGINX_NAME="${BASE_NAME}-nginx"

TS="$(date +%Y%m%d%H%M%S)"
cp -a "$COMPOSE_FILE" "$COMPOSE_FILE.bak.$TS"
cp -a "$NGINX_CONF" "$NGINX_CONF.bak.$TS"

# Aggiorna solo i container_name (non i nomi dei servizi)
sed -i -E "s|^(\s*container_name:\s*)docker-ps8\s*$|\1${PHP_NAME}|" "$COMPOSE_FILE"
sed -i -E "s|^(\s*container_name:\s*)docker-ps8-nginx\s*$|\1${NGINX_NAME}|" "$COMPOSE_FILE"

# Aggiorna l'upstream php-fpm verso il nuovo hostname del container PHP
sed -i -E "s|(\s*server\s+)docker-ps8:9000;|\1${PHP_NAME}:9000;|" "$NGINX_CONF"

echo "OK. Aggiornati:" 
echo "- $COMPOSE_FILE (backup: $COMPOSE_FILE.bak.$TS)"
echo "- $NGINX_CONF (backup: $NGINX_CONF.bak.$TS)"
echo
echo "Nuovi nomi:" 
echo "- PHP:   $PHP_NAME"
echo "- Nginx: $NGINX_NAME"
