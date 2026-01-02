#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WWW_DIR="$PROJECT_DIR/www"

INSTALL_SH="$PROJECT_DIR/install.sh"
UP_SH="$PROJECT_DIR/up.sh"
INSTALLPS_SH="$PROJECT_DIR/installps.sh"

if [[ ! -f "$INSTALL_SH" ]]; then
  echo "Errore: file non trovato: $INSTALL_SH" >&2
  exit 1
fi
if [[ ! -f "$UP_SH" ]]; then
  echo "Errore: file non trovato: $UP_SH" >&2
  exit 1
fi
if [[ ! -f "$INSTALLPS_SH" ]]; then
  echo "Errore: file non trovato: $INSTALLPS_SH" >&2
  exit 1
fi

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  read -r -p "Nome istanza (base name) (es. ps8-mio): " NAME
fi
NAME="${NAME// /}"

if [[ -z "$NAME" ]]; then
  echo "Errore: nome vuoto." >&2
  exit 1
fi

NGINX_NAME="${NAME}-nginx"

echo "[0/3] Preparo la cartella ./www (owner: utente corrente)..."
mkdir -p "$WWW_DIR"
if [[ "$(id -u)" -ne 0 ]]; then
  if [[ -O "$WWW_DIR" ]]; then
    :
  else
    if command -v sudo >/dev/null 2>&1; then
      sudo chown -R "$(id -u):$(id -g)" "$WWW_DIR"
    else
      echo "Errore: '$WWW_DIR' non è di tua proprietà e sudo non è disponibile per sistemare i permessi." >&2
      exit 1
    fi
  fi
fi

echo "[1/3] Configuro i nomi dei container..."
bash "$INSTALL_SH" "$NAME"

echo "[2/3] Avvio i container (build incluso)..."
bash "$UP_SH"

echo "[3/3] Scarico e preparo i file di PrestaShop in ./www..."
CHOWN_WWW_DATA=0 bash "$INSTALLPS_SH"

echo
echo "OK: setup completato."
echo
echo "Prossimo step (Nginx Proxy Manager):"
echo "- Crea un Proxy Host che punti a: $NGINX_NAME"
echo "- Porta: 80"
echo "- Rete: proxy-network (la stessa usata da NPM)"
echo
echo "Poi apri il dominio/host configurato per avviare l'installer di PrestaShop." 
