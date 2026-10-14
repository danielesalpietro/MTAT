# Logbook: cloud-coordinamento

Sessione cloud (claude.ai/code) di coordinamento. Etichetta `sessione:cloud-coordinamento`.
Regole in `CLAUDE.md`. Voce più recente in alto.

## 2026-10-14 19:05: #30 CI verde
- **Verifiche**: CI su 0a13902 verde (2 run). Log: 5 moduli della catena di Core tutti
  13.3.0.24145081 (Vim 8.3.0.24145081), `VMware.System.Private.ServiceModel 4.5.0.0` caricata,
  gate superato, smoke test ok.
- **Aperto**: rebuild e analisi Real-Time sul PC (ok di Daniele, già subordinato al verde); poi
  test #29 (Read-only vs ruolo personalizzato). PR #27 di nuovo verde.

## 2026-10-14 19:00: #30 terza iterazione: solo la chiusura di VMware.VimAutomation.Core
- **Obiettivo**: CI rossa su d795131 (dipendenza senza versione in StorageUtility) e 5519f4c
  (`VMware.Sdk.vSphere.vCenter.CertManagement` 1.0.0.0 non installabile da PSGallery): il meta
  completo trascina decine di SDK che MTAT non usa.
- **Fatto** (proposta 2 di `locale-windows`): `install-powercli.ps1` scarica solo il manifest di
  VMware.PowerCLI per le versioni, installa soltanto Core e le sue dipendenze a quelle versioni
  (`-SkipDependencyCheck`), scrive `powercli-pins.json`; `verify-powercli.ps1` controlla il set
  rispetto ai pin, fa `Import-Module` di Core e prova a caricare `VMware.System.Private.ServiceModel`.
- **Verifiche**: repo PSResource finto (esche 13.5.1/9.1, modulo fuori dalla catena, requisito senza
  versione): installati solo i 4 moduli della catena, gate ok, Import-Module ok. Il test ha trovato un
  errore di parsing nello script (`$PowerCliVersion:`), corretto prima del push. PSGallery reale → CI.

## 2026-10-14 18:55: #30 seconda correzione (CI rossa su 8b4fc92)
- **Obiettivo**: la CI ha confermato il gate: anche il meta-modulo VMware.PowerCLI 13.3 installato
  con `Install-Module` porta dipendenze transitive all'ultima versione (`VMware.Vcf.Sso` 13.5.1).
- **Fatto**: `docker/install-powercli.ps1`: installazione con `Install-PSResource
  -SkipDependencyCheck`, percorrendo i `RequiredModules` dal meta-modulo in giù a versione esatta
  (RequiredVersion o il minimo di ModuleVersion), una sola versione per modulo, build fallita su
  conflitti.
- **Verifiche**: repository PSResource locale con moduli finti e versioni "esca" più nuove: installa
  solo l'insieme coerente; `verify-powercli.ps1` passa; con una versione duplicata iniettata fallisce.
  Installazione reale da PSGallery: affidata alla CI.

## 2026-10-14 15:45: #30 PowerCLI con versioni miste nell'immagine
- **Obiettivo**: bug bloccante per #15 trovato da `locale-windows`: Core 13.3 con Common/Sdk 13.5 e
  VMware.Vim 9.1 → `Get-EsxCli` non carica gli assembly, VMHost vuoto, "0 VM(s)" senza WARN.
- **Fatto**: Dockerfile installa il meta-modulo `VMware.PowerCLI` a versione fissa (pinna tutti i
  sottomoduli) + CEIP off per AllUsers; `docker/verify-powercli.ps1` fa fallire la build se un
  modulo `VMware.*` ha più versioni o non corrisponde al manifest. Nel motore: VM accese non
  attribuite a nessun host → WARN e voce "(no host)" in `failedVms`, mai più "0 VM" silenzioso.
- **Verifiche**: parse dello script 0 errori; logica WARN provata in isolamento; verify-powercli
  fallisce senza PowerCLI. Installazione reale del meta-modulo **non eseguibile in cloud**
  (PSGallery bloccato): esito affidato alla CI.
- **Aperto**: esito CI; rebuild e analisi #15 sul PC (ok di Daniele). Nota: l'host del lab è ESXi
  8.0.2, il Memory Tiering richiede 8.0 U3.

## 2026-10-14 14:05: PR verso main del fork
- **Fatto**: aperta danielesalpietro/MTAT#27 (`claude/focused-hamilton-m4loti` → `main`, fork di
  Daniele, non upstream). Chiude #9, #21, #23, #25 al merge; #1 resta aperta (Sec-Fetch-Site).
- **Aperto**: review e merge di Daniele.

## 2026-10-14 14:00: #25 verificata sul PC (94cd510)
- **Verifiche** (da `locale-windows`, hash dello script nel container = checkout): password errata →
  UI resta in Fase 1 con errore; account RO → "0 cluster(s) found", "(no clusters found)",
  Analyze off, Import on; nessun altro WARN/ERROR/CRITICAL. Hint System.View presente nel codice,
  non riverificato dal vero (ruolo ormai assegnato).
- **Aperto**: #9, #21, #23, #25 verificate ma aperte fino al merge su `main` (proposta PR a Daniele).
  #15 attende i blade nel cluster (#22).

## 2026-10-14 13:50: #25 caso "0 cluster" verificato su vCenter reale
- **Verifiche** (da `locale-windows`, build c2700dd): ruolo Read-only assegnato a `mtat-ro`, connect
  RO riuscito, log "0 cluster(s) found", UI "(no clusters found)" e Analyze disabilitato.
  Toast e Import attivo ancora da confermare.
