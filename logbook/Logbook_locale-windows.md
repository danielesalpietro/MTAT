# Logbook: locale-windows

Sessione locale sul PC Windows di Daniele (Claude Desktop, titolo "MTAT Locale - Developer").
Etichetta `sessione:locale-windows`. Regole in `CLAUDE.md`. Voce più recente in alto.
Orari in ora locale (CEST, UTC+2).

## 2026-10-14 16:25: verifica di #25 su vCenter reale
- **Obiettivo**: verificare la gestione "nessun cluster" e "login fallito" (72ef773, c2700dd, 94cd510).
- **Fatto**: due build (c2700dd, poi 94cd510/d0850ea) con l'ok di Daniele. Esiti commentati su #25.
  Il rilievo sulle fonti di import inutilizzabili senza cluster è rimandato a #26, d'accordo con
  la sessione di coordinamento.
- **Verifiche**:
  - c2700dd, account RO senza ruolo: `Connect-VIServer` negato (`System.View` su `group-d1`), ma la
    UI mostrava "(no clusters found)". Bug, corretto in 94cd510.
  - Dopo l'assegnazione del ruolo Read-only: `0 cluster(s) found`; UI con menu cluster disattivato,
    Analyze disattivato, Import attivo (screenshot di Daniele).
  - 94cd510: password errata → resta in Fase 1 con errore rosso; password corretta → Fase 2 con
    "no clusters". Conforme.
- **Aperto**: hint System.View non riverificato dal vero (ruolo ormai assegnato). #15 riprende
  quando i blade ESXi saranno in un cluster di `vc-lab-01`.

