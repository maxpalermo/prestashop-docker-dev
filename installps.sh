#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WWW_DIR="$PROJECT_DIR/www"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Errore: comando richiesto non trovato: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd unzip

mkdir -p "$WWW_DIR"

HAS_WWW_DATA="0"
if command -v getent >/dev/null 2>&1; then
  if getent passwd www-data >/dev/null 2>&1; then
    HAS_WWW_DATA="1"
  fi
else
  if id -u www-data >/dev/null 2>&1; then
    HAS_WWW_DATA="1"
  fi
fi

WANT_WWW_DATA="0"
if [[ "$HAS_WWW_DATA" == "1" ]]; then
  if [[ -n "${CHOWN_WWW_DATA:-}" ]]; then
    case "${CHOWN_WWW_DATA}" in
      1|true|TRUE|yes|YES|y|Y) WANT_WWW_DATA="1" ;;
      0|false|FALSE|no|NO|n|N) WANT_WWW_DATA="0" ;;
      *)
        echo "Errore: CHOWN_WWW_DATA deve essere 1/0 (o true/false, yes/no)." >&2
        exit 1
        ;;
    esac
  else
    read -r -p "www-data trovato. Vuoi impostare owner/permessi di ./www a www-data? [y/N]: " REPLY
    case "${REPLY}" in
      y|Y|yes|YES) WANT_WWW_DATA="1" ;;
      *) WANT_WWW_DATA="0" ;;
    esac
  fi
fi

SUDO=""
if [[ "$WANT_WWW_DATA" == "1" && "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "Errore: per impostare ownership www-data serve sudo (oppure esegui come root)." >&2
    exit 1
  fi
fi

if [[ -z "${FORCE:-}" ]]; then
  # Se www contiene qualcosa (esclusi i dotfile), evitiamo di sovrascrivere
  if find "$WWW_DIR" -mindepth 1 -maxdepth 1 -not -name ".gitkeep" | read -r _; then
    echo "Errore: la cartella '$WWW_DIR' non è vuota." >&2
    echo "Se vuoi forzare comunque, rilancia con: FORCE=1 ./installps.sh" >&2
    exit 1
  fi
fi

# Imposta permessi/owner per lavorare con PHP-FPM (www-data)
# Nota: su alcuni host l'utente www-data potrebbe non esistere: in quel caso lasciamo l'ownership di default.
chown_cmd=(chown -R www-data:www-data "$WWW_DIR")
chmod_cmd=(chmod -R u+rwX,go+rX,go-w "$WWW_DIR")

if [[ "$HAS_WWW_DATA" == "1" && "$WANT_WWW_DATA" == "1" ]]; then
  if [[ -n "$SUDO" ]]; then
    $SUDO "${chown_cmd[@]}"
    $SUDO "${chmod_cmd[@]}"
  else
    "${chown_cmd[@]}"
    "${chmod_cmd[@]}"
  fi
elif [[ "$HAS_WWW_DATA" == "1" && "$WANT_WWW_DATA" == "0" ]]; then
  echo "Info: lasciati invariati owner/permessi in '$WWW_DIR'."
else
  echo "Info: utente www-data non trovato sull'host. Lascio l'ownership di default in '$WWW_DIR'."
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Recupera l'ultima release 8.x da GitHub
RELEASES_JSON="$TMP_DIR/releases.json"
curl -fsSL "https://api.github.com/repos/PrestaShop/PrestaShop/releases" -o "$RELEASES_JSON"

# Estrae la prima tag che inizia con 8.
TAG="$(grep -oE '"tag_name"\s*:\s*"[^"]+"' "$RELEASES_JSON" | head -n 50 | sed -E 's/.*"([^"]+)".*/\1/' | grep -E '^8\.' | head -n 1)"

if [[ -z "$TAG" ]]; then
  echo "Errore: non riesco a determinare l'ultima release 8.x da GitHub." >&2
  exit 1
fi

ZIP_URL="https://github.com/PrestaShop/PrestaShop/releases/download/${TAG}/prestashop_${TAG}.zip"
ZIP_FILE="$TMP_DIR/prestashop.zip"

echo "Scarico PrestaShop $TAG..."
curl -fL "$ZIP_URL" -o "$ZIP_FILE"

echo "Decomprimo in $WWW_DIR..."
if [[ -n "$SUDO" ]]; then
  $SUDO unzip -q "$ZIP_FILE" -d "$WWW_DIR"
else
  unzip -q "$ZIP_FILE" -d "$WWW_DIR"
fi

# Il pacchetto PrestaShop ufficiale spesso contiene prestashop.zip dentro la prima estrazione
INNER_ZIP="$WWW_DIR/prestashop.zip"
if [[ -f "$INNER_ZIP" ]]; then
  if [[ -n "$SUDO" ]]; then
    $SUDO unzip -q "$INNER_ZIP" -d "$WWW_DIR"
    $SUDO rm -f "$INNER_ZIP"
  else
    unzip -q "$INNER_ZIP" -d "$WWW_DIR"
    rm -f "$INNER_ZIP"
  fi
fi

# Ripristina owner/perms dopo l'estrazione
if [[ "$HAS_WWW_DATA" == "1" && "$WANT_WWW_DATA" == "1" ]]; then
  if [[ -n "$SUDO" ]]; then
    $SUDO "${chown_cmd[@]}"
    $SUDO "${chmod_cmd[@]}"
  else
    "${chown_cmd[@]}"
    "${chmod_cmd[@]}"
  fi
fi

echo "OK: PrestaShop $TAG pronto in '$WWW_DIR'."
echo "Ora avvia i container e apri la pagina per completare l'installazione via browser." 
