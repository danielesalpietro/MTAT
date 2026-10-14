# MTAT in Docker (beta)

Esecuzione *turn-key* del motore MTAT v3.1 in un container Linux (PowerShell 7 + VMware PowerCLI),
senza installare nulla sul proprio PC a parte Docker.

## Avvio rapido

```bash
docker compose up -d --build
# poi aprire http://localhost:8600
```

Il primo build scarica PowerCLI da PowerShell Gallery (serve accesso a `www.powershellgallery.com`).

| Comando | Effetto |
|---|---|
| `docker compose logs -f` | log del motore (stesso contenuto di `MTAT_debug_log.txt`) |
| `docker compose restart` | riavvio pulito (chiude le sessioni vCenter aperte) |
| `docker compose down` | stop; i log restano nel volume `mtat-data` |

Il pulsante **Exit Engine** dell'interfaccia termina il processo: con `restart: unless-stopped`
Docker lo riavvia subito, quindi in pratica equivale a "reset delle sessioni".

## Differenze rispetto all'esecuzione desktop

Lo script resta lo stesso (`MTAT_v3_1.ps1`); il comportamento container è attivato solo da
variabili d'ambiente, già impostate nell'immagine:

| Variabile | Default container | Default desktop | Significato |
|---|---|---|---|
| `MTAT_HEADLESS` | `1` | non impostata | niente apertura browser, niente auto-spegnimento per assenza di heartbeat UI, log su stdout |
| `MTAT_PORT` | `8600` | auto (8600+) | porta fissa |
| `MTAT_BIND_HOST` | `+` (tutte le interfacce) | `127.0.0.1` | interfaccia di ascolto dentro il container |
| `MTAT_ALLOWED_HOSTS` | vuota | vuota | hostname aggiuntivi accettati nell'header `Host` (oltre a localhost/127.0.0.1/[::1]); un'eventuale `:porta` viene ignorata |
| `MTAT_DATA_DIR` | `/var/lib/mtat` (volume) | temp di sistema | dove viene scritto `MTAT_debug_log.txt` |

## Sicurezza

MTAT **non ha autenticazione**: chi raggiunge la porta può usare le sessioni vCenter aperte.
Per questo il compose pubblica la porta solo su `127.0.0.1` dell'host. Per l'accesso da altre
macchine:

```bash
MTAT_PUBLISH_ADDR=0.0.0.0 MTAT_ALLOWED_HOSTS=mtat.lab.local docker compose up -d
```

solo su rete fidata o dietro un reverse proxy con autenticazione.

Protezioni nel motore (sempre attive, anche in modalità desktop):
- **Host allowlist**: richieste con header `Host` diverso da localhost/127.0.0.1/[::1] o da
  `MTAT_ALLOWED_HOSTS` → 403. Blocca il DNS rebinding, che l'ascolto su tutte le interfacce
  (`MTAT_BIND_HOST=+`) altrimenti renderebbe possibile.
- **Anti-CSRF**: POST con header `Origin` diverso (host **e porta**) da quello della richiesta → 403,
  anche se arriva da un'altra app su localhost. La UI di MTAT (same-origin) e i client
  non-browser (senza `Origin`) passano.

Come nella versione desktop, i certificati self-signed di vCenter vengono accettati (`-InvalidCertificateAction Ignore`).

## Rete

Il container deve raggiungere vCenter sulla 443/TCP. `Get-EsxCli` (stato tiering per host) passa
anch'esso da vCenter, non serve accesso diretto agli ESXi.

## CA aziendali / proxy con ispezione TLS

Copiare i certificati root (`*.crt`, formato PEM) in `docker/certs/` e ricostruire l'immagine.

## Parametri di build

| Build arg | Default | Note |
|---|---|---|
| `PWSH_IMAGE` | `mcr.microsoft.com/powershell:7.4-ubuntu-22.04` | PowerShell 7.4 LTS |
| `POWERCLI_CORE_VERSION` | `13.3.0.24145081` | versione di `VMware.VimAutomation.Core` |
| `SKIP_POWERCLI` | `0` | `1` solo per smoke test offline: senza PowerCLI il motore si chiude all'avvio |

## CI

`.github/workflows/docker-image.yml` costruisce l'immagine con PowerCLI reale, esegue uno smoke
test e, su `main` o tag `v*`, la pubblica su `ghcr.io/<owner>/mtat`.
