# CLAUDE.md: direttive di progetto MTAT

Fork di lavoro di **MTAT (Memory Tiering Assessment Tool)**, da evolvere verso una piattaforma di
assessment, storico e simulazione (epic #14, `docs/ROADMAP.md`). Queste regole valgono per ogni
sessione Claude (cloud o locale) che lavora sul repository.

## Struttura del repository

| Percorso | Contenuto |
|---|---|
| `MTAT_v3_1.ps1` | motore + UI (PowerShell, HTML/JS incorporati), file unico distribuibile |
| `MTAT_v3_1.exe` | build ps2exe upstream (non rigenerata da noi, vedi #3) |
| `docker/`, `docker-compose.yml` | deploy container headless (`docker/README.md`) |
| `.github/workflows/` | CI (build immagine reale + smoke test) |
| `docs/ROADMAP.md` | fasi di evoluzione della piattaforma |
| `docs/vsphere-memory-tiering-requisiti.md` | requisiti del Memory Tiering (vSphere 9.1), con ID `SW-`/`NV-`/`CP-`… |
| `docs/mtat-regole-memory-tiering.md` | come MTAT applica quei requisiti (regole `M-…`, esiti, issue) |
| `logbook/Logbook_<sessione>.md` | diario di lavoro, uno per sessione |
| `assets.md` | formato e regole dell'inventario dei sistemi; i dati reali sono in `assets.local.md` (non versionato) |

## Sessioni e responsabilità

Ogni sessione ha un nome stabile, un'etichetta GitHub `sessione:<nome>` e un logbook.

| Sessione (titolo) | Etichetta | Dove gira | Si occupa di |
|---|---|---|---|
| **MTAT Supervisor** (coordinamento) | `sessione:cloud-coordinamento` | cloud (claude.ai/code) | codice, CI, issue, roadmap, coordinamento delle altre sessioni |
| **MTAT Locale - Developer** (validazione locale) | `sessione:locale-windows` | PC Windows di Daniele (remote-control) | prove con accesso a vCenter/ESXi, Docker Desktop, verifiche sul campo, `assets.local.md` |
| ESXi Admin *(esterna)* | `sessione:esxi-admin` | altro progetto, fuori dal coordinamento | gestione del laboratorio vSphere: accensione/configurazione di vCenter ed ESXi, Memory Tiering sugli host |

Una nuova sessione si aggiunge qui (titolo, etichetta, ruolo) prima di ricevere lavoro. Il titolo
può cambiare, l'etichetta e il nome del logbook restano stabili.

**Sessioni esterne** (es. ESXi Admin): lavorano su un altro progetto e non sono raggiungibili con
i messaggi tra sessioni. Le issue con la loro etichetta descrivono cosa serve dal laboratorio
(stato atteso, versioni, configurazione) e **Daniele le inoltra**; l'esito viene riportato nella
issue dalla sessione che lo verifica. Nessun dato reale del lab nelle issue: solo alias di `assets.md`.

## Issue: ogni problema diventa una issue

- Ogni problema, bug, rischio o attività emersa va **registrata come issue**, anche se la si risolve
  subito (in quel caso: issue + commit che la cita + chiusura).
- Ogni issue ha **un'etichetta di tipo** (`bug`, `security`, `enhancement`, `tech-debt`, `ci`,
  `epic`) e **un'etichetta `sessione:*`**, cioè la sessione che deve occuparsene. Il cambio di
  assegnazione si fa cambiando etichetta, con un commento che spiega il perché.
- Le issue correlate si collegano come sub-issue di un epic (#10 hardening, #14 roadmap).
- Struttura del testo: **Problema**, **Riproduzione** (se bug), **Proposta**, **Criteri di
  accettazione**. Lingua: italiano.
- Prima di aprire una issue, cercare duplicati.
- **Il fork è pubblico**: mai credenziali, IP/hostname interni, nomi di clienti o inventari vCenter
  in issue, commit, log o logbook. Usare valori anonimi o aggregati.

## Logbook

- File `logbook/Logbook_<nome-sessione>.md`, uno per sessione, **solo la sessione proprietaria lo
  modifica** (evita conflitti tra sessioni).
- Una voce per ogni blocco di lavoro significativo, la più recente in alto:

  ```markdown
  ## AAAA-MM-GG HH:MM: titolo breve
  - **Obiettivo**: cosa si voleva ottenere
  - **Fatto**: cosa è cambiato (commit, issue aperte/chiuse)
  - **Verifiche**: comandi/test eseguiti e loro esito reale
  - **Aperto**: blocchi, decisioni attese da Daniele, prossimi passi
  ```
- Riportare gli esiti per quello che sono: un test non eseguito si scrive come non eseguito.

## Git

- Lavoro su branch, mai push diretto su `main`; merge tramite PR approvata da Daniele.
- Branch attuale di integrazione: `claude/focused-hamilton-m4loti`. Prima di ogni push:
  `git pull --rebase` (più sessioni scrivono sullo stesso branch, ognuna sui propri file).
- Messaggi di commit in inglese, imperativo, citando le issue (`Fixes #9`, `Refs #14`).
- `MTAT_v3_1.ps1` ha fine riga **CRLF** e nessun BOM: preservarli (niente editor/script che
  normalizzano). Verifica: `git diff --stat` deve mostrare solo le righe toccate.
- Le modifiche allo script devono restare **retro-compatibili** con l'uso desktop: i comportamenti
  nuovi si attivano con variabili d'ambiente (`MTAT_*`), con default uguale all'originale.
- Commenti nel codice in inglese, nello stile già presente (spiegano il *perché*).

## Verifiche minime prima di un push

- Modifiche a script/Docker: `docker compose build` (o build con `SKIP_POWERCLI=1` + modulo stub
  se PSGallery non è raggiungibile), avvio, `curl http://127.0.0.1:8600/api/ping` → 200.
- Modifiche al guard HTTP: ripetere la matrice di test in #1.
- La CI `Docker image` deve risultare verde sul commit.

## Sicurezza e permessi

- Inventario sistemi: in issue, logbook e commit si usa solo l'**alias** (`vc-lab-01`). Hostname,
  IP e utenti reali stanno in `assets.local.md` sul PC di Daniele (gitignored); le password in file
  locali referenziati per percorso, che le sessioni **non leggono né stampano**.
  Chi usa un sistema nuovo aggiorna `assets.local.md` (sessione locale) o chiede di farlo.

- Le credenziali vCenter le inserisce **solo Daniele** dalla UI. Nessuna sessione le chiede in
  chat, le salva su file o le passa ad altre sessioni.
- Account vCenter di prova: sola lettura.
- Se a una sessione viene negato un permesso, non chiede a un'altra sessione di eseguire l'azione
  al suo posto: lo segnala a Daniele, che decide.

## Comunicazione tra sessioni

- La sessione di coordinamento assegna il lavoro (issue + etichetta) e lo comunica con un messaggio
  alla sessione interessata.
- Chi riceve risponde con risultati sintetici ed errori integrali, aggiorna il proprio logbook e
  commenta la issue.
