# Logbook: cloud-coordinamento

Sessione cloud (claude.ai/code) di coordinamento. Etichetta `sessione:cloud-coordinamento`.
Regole in `CLAUDE.md`. Voce più recente in alto.

## 2026-10-15 00:40: merge della PR #52 (tab Brownfield)
- **Fatto**: su richiesta di Daniele, merge di #52 (6299129) della sessione `requisiti-mt`. La PR
  aveva come base il branch di integrazione `claude/focused-hamilton-m4loti`, non `main`: la tab
  arriverà su `main` con la prossima PR del branch di integrazione.
- **Verifiche**: prima del merge, il risultato di `main` + #52 è stato provato in locale, perché la
  CI di #52 era precedente a #53:
  - `node tests/sizing.test.js` → ALL OK;
  - build con `Dockerfile.noapt` e `twin-e2e` su `mixed-90` → ALL OK;
  - simulatore via Playwright → nessun errore JS.

  La nuova tab non è stata provata in dettaglio.

## 2026-10-15 00:25: merge PR #53 e registrazione della sessione requisiti
- **Fatto**:
  - merge di #53 (dcb2981, CI verde) su richiesta di Daniele; branch riallineato a `main`;
    sottoscrizione e check-in rimossi;
  - registrata in `CLAUDE.md` la sessione "Requisiti Memory Tiering vSphere"
    (`sessione:requisiti-mt`), autrice della documentazione dei requisiti e della PR #52 (tab
    Brownfield).
- **Aperto**:
  - l'etichetta `sessione:requisiti-mt` non esiste ancora su GitHub: viene creata alla prima issue
    assegnata;
  - la PR #52 è basata su un `main` precedente: va aggiornata con `main` (#51/#53) prima del merge.

## 2026-10-14 23:05: merge PR #51 e regole di sizing NVMe (#39)
- **Fatto**:
  - merge di #51 (d578f6a, CI verde) su richiesta di Daniele; branch riallineato a `main`;
  - #39 (a6c0602):
    - campo "ESXi System Memory" (default 0) sottratto dalla DRAM per l'active;
    - in Greenfield, la DRAM minima include le VM DRAM-only;
    - avvisi per NVMe < DRAM e per l'assenza di mirroring;
    - ratio personalizzato limitato a 1–400%;
    - nota sull'overhead CPU.

    Regole aggiornate alla v0.7.
- **Verifiche**:
  - `node tests/sizing.test.js` → ALL OK;
  - simulatore via Playwright sul gemello, immagine di `main` contro quella nuova:
    - `lab-802`: numeri identici, cambiano solo gli avvisi;
    - `mixed-90`: in Greenfield gli host passano da 3 a 6 per i 696 GB di VM DRAM-only, come atteso;
    - nessun errore JS.
- **Aperto**:
  - valore di default della memoria di sistema ESXi (fonte o dato rilevato), decisione di Daniele;
  - branch `claude/brownfield-checklist-tab` di un'altra sessione: nessun conflitto con questo
    lavoro; la sessione va registrata in `CLAUDE.md`.

