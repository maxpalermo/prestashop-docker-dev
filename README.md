# PrestaShop 8 (PHP 8.2) Dev Environment (Docker)

Questa cartella contiene un ambiente Docker **isolato** per sviluppare con **PrestaShop 8** su **PHP 8.2**, completo di:

-   PHP 8.2 FPM
-   Nginx
-   Composer 2
-   Node.js 18 + Yarn (utile per tooling temi)
-   Xdebug

Il codice di PrestaShop viene montato in bind dentro ai container da `./www` verso `/var/www/html`.

## Requisiti

-   Docker + Docker Compose
-   Una rete Docker esterna chiamata `proxy-network` (usata anche da Nginx Proxy Manager / OpenResty)

Se non esiste, crea la rete:

```bash
docker network create proxy-network
```

## Procedura consigliata (setup completo)

Da questa cartella:

```bash
bash ./setup.sh
```

Lo script:

-   prepara `./www`
-   imposta i nomi dei container (ti chiede un nome istanza)
-   avvia i container
-   scarica/prepara PrestaShop dentro `./www`

## Avvio manuale (senza setup.sh)

1. Avvia i container (build incluso):

```bash
bash ./up.sh
```

2. Metti i file di PrestaShop in `./www` (se non usi `installps.sh`).

## Nginx Proxy Manager (NPM) / Reverse Proxy

Se usi Nginx Proxy Manager sulla stessa rete Docker `proxy-network`, crea un **Proxy Host** che punti al container Nginx di questa istanza:

-   **Forward Hostname / IP**: `<nome-istanza>-nginx` (es. `ps8-mio-nginx`)
-   **Forward Port**: `80`

Nel tab **Advanced** di NPM puoi impostare (opzionale ma consigliato per upload grandi):

```nginx
client_max_body_size 512m;
```

### Header consigliati (HTTPS dietro proxy)

Se il proxy termina TLS (HTTPS) e inoltra a Nginx in HTTP, assicurati che inoltri correttamente:

-   `X-Forwarded-Proto: https`
-   `X-Forwarded-Host: <tuo-dominio>`

Se questi header mancano, PrestaShop può generare redirect/URL non coerenti.

## Xdebug

-   Porta Xdebug: `9001`
-   Host: `host.docker.internal`

Per VS Code/Windsurf:

-   `port`: `9001`
-   `pathMappings`: `/var/www/html` -> `./www`

## UID/GID e proprietà dei file (`www-data`)

Con bind mount Docker l’ownership è numerica (es. `1000:1000`). Questo progetto rimappa `www-data` nel container PHP per farlo coincidere con l’utente host:

-   `Dockerfile` accetta `WWW_UID` e `WWW_GID`
-   `up.sh` passa automaticamente `WWW_UID="$(id -u)"` e `WWW_GID="$(id -g)"`

Se cambi utente/UID o sposti il progetto, ricostruisci l’immagine:

```bash
WWW_UID="$(id -u)" WWW_GID="$(id -g)" docker compose build --no-cache
WWW_UID="$(id -u)" WWW_GID="$(id -g)" docker compose up -d
```

Verifica:

```bash
docker exec -it ps8-dev id www-data
```

## Tool disponibili nel container PHP

Nel container PHP trovi:

-   `composer`
-   `node`, `npm`, `yarn`
-   `git`

Entra nel container:

```bash
docker exec -it ps8-dev bash
```

## Cosa fare dopo (post-install)

1. Apri il dominio/host configurato sul reverse proxy e completa l’installer di PrestaShop.

2. A fine installazione:

-   rinomina/cancella la cartella `install/` come richiesto da PrestaShop
-   prendi nota del nome della cartella admin generata (es. `admin_shop/`)

3. Accedi al Back Office:

-   `https://<dominio>/<admin_folder>/`

## Troubleshooting

### 403 su `/` (directory index forbidden)

Se Nginx logga `directory index of "/var/www/html/" is forbidden`:

-   verifica che dentro al container Nginx `/var/www/html` non sia vuota

```bash
docker exec -it ps8-dev-nginx ls -la /var/www/html | sed -n '1,20p'
```

Se è vuota, di solito il bind mount punta a una directory sbagliata: avvia `docker compose` dalla cartella corretta oppure usa path assoluti nei volumi.

### Redirect Back Office senza `/admin_*/`

Se chiamando `/<admin_folder>/index.php/...` ottieni redirect strani, assicurati che Nginx gestisca correttamente `PATH_INFO` (URL tipo `index.php/sell/...`). In questo progetto la config Nginx include una `location` PHP compatibile con `index.php/...`.

### Pagina `security/compromised`

Se vieni rediretto a `.../security/compromised` nel backoffice, spesso è dovuto a sessione/token e/o mismatch tra HTTP/HTTPS dietro reverse proxy. Controlla gli header `X-Forwarded-*` e che il dominio configurato in PrestaShop sia coerente.

## Note sulle risorse

-   Il servizio PHP ha `mem_limit: 4g` in compose.
-   `memory_limit` PHP è impostato a `4096M`.