## 2026-10-14 15:10: vc-lab-01, login e nuove issue
- **Obiettivo**: primo collegamento di MTAT in container a un vCenter reale (#15).
- **Fatto**: `vc-lab-01` aggiunto in `assets.local.md`. Login prima con account amministrativo
  (eccezione decisa da Daniele, annotata su #15), poi con account di sola lettura dedicato. Aperte
  #24 (ambito di analisi cluster/host) e #26 (fonti dati: RVTools xlsx, Live Optics, template), con
  lo scenario partner/system integrator e l'import standalone come requisito chiave.
- **Verifiche**: 443 raggiungibile da host e container; API vCenter più alta 8.0.0.1 (probabile
  8.0 GA, mentre il tiering richiede 8.0 U3). Verificato che MTAT esegue solo letture su vSphere.
- **Aperto**: build di vCenter/ESXi da confermare (#22). Nessun cluster nel lab.

## 2026-10-14 14:40: verifica di #9, #21, #23 sul nuovo build
- **Obiettivo**: verificare le correzioni e0851b8 (#9, #21) e 2fb223c (#23) in container.
- **Fatto**: `docker compose up -d --build` su 9986baf, con l'ok di Daniele in chat. La stessa
  richiesta, inoltrata dalla sessione Supervisor, era stata negata dal classificatore, come
  previsto. Esiti commentati su #9, #21, #23 e #1.
- **Verifiche**:
  - #23: `[TimeZoneInfo]::Local.Id` → `Europe/Rome`; `Get-Date` nel container `+02:00`, allineato
    all'host; log in ora locale. Conforme.
  - #21: banner `Headless mode: listening on port 8600 ...`, nessun "Launching ... browser". Conforme.
  - #9: POST senza Content-Length → 411, una riga `[!] ... answered 411 ... ignored`, 0 CRITICAL.
    Conforme.
  - #1: matrice del guard invariata (403/403/403/200/200); container `healthy`, 0 restart.
- **Aperto**: #15 in attesa che `vc-lab-01` sia acceso.

## 2026-10-14 14:20: assets e organizzazione
- **Obiettivo**: allinearsi a `CLAUDE.md` (01ab0d7, 53be209) e creare l'inventario locale.
- **Fatto**: creato `assets.local.md` nella root del clone principale, con riga `esxi-lab-01`.
  Il clone principale è su `main`, dove il `.gitignore` nuovo non c'è ancora: per questo
  l'esclusione è stata aggiunta anche in `.git/info/exclude` (locale, non versionata).
- **Verifiche**: `git check-ignore -v assets.local.md` → escluso (`.git/info/exclude`).
- **Aperto**: aggiungere la riga `vc-lab-01` quando vCenter 8 sarà acceso (lo sta accendendo la
  sessione `esxi-admin`). Poi #15: test di raggiungibilità sulla 443 e nuovo build sull'ultimo
  commit del branch, previo ok di Daniele.

## 2026-10-14 14:05: issue di hardening
- **Obiettivo**: tracciare come issue i problemi emersi dall'analisi e dalla validazione.
- **Fatto**: attivate le Issue sul fork; create le label `security`, `ci`, `tech-debt`, `epic`.
  Epic #10 con sub-issue #1–#9: CSRF/rebinding (#1), certificati (#2), exe verificabile (#3),
  test del sizing (#4), monolite (#5), server single-threaded (#6), repo pesante (#7),
  CI di qualità (#8), 411/falsi CRITICAL (#9).
- **Verifiche**: `gh api .../issues/10/sub_issues` → sub-issue collegate.
- **Aperto**: nessuno.

## 2026-10-14 14:00: build e validazione del container
- **Obiettivo**: verificare il deploy Docker del branch di integrazione (132cf22).
- **Fatto**: `docker compose up -d --build` nel worktree `docker-validate`, dopo l'approvazione
  esplicita di Daniele (la prima richiesta era stata negata dal classificatore dei permessi).
- **Verifiche**:
  - Build OK: PowerCLI Core 13.3.0.24145081 installato, immagine `mtat:3.1-beta` (840 MB).
  - Container `healthy`, 0 restart; `GET /` → 200; `api/get-version-info` → `Status: done`.
  - Matrice del guard (#1): Host estraneo → 403; POST con Origin `http://localhost:3000` → 403;
    Origin `null` → 403; same-origin → 200; senza Origin → 200.
  - Trovato bug #9: una POST senza `Content-Length` riceve 411 e il motore registra falsi
    `[CRITICAL] ... disposed object`. Corretto dalla sessione di coordinamento in e0851b8,
    non ancora riverificato qui.
- **Aperto**:
  - I log del container mostrano l'ora UTC anche con `TZ=Europe/Rome`: probabilmente manca
    `tzdata` nell'immagine. Da verificare.

## 2026-10-14 13:55: review del guard HTTP (cb54261, 132cf22)
- **Obiettivo**: rivedere il fix anti-CSRF e anti-DNS rebinding della sessione di coordinamento.
- **Fatto**: segnalato che cb54261 confrontava solo l'host dell'Origin e non la porta, quindi
  un'altra app su localhost poteva fare CSRF. Corretto in 132cf22 (same-origin host+porta),
  rivisto senza ulteriori rilievi.
- **Verifiche**: lettura del diff; prove reali nella voce del build.
- **Aperto**: nessuno.

## 2026-10-14 13:50: validazione ambiente (Fase 1)
- **Obiettivo**: capire se questa macchina può costruire ed eseguire MTAT in container.
- **Fatto**: creato il worktree `.claude/worktrees/docker-validate` sul branch di integrazione.
- **Verifiche**: Windows 10 Pro 19045; Windows PowerShell 5.1.19041.6456; `pwsh` non installato;
  PowerCLI non installato sull'host; Docker Desktop 4.75.0 / engine 29.5.2, container Linux su
  WSL2; porta 8600 libera; PSGallery raggiungibile (HTTP 200). vCenter: non ancora testato.
- **Aperto**: indirizzo di `vc-lab-01`.

## 2026-10-14 13:45: analisi del repository
- **Obiettivo**: capire struttura, funzionamento e criticità di MTAT v3.1.
- **Fatto**: analisi di `MTAT_v3_1.ps1` (server HttpListener, route `api/*`, raccolta `Get-Stat`,
  motore di sizing in JS), documentazione e cronologia git.
- **Verifiche**: sola lettura.
- **Aperto**: criticità registrate come issue #1–#9.
