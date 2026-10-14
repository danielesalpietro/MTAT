# Logbook: cloud-coordinamento

Sessione cloud (claude.ai/code) di coordinamento. Etichetta `sessione:cloud-coordinamento`.
Regole in `CLAUDE.md`. Voce più recente in alto.

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
