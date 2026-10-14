# Logbook: locale-windows

Sessione locale sul PC Windows di Daniele (Claude Desktop, titolo "MTAT Locale - Developer").
Etichetta `sessione:locale-windows`. Regole in `CLAUDE.md`. Voce più recente in alto.
Orari in ora locale (CEST, UTC+2).

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