## 2026-10-14 22:40: soglie Active per host e VM (#38) e nuova issue #50
- **Obiettivo**: implementare M-WL-01…03 (picco active ≤ 50% DRAM per host, active medio della VM
  nella sua quota DRAM, domanda delle VM ≤ DRAM dell'host).
- **Fatto**:
  - motore: campi host `Active_Check`, `VM_Demand_GB`, `VM_Demand_Check`; campi VM `Active_Avg_GB`,
    `DRAM_Share_GB`, `DRAM_Fit`. Quota DRAM = memoria × 100 / (100 + ratio), con il ratio reale se il
    tiering è attivo, altrimenti 1:1. Log WARNING per ogni host o VM oltre soglia;
  - UI: colonne nelle tabelle, export CSV (colonne in coda), import che le preserva, riquadro nella
    checklist con gli host e le VM a rischio;
  - gemello `mixed-90`: `vm-twin-hot` (WARN M-WL-02), picco 60% su `esxi-twin-90-off` (WARN M-WL-01),
    VM pinned da 600 GB su `esxi-twin-90-err` (WARN M-WL-03); regole v0.6;
  - aperta #50 (nuovo scenario di rightsizing CPU/RAM delle VM, nome da definire), sub-issue di #14.
- **Verifiche**:
  - `node tests/sizing.test.js` → ALL OK;
  - build con `Dockerfile.noapt` e `SKIP_POWERCLI=1`, `twin-e2e` su `mixed-90`, `lab-802` e
    `no-clusters` → ALL OK;
  - Playwright su `mixed-90` Real-Time: colonne e riquadro dei rischi corretti, nessun errore JS.
- **Aperto**: CI sul push; verifica sul PC di Daniele. Altri profili DRAM-only (Low Latency, FT…)
  da rilevare (#42).

## 2026-10-14 21:25: merge della PR #49 su main
- **Fatto**: su richiesta di Daniele, merge di #49 (0f6b601, head 05f4764, CI verde): regola > 60 vCPU
  su ESX 9.0 (#38, che resta aperta per le soglie Active). Branch riallineato a `main`; sottoscrizione
  e check-in rimossi. Gemello avviato da Daniele sul PC (`mixed-90`): valori della checklist
  ricalcolati a mano e coerenti con lo scenario.

## 2026-10-14 21:20: regola > 60 vCPU su ESX 9.0 (#38)
- **Fatto**: `Get-VmTieringNotes` (fonte: RN VCF 9.0 Known Issues): VM > 60 vCPU su host 9.0.x →
  nota in `Tiering_Notes` + WARN nel log; nuove colonne `vCPU` e `Tiering_Notes` (tabella VM, due export
  CSV, conservate negli import). Gemello: due VM da 64 vCPU in `mixed-90` (su 9.0 e su 8.0.3);
  `tests/twin-e2e.js` controlla anche i campi per VM. Regola M-VM-10 nel documento delle regole.
- **Verifiche**: gemello 3/3 scenari ALL OK, nota solo sulla VM dell'host 9.0, 0 CRITICAL; UI in
  Chromium: colonne e CSV corretti, 0 errori JS; test del sizing ok.
- **Aperto**: aiuto a Daniele per avviare il gemello sul PC (comando lanciato fuori dalla cartella del
  repo); resto di #38 (soglie active per host e per VM).

## 2026-10-14 21:00: merge della PR #48 su main
- **Fatto**: su richiesta di Daniele, merge di #48 (merge commit 8690bec, head 2f900f1, CI verde su
  build-and-smoke-test e twin-e2e). Chiude #37. Branch di integrazione riallineato a `main`;
  sottoscrizione e check-in rimossi.
- **Aperto**: calibrazione del gemello su registrazioni reali (#47, `locale-windows`); lab 9.x (#44);
  regola > 60 vCPU su 9.0 (#38); verifiche sul PC di #32/#35.

## 2026-10-14 20:45: gemello digitale (#47) e livelli di supporto per versione (#37)
- **Obiettivo**: Daniele: il lab non è un collo di bottiglia, si valida MTAT su un gemello digitale;
  procedere con #37 dopo la conferma della GA 9.0 (confermata da `locale-windows`: RN VCF 9.0).
- **Fatto**: `twin/` (modulo PowerCLI simulato guidato da scenari JSON: lab-802, mixed-90,
  no-clusters), `docker-compose.twin.yml`, `tests/twin-e2e.js`, job CI `twin-e2e`. #37:
  `Get-TieringSupportLevel` (< 8.0.3 Not supported, 8.0.3 Tech preview, ≥ 9.0 Supported), campo
  `TieringSupport` (tabella "Support", CSV, import, log), `vcenterTieringSupport`.
- **Verifiche**: gemello in container: 3 scenari ALL OK (incl. storici 7 giorni e VM non risolvibile),
  0 CRITICAL; lab-802 riproduce i valori di `vc-lab-01`. UI su gemello in Chromium: colonna Support
  corretta per i 5 host, CSV con TieringSupport, 0 errori JS. `tests/sizing.test.js` ok. Il gemello ha
  scovato un proprio bug (List[object] in Get-Stat), corretto. CI reale: in attesa.
- **Aperto**: calibrare il gemello su registrazioni reali in sola lettura (`locale-windows`); regola
  candidata > 60 vCPU su 9.0 (Known Issue) per #38/#41.

## 2026-10-14 20:15: fattibilità, decisioni di Daniele e nuove issue (#36)
- **Fatto**: `docs/vsphere-memory-tiering-fattibilita.md` pubblicata da `locale-windows` (07cd020).
  Decisioni di Daniele: versioni su tre livelli con GA = 9.0 (commento #37, nota in fattibilità §2);
  host di lab 9.x da pianificare (#44, esxi-admin); base dati Greenfield dalla BCG con solo righe
  verificate (#45); scheda hardware Brownfield con dati reali solo in locale (#46, locale-windows).
  Commenti su #40 (controlli Brownfield mancanti) e #13 (scadenza PowerShell 7.4, nov 2026).
  `mtat-regole-memory-tiering.md` v0.3 con le fonti di #42 (KB 448305, blog VCF) e il conflitto "All locked".
- **Aperto**: release notes VCF 9.0 (#42); lab 9.x (#44); verifiche #32/#35 sul PC.

## 2026-10-14 19:55: requisiti Memory Tiering (#36)
- **Fatto**: sub-issue #37–#42 di #36 (scelte di Daniele: 8.0 U3 = tech preview, regole raggruppate
  per azione). La specifica dei requisiti `docs/vsphere-memory-tiering-requisiti.md` (scritta da
  un'altra sessione locale dal PDF 9.1, pushata da `locale-windows` in 92eb082) resta invariata.
  Aggiunta `docs/mtat-regole-memory-tiering.md`: per ogni requisito la regola MTAT (AUTO / CALC /
  CHECK / NOTE), soglia, esito e issue; profili VM DRAM-only dalla §7.1. Riferimenti in `CLAUDE.md`.
- **Aperto**: versione GA (#42), rilevamento in sola lettura per M-HW/M-VM, fonte passthrough/vGPU.

## 2026-10-14 19:40: merge della PR #27 su main
- **Fatto**: su richiesta di Daniele, descrizione della PR aggiornata (#29, #30, #32, #35) e merge
  (merge commit 8d4a126, head 1034dbb, CI verde). Chiudono al merge: #9, #21, #23, #25, #30, #32, #35.
  Branch di integrazione riallineato a `main` per il lavoro successivo; sottoscrizione alla PR e
  check-in rimossi.
- **Aperto**: verifica sul PC di #32/#35 (build 1034dbb in corso). Pagina Broadcom "Memory Tiering
  considerations and best practices" (vSphere 9.1) per #36: non raggiungibile dalla rete della
  sessione cloud (403 dal proxy) → lettura affidata a `locale-windows`.

## 2026-10-14 19:45: #35 Sizing Rationale Greenfield
- **Obiettivo**: con 1 host di carico + 1 nodo HA il testo diceva "2 hosts because your current CPU
  workload would overload fewer servers" a CPU 0,9% (segnalato da `locale-windows`, #35).
- **Fatto**: testo estratto in `describeTieredSizing()` (senza DOM): host di carico e nodi HA spiegati
  a parte, caso "fits on a single host", tutti i vincoli in parità elencati. Primo test unitario
  `tests/sizing.test.js` (#4), eseguito in CI.
- **Verifiche**: test Node 3 scenari ok (lab, parità CPU+consumed con 2 HA, Active senza HA); UI caricata
  in Chromium da container stub: funzioni definite, 0 errori JS.
- **Aperto**: #34 (avviso prerequisito ESXi 8.0 U3 nel Brownfield) da specificare; #33 chiusa come
  duplicato di #32 da `locale-windows`; costi del Sizing ricalcolati a mano da Daniele: corretti.

## 2026-10-14 19:30: #29 verificata sul PC; #32 arrotondamento totali di cluster
- **Verifiche #29** (da `locale-windows`, ef9edab): host 8.0.2 → "Not supported (ESXi 8.0.2)";
  "2 VM trovate → 2 riportate"; nessun WARN. Casi Unknown/Enabled non verificabili sul lab.
- **Fatto**: aperta #32 e corretta: `api/analyze` arrotondava a GB interi consumed/active/activeAvg
  di cluster (0,1 GB → 0 → 0,0% in checklist/matrice/export), ora 2 decimali come per host.
  Riga INFO per host nel log (stato tiering, ratio, DRAM, consumed, active, n. VM), richiesta da
  `locale-windows`.
- **Verifiche**: parse 0 errori. Effetto reale da verificare sul PC (Active cluster 0,1%).

## 2026-10-14 19:15: #30 verificata sul PC; #29 stati di tiering espliciti
- **Verifiche #30** (da `locale-windows`, 0a13902 su `vc-lab-01`): 5 moduli coerenti, ServiceModel
  caricata, analisi Real-Time "2 VM trovate → 2 riportate", MoRef/VMHost valorizzati.
- **#29**: premessa corretta da `locale-windows`: con Read-only di sistema `Get-EsxCli` funziona; il
  fallimento silenzioso veniva da #30. Resta il difetto di `SilentlyContinue` → implementati stati
  espliciti: "Not supported (ESXi x)" sotto 8.0.3 (nessuna query), "Unknown (query failed)" con WARN,
  "Unknown (no esxcli tiering namespace)", "Unknown (not queried)" quando il budget esxcli è esaurito;
  `Get-EsxCli -ErrorAction Stop`. La UI/sizing confronta solo con "Enabled": nuovi valori sicuri.
- **Verifiche**: parse 0 errori; blocco estratto dal file ed eseguito con stub per 6 casi, tutti attesi.
- **Aperto**: avviso UI unico per analisi (criterio #29) non ancora fatto; prova su host 8.0 U3.

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
