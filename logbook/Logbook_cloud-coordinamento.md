# Logbook: cloud-coordinamento

Sessione cloud (claude.ai/code) di coordinamento. Etichetta `sessione:cloud-coordinamento`.
Regole in `CLAUDE.md`. Voce più recente in alto.

## 2026-10-14 12:30: ESXi Admin come sessione esterna
- **Fatto**: `CLAUDE.md`: ESXi Admin gira su un altro progetto, niente remote-control: le richieste
  al laboratorio vanno in issue `sessione:esxi-admin` e le inoltra Daniele.

## 2026-10-14 12:20: fix #9 (411 → falsi CRITICAL) e #21 (banner headless)
- **Obiettivo**: chiudere i problemi emersi dalla validazione locale.
- **Fatto**: richieste POST senza Content-Length (a cui HttpListener su Linux risponde da solo
  411) ora sono registrate come WARN e non toccano la response; response già chiusa nel catch
  esterno → WARN invece di CRITICAL. Banner di avvio specifico in headless. Sessione `esxi-admin`
  registrata in `CLAUDE.md`.
- **Verifiche**: container stub: POST senza CL → 411 con una riga WARN, 0 CRITICAL; CL:0
  same-origin 200; chunked 200; guard Host/Origin invariato (403); desktop: banner originale.

## 2026-10-14 12:25: inventario sistemi (assets)
- **Obiettivo**: un riferimento unico ai sistemi (vCenter, ESXi…), con utenti e percorso delle password.
- **Fatto**: 53be209: `assets.md` versionato con solo formato e regole (fork pubblico);
  dati reali in `assets.local.md` gitignored sul PC locale; password solo come percorso di file locale.
  `.gitignore` per segreti. Regole aggiunte a `CLAUDE.md`.
- **Aperto**: la sessione locale crea `assets.local.md` e registra `vc-lab-01`.

## 2026-10-14 12:15: organizzazione del progetto
- **Obiettivo**: impostare le regole di lavoro tra sessioni.
- **Fatto**: `CLAUDE.md` (direttive), template issue, logbook per sessione, etichette
  `sessione:*` su tutte le issue aperte.
- **Aperto**: la sessione locale crea e mantiene `logbook/Logbook_locale-windows.md`.

## 2026-10-14 12:10: issue e roadmap
- **Obiettivo**: tracciare come issue quanto emerso in questa sessione.
- **Fatto**: #11 (api/connect riusa sessioni vCenter senza verificare le credenziali),
  #12 (autenticazione UI), #13 (PowerShell 7.4 EOL nell'immagine) sotto l'epic #10; epic
  roadmap #14 con le fasi #15 (validazione su vCenter reale) … #20.
- **Verifiche**: #11 confermata leggendo il codice di `api/connect`.

## 2026-10-14 11:55: guard Host/Origin (anti DNS rebinding e CSRF)
- **Obiettivo**: chiudere i buchi segnalati dalla sessione locale (#1).
- **Fatto**: cb54261 (allowlist Host, rifiuto POST cross-origin), 132cf22 (confronto host+porta
  dell'Origin, normalizzazione `MTAT_ALLOWED_HOSTS`).
- **Verifiche**: matrice in container: Host estraneo 403, Origin localhost:3000/null/evil 403,
  same-origin e curl senza Origin 200, healthcheck `healthy`. Revisione della sessione locale: ok.

## 2026-10-14 11:47: deploy Docker (beta)
- **Obiettivo**: MTAT v3.1 turn-key in container.
- **Fatto**: 4c2268d: modalità headless opt-in nello script (`MTAT_HEADLESS`, `MTAT_PORT`,
  `MTAT_BIND_HOST`, `MTAT_DATA_DIR`), `docker/Dockerfile` (PowerShell 7.4 + PowerCLI 13.3),
  `docker-compose.yml`, CI `Docker image`, `docs/ROADMAP.md`.
- **Verifiche**: in cloud solo con PowerCLI stub (PSGallery bloccato dalla rete della sessione):
  UI servita, motore vivo oltre 60 s, healthcheck ok; modalità desktop invariata (si spegne a 60 s
  senza UI). CI con PowerCLI reale: verde. Build sul PC Windows lanciata da Daniele.
- **Aperto**: analisi su vCenter reale (#15).