- **Aperto**: percorso "tutti i target falliti" (94cd510) non verificato sul PC: al prossimo build
  con password errata. #15 riprende con i blade nel cluster.

## 2026-10-14 13:40: #25: connect fallito presentato come "nessun cluster"
- **Obiettivo**: segnalazione `locale-windows`: con l'account RO senza ruolo sull'inventario il
  connect fallisce, ma la UI sbloccava la Fase 2 con "(no clusters found)".
- **Fatto**: se falliscono tutti i vCenter richiesti e nessuna sessione precedente fornisce cluster,
  la UI resta in Fase 1 con toast di errore per target e chip "failed" (cache precedente intatta).
  Nuovo hint in `Add-KnownIssueHints` per "Permission ... denied ... System.View" (assegnare
  Read-only sulla root dell'inventario con propagazione). Permesso mancante segnalato su #22.
- **Verifiche**: stub con Connect-VIServer che lancia l'errore reale: `api/connect` restituisce
  l'errore con hint; Playwright: toast error, scheda Baseline nascosta, Fase 1 attiva, 0 errori JS;
  casi 0 e 2 cluster invariati. Docker in cloud si è fermato due volte (riavviato).

## 2026-10-14 13:30: scenario "assessment offline" (#26)
- **Fatto**: recepita la decisione di Daniele (riportata da `locale-windows` in #26): oltre al
  self-assessment live, il fork serve il system integrator con import standalone completo
  (RVTools, Live Optics, template) senza vCenter. Aggiunta sezione "Scenari d'uso" a `docs/ROADMAP.md`.
- **Aperto**: specifiche di #26 e #24 da chiudere con Daniele prima dello sviluppo. #25 in verifica
  sul PC (build c2700dd, in attesa del login con l'account RO).

## 2026-10-14 13:20: #25 rivisto: import offline raggiungibile anche senza cluster
- **Obiettivo**: effetto collaterale segnalato da `locale-windows`: con 0 cluster il `return` di
  72ef773 lasciava bloccate le schede e quindi anche l'Import offline.
- **Fatto**: con 0 cluster le schede si sbloccano; menu cluster (Baseline e Simulator) e Analyze
  disabilitati con voce "(no clusters found)"; l'avviso indica che l'import Matrix/History resta
  disponibile. L'import singolo MTAT/RVTools richiede già oggi un cluster live selezionato:
  limite preesistente, coperto da #26 (import senza vCenter).
- **Verifiche**: Playwright su container stub: 0 cluster → avviso, select/Analyze disabilitati,
  schede visibili, pannello Import apribile, tab Simulator senza errori; 2 cluster → invariato.

## 2026-10-14 13:05: #15 primo contatto con vc-lab-01; fix #25 (nessun cluster)
- **Obiettivo**: gestire l'esito della prima connessione reale (riportato da `locale-windows`).
- **Fatto**: login su `vc-lab-01` riuscito ma il lab non ha cluster → aperta #25 e corretta:
  avviso in UI e schede bloccate se la lista cluster è vuota; log del numero di cluster per vCenter.
  La funzionalità "host standalone / lista di host" è #24 (bozza di Daniele, aperta da `locale-windows`).
- **Verifiche**: container con PowerCLI stub (0 e 2 cluster): `api/connect` → `[]` / 2 voci, riga di
  log corretta; UI in Chromium headless (Playwright): con 0 cluster avviso e schede bloccate, con 2
  cluster menu popolato e schede sbloccate, 0 errori JS. Build in cloud da Dockerfile senza il passo
  `apt` (tzdata), non installabile da questa rete; la build reale resta alla CI.
- **Aperto**: `vc-lab-01` risulta API 8.0.0.1 (probabilmente 8.0 GA): il Memory Tiering richiede
  8.0 U3, da confermare in #22. Login fatto con administrator@ per scelta di Daniele (annotato in
  #15); serve l'account in sola lettura.

## 2026-10-14 12:45: verifica locale di #9, #21, #23 e build per #15
- **Obiettivo**: confermare sul PC Windows le correzioni fatte in cloud.
- **Fatto**: sessione rinominata "MTAT Supervisor"; titoli delle sessioni in `CLAUDE.md` (9986baf);
  build per #15 affidata a `locale-windows` (lanciata dopo l'ok diretto di Daniele nella sua chat).
- **Verifiche** (riportate da `locale-windows` sul build 9986baf): #23 fuso Europe/Rome e log in
  ora locale; #21 banner headless; #9 POST senza Content-Length → 411, una riga WARN, 0 CRITICAL;
  matrice #1 invariata; container healthy, 0 restart. CI verde su 2fb223c. Banner desktop
  verificato solo in cloud (container stub), non sul PC.
- **Aperto**: #15 attende l'accensione di `vc-lab-01` (#22, sessione esterna esxi-admin).
  #9/#21/#23 si chiudono al merge su `main`.

## 2026-10-14 12:35: fuso orario nel container (#23)
- **Obiettivo**: log del container nell'ora locale (segnalazione `locale-windows`).
- **Fatto**: `tzdata` installato nel Dockerfile; controllo `TimeZoneInfo` nello smoke test CI.
- **Verifiche**: causa confermata (immagine base senza `/usr/share/zoneinfo` → UTC). In cloud il
  passo `apt-get` **non è eseguibile** (il proxy della sessione accetta solo HTTPS): verificato con
  un'immagine di test con zoneinfo copiata → log in ora di Roma. Build reale con apt: affidata alla CI.
- **Aperto**: esito CI; riverifica sul PC locale al prossimo build.

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
