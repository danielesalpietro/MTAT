# Fattibilità tecnica: MTAT × Memory Tiering over NVMe (vSphere 9.1)

**Documento collegato:** [vsphere-memory-tiering-requisiti.md](vsphere-memory-tiering-requisiti.md) (requisiti dal PDF VMware vSphere 9.1).
**Fonti di questa analisi:**
- 27 issue aperte di `danielesalpietro/MTAT` (#1–#36, stato del 2026-10-14);
- codice e documentazione del branch `claude/focused-hamilton-m4loti` (`MTAT_v3_1.ps1`, `CLAUDE.md`, `docs/ROADMAP.md`, `logbook/`);
- ricerca web sul supporto hardware (vedi §5 per i limiti).

---

## 1. Sintesi

| Area | Fattibilità | Nota in una riga |
|---|---|---|
| Sicurezza e hardening (#1, #2, #11, #12, #31) | **Alta** | Quasi tutto è codice piccolo e isolato; #1 ha già il fix sul branch, manca il merge. |
| Build, CI, repo (#3, #7, #8, #13) | **Alta** | Fattibile con GitHub Actions. **#13 ha una scadenza**: PowerShell 7.4 esce dal supporto a novembre 2026. |
| Rilevamento stato tiering (#29) | **Alta sul codice, bloccata sul lab** | Il codice è già stato corretto in gran parte (stati espliciti). Non si può validare: il lab non ha host con tiering. |
| Compatibilità e prerequisiti (#34, #36) | **Media-alta** | Molte regole sono leggibili via API vSphere. Alcune (HA, DRS, GPU) sono solo avvisi da documentazione. **La versione minima va corretta a 9.1.** |
| Ambito host / lista host (#24) | **Media** | Fattibile, ma cambia le regole di sizing per gli host standalone. |
| Import RVTools/Live Optics/template (#26) | **Media** | RVTools XLSX e template: fattibili. Live Optics SIOKIT: **formato non documentato, serve un file di esempio**. |
| Setup/Ripristino vCenter (#28) | **Media-bassa** | Tecnicamente fattibile, ma è scrittura su vCenter del cliente: rischio alto, richiede disegno e test approfonditi. |
| Piattaforma: storico, DB, vLLM (#16–#20) | **Media → bassa** | Fasi a valle; #19 richiede GPU; #17 dipende dai test di #4. |
| Validazione reale del tiering (#15, #22) | **Bloccata** | Il lab è vCenter 8.0 + ESXi 8.0.2 senza tiering. Serve un host ESXi 9.1 con NVMe Mixed Use. |

**Conclusione.** Il percorso software è realizzabile. Il collo di bottiglia è il **laboratorio**: senza un host ESXi 9.1 con NVMe dedicato non si può validare nessuna funzione di tiering end-to-end, né il calcolo brownfield né la rilevazione dello stato. Va risolto prima di scrivere altro codice sul tiering.

---

## 2. Correzione necessaria: versione minima

> **Decisione di Daniele (2026-10-14), successiva a questa analisi:** MTAT usa tre livelli,
> < 8.0 U3 *Not supported*, 8.0 U3 *Tech preview*, ≥ 9.0 *Supported* (GA da confermare con le
> release notes di VCF 9.0). La proposta "soglia unica 9.1" qui sotto è superata. Dettagli in #37.

Il PDF (requisiti in §2 della spec) dice **vCenter 9.1+ ed ESX 9.1+**. Il codice e le issue dicono altro:

| Fonte | Versione minima indicata |
|---|---|
| PDF VMware vSphere 9.1 (documento di riferimento) | **vCenter 9.1+, ESX 9.1+** |
| MTAT, issue #34 e #36, `docs/ROADMAP.md` e logbook | **vSphere 8.0 U3+** |
| Stato "Not supported (ESXi x)" nel codice | soglia **8.0.3** |
| Fonti web secondarie (blog, Lenovo) | 9.0+ |

**Azione proposta:** allineare MTAT alla 9.1 (vCenter e ESX), come da documentazione ufficiale. Vanno cambiati: la soglia di `Not supported` nel codice, il testo di #34, #36 e #22. Con 8.0 U3 MTAT mostrerebbe host come candidati che la documentazione esclude. Non ho ancora verificato se la 8.0 U3 sia davvero esclusa in una release precedente; il PDF non la menziona.

---

## 3. Mappa delle issue aperte

Legenda fattibilità: **A** alta · **M** media · **B** bassa. Effort: **S** (ore), **M** (giorni), **L** (settimane).

### 3.1 Bloccanti per il tiering

| # | Titolo (sintesi) | Fattibilità | Effort | Impatto sul tiering | Dipendenze / note |
|---|---|---|---|---|---|
| **15** | Validare il container su vCenter/ESXi reali | **B** (bloccata) | M | Senza un host 9.1 con NVMe non si verifica il tiering. Già validati: login, ruolo RO, cluster-ranges, analyze Real-Time. | Dipende da **#22** (lab). Confronto desktop ancora da fare. |
| **22** | Prerequisiti lab per la validazione | **A** | S (richiesta) | Richiede vCenter e ESXi 9.1 con NVMe. Lo stato attuale del lab non lo soddisfa. | Inoltro a Daniele per la sessione esxi-admin. |
| **29** | `Get-EsxCli` senza permessi → "Disabled" silenzioso | **A** (codice) | S | Causa un falso negativo sul tiering: il sizing parte da un presupposto errato. Sul branch è già corretto in gran parte (`ef9edab`: stati espliciti). | Rimangono: avviso UI unico per analisi, documentazione del ruolo personalizzato, verifica del privilegio `Host.Config.AdvancedConfig` su host 9.1. |
| **34** | Avviso prerequisito upgrade per host < soglia | **A** | S | Il Brownfield oggi simula il tiering su host non supportati senza avvisare. | **Va cambiata la soglia da 8.0 U3 a 9.1** (vedi §2). |
| **36** | Controlli di compatibilità e prerequisiti | **M** | L (per regola) | Oggi il sizing rischia di essere ottimistico. Le regole che il PDF definisce sono in §3.2. | Dettaglio in §3.2. Ogni regola richiede la fonte ufficiale e un caso di test. |

### 3.2 Regole di compatibilità: cosa si può rilevare

Dal PDF (spec §5, §7, §10) e dall'issue #36. Il rilevamento tramite API vSphere è da **verificare campo per campo** su un host reale: qui indico solo la fattibilità teorica.

| Regola (fonte: PDF) | Rilevabile con | Fattibilità |
|---|---|---|
| Versione vCenter/ESX ≥ 9.1 | `Get-VMHost` / `About` del vCenter | **A** |
| VM > 512 GB RAM e 64 vCPU: degrado possibile | `Get-VM` (`MemoryGB`, `NumCpu`) | **A** |
| Low Latency, Confidential, FT, Large, Nested (eccetto VBS): esclusa dal tiering | `ExtensionData` della VM (latency sensitivity, FT, confidential, nested HV) | **M** (da verificare per campo) |
| `sched.mem.enableTiering = FALSE` già impostato | Advanced settings della VM | **A** (già in parte: `sched.mem.enableTiering`) |
| `Pinned_Memory` / reservation completa | `MemoryReservationLockedToMax` (già usato) | **A** (già implementato) |
| PCI passthrough / vGPU / SR-IOV: memoria bloccata | Device list della VM (`ExtensionData.Config.Hardware.Device`) | **M** (il rilevamento completo va provato sui tre casi) |
| Quick Boot attivo sull'host: non supportato | Impostazione host | **M** (non verificato su API) |
| Suspend-to-memory: non supportato | Configurazione VM | **M** |
| Optane PMem o NVDIMM-N presenti sull'host | Inventario hardware host | **M** |
| Memory overcommit attivo: sconsigliato | Configurazione cluster/host (ballooning, swap) | **M** |
| NVMe dedicato, nessun claim vSAN | Dischi host + stato vSAN | **M** (da provare su host reale) |
| HA restart policy | Config HA cluster | **A** (solo avviso) |
| DRS con host tiered e non tiered nello stesso cluster | Config DRS | **A** (solo avviso, nessun calcolo) |

**Difficoltà reali:**
- Molte regole valgono solo come **avviso** (HA, DRS, consumo tra host): il sizing non può quantificarle.
- Le regole VM si possono validare solo con VM di prova su un host 9.1. Oggi il lab non le ha.

### 3.3 Interfaccia, ambito e dati

| # | Titolo (sintesi) | Fattibilità | Effort | Note |
|---|---|---|---|---|
| **24** | Ambito di analisi: cluster **o** lista di host | **M** | L | Richiede una chiave di identità per il gruppo (oggi `vcenter\|cluster`, usata da cache, matrice, CSV). Va definita prima del codice, per non rompere i file esistenti. Sizing per host standalone: va deciso se applicare i vincoli di cluster (HA, CPU cap 80%). |
| **26** | Import RVTools/Live Optics/template XLSX/CSV | **M** | L | RVTools XLSX: fattibile, serve un parser XLSX nel browser (la UI è offline e single-file, quindi la libreria va incorporata e va verificata la licenza). **Live Optics SIOKIT: formato non documentato**, serve un file di esempio prima di stimare. Template: fattibili. Import standalone senza vCenter: il requisito chiave del partner. |
| **28** | Setup vCenter (account RO, ruolo, Statistics Level) e Ripristino | **M-B** | L | Tecnicamente possibile, ma: creare utenti SSO richiede il modulo `VMware.vSphere.SsoAdmin` o le API REST (non incluse oggi); il ripristino deve confrontare lo stato con lo snapshot. Scrive sul vCenter del cliente: richiede disegno, test di idempotenza e revisione di sicurezza. |

### 3.4 Sicurezza

| # | Titolo (sintesi) | Fattibilità | Effort | Note |
|---|---|---|---|---|
| **1** | CSRF e DNS rebinding | **A** | S | Fix già sul branch (`cb54261`, `132cf22`), verificato in container. Manca il merge su `main` e la valutazione di `Sec-Fetch-Site`. |
| **2** | `InvalidCertificateAction` non configurabile | **A** | S | Variabile `MTAT_CERT_ACTION`, default retrocompatibile, avviso in UI. |
| **11** | Riuso di sessioni vCenter senza verifica credenziali | **A** | M | Critico solo in container condiviso. Breve termine: riverificare le credenziali o usare un token di sessione. |
| **12** | Autenticazione UI oltre localhost | **M** | M-L | Opzione rapida: reverse proxy con TLS (profilo compose). Opzione nativa: token all'avvio, più lavoro. In ogni caso TLS. |
| **31** | "Exit Engine" riavvia il container | **A** | S | Rinominare in "Reset sessions" o nascondere in headless. |

### 3.5 Build, qualità, repo

| # | Titolo (sintesi) | Fattibilità | Effort | Note |
|---|---|---|---|---|
| **3** | Build riproducibile dell'exe (CI + SHA256) | **A** | M | Runner Windows in GitHub Actions, ps2exe a versione fissata. La firma Authenticode richiede un certificato (costo). |
| **4** | Test della matematica di Sizing | **A** | M | Esiste già `tests/sizing.test.js` (3 scenari). Estendere alle fixture del CHANGELOG e ai casi limite (4096 GB, CPU 80%, Active 50%). |
| **5** | Modularizzare il monolite (3.700 righe) | **M** | L | Fattibile, ma va fatto dopo #4. Conflitto con la regola CRLF di `CLAUDE.md`: il build deve preservarla. |
| **6** | Server HTTP single-threaded | **M** | M | Runspace o job con polling. Rischio: sessioni VIServer globali, non thread-safe. |
| **7** | Repo pesante (video 87 MB, binari) | **A** (tecnica) | S | Spostare il video in Release. La riscrittura della storia cambia gli SHA: decisione di Daniele. |
| **8** | CI di qualità (PSScriptAnalyzer, test) | **A** | M | Parte già presente (`docker-image.yml`). Aggiungere lint e test. |
| **10** | Epic hardening | — | — | Raccoglie #1, #2, #3, #6, #8, #11, #12, #13. |
| **13** | PowerShell 7.4 a fine supporto | **A** | S-M | **Scadenza: novembre 2026.** Base `ubuntu:24.04` + PowerShell LTS corrente; PowerCLI da verificare con la versione di vCenter 9.1. |

### 3.6 Piattaforma (epic #14, fasi 0–5)

| # | Fase | Fattibilità | Effort | Dipendenze e rischi |
|---|---|---|---|---|
| **14** | Epic roadmap | — | — | Dipende da #6, #11, #12 prima di esporre a più utenti. |
| **16** | Fase 1: persistenza dei risultati (JSON) | **A** | M | Schema versionato, anonimizzazione opzionale (hash salato). |
| **17** | Fase 2: Postgres + FastAPI + port del sizing | **M** | L | Port del sizing in Python con test di equivalenza con il JS. Dipende da #4. |
| **18** | Fase 3: knowledge library (RAG) | **M** | M-L | Il rischio è legale: licenze e riservatezza del corpus (note interne, report clienti). |
| **19** | Fase 4: vLLM self-hosted | **B-M** | L | Richiede GPU NVIDIA. L'LLM non calcola i numeri: solo tool deterministici (già nei principi). |
| **20** | Fase 5: what-if e confronti | **M** | L | Riproducibilità: stessi input → stesso output. Dipende da #16 e #17. |

---

## 4. Brownfield: stato e verifiche da fare sul candidato

**Dato mancante:** l'hardware brownfield candidato non è nel repository né nelle issue. Per completare l'analisi servono i dati della scheda qui sotto.

### 4.1 Cosa già fa il motore (branch)

- Modalità di input: rapporto (1:1 … 1:4), dimensione drive per host (800 GB, 1,6 TB, 3,2 TB, 6,4 TB, tutti Mixed Use 3 DWPD), percentuale personalizzata.
- Limite di 4096 GB NVMe per host in tutte le modalità; limite di 4× del rapporto nelle modalità drive e percentuale personalizzata.
- Costi configurabili: DRAM $100/GB, NVMe $0,25/GB (valori predefiniti), mirror = ×2 drive.
- Avviso "1:1 consigliato", vincolo Active ≤ 50% DRAM.

### 4.2 Cosa manca per il Brownfield (secondo il PDF)

| Controllo | Stato nel motore | Azione |
|---|---|---|
| Versione ESX/vCenter ≥ 9.1 | Soglia 8.0.3 nel codice | Correggere (§2) |
| Slot NVMe liberi e dedicati per host | Non verificato | Aggiungere un campo "slot NVMe disponibili" per host |
| Drive Mixed Use 3 DWPD, classe D/F/G | Solo menu di dimensioni | Campo "modello drive" e validazione dei criteri BCG |
| Nessun Optane/NVDIMM-N | Non verificato | Rilevamento via inventario (§3.2) |
| Quick Boot disattivato | Non verificato | Rilevamento o avviso |
| Partizioni esistenti da eliminare | Non rilevabile | Avviso di procedura (KB 323144) |
| Host in maintenance per ogni modifica | Documentazione | Nota nel report |

### 4.3 Scheda da compilare per il candidato brownfield

| Campo | Valore |
|---|---|
| Marca e modello server | *da compilare* |
| CPU (modello, socket, core) | *da compilare* |
| DRAM per host (GB) e DIMM disponibili | *da compilare* |
| NVMe: modello, capacità, endurance (DWPD), classe D/F/G | *da compilare* |
| Slot NVMe per host (liberi / totali) | *da compilare* |
| Controller RAID (se si usa RAID hardware invece del mirror software) | *da compilare* |
| Versione ESXi target (deve essere 9.1+) | *da compilare* |
| vCenter target (deve essere 9.1+) | *da compilare* |
| vSAN nel cluster? (in tal caso il drive deve essere libero o rimosso dal disk group) | *da compilare* |
| Optane / NVDIMM-N presenti | *da compilare* |

Con questi dati si può fare il calcolo con il motore esistente e verificare i vincoli della tabella §4.2.

---

## 5. Greenfield: configurazione target Cisco UCS / UCSX

### 5.1 Stato della certificazione (verifica)

- **Non ho trovato alcuna fonte pubblica che certifichi i sistemi Cisco UCS o UCSX per il Memory Tiering.** Le ricerche hanno trovato solo:
  - il Cisco X210c M8 All-NVMe come **vSAN ReadyNode** certificato da Broadcom e Cisco (vSAN, non Memory Tiering);
  - il X210c M7 con fino a **6 drive NVMe hot-plug** con controller passthrough e fino a 2 M.2 SATA con RAID hardware.
- La certificazione per il Memory Tiering si verifica nella **Broadcom Compatibility Guide**: ricerca *vSAN SSD*, filtro *Device Type = NVMe* e *Endurance/Performance class*. Il PDF non cita un elenco di server, quindi il controllo va fatto sul sito e sulla scheda del singolo modello.
- **Quindi la "base dati di sistemi Cisco certificati" va costruita a partire dalla BCG, non da fonti secondarie.** Finché non è verificata, ogni riga è *non verificata*.

### 5.2 Target proposto (da validare)

| Scelta | Motivo | Rischio |
|---|---|---|
| **Piattaforma primaria: UCS X210c M8** (chassis X9508) | Versione più recente trovata nelle fonti Cisco; All-NVMe già validata come vSAN ReadyNode | Certificazione per il Memory Tiering non verificata |
| **Alternativa: UCS C240 M8 rack** | Più bay NVMe per host, più semplice da cablare per due drive di mirror + eventuale vSAN | Da confrontare con X210c |
| **Ripiego: X210c M7** | Fino a 6 NVMe hot-plug, già ampiamente installato | Versione più vecchia, verificare il supporto a ESXi 9.1 |

Configurazione di riferimento per un host greenfield (valori da confermare sulla scheda tecnica e nella BCG):

| Componente | Valore proposto | Motivo |
|---|---|---|
| Rapporto DRAM:NVMe | **1:1** | Default raccomandato dal PDF; "adatto a un'ampia gamma di workload" |
| NVMe tier | **2 × drive Mixed Use 3 DWPD, classe D/F/G**, capacità ≥ DRAM per host (es. 1,6 TB per host con 1 TB DRAM) | Mirror software in 9.1: due drive, stessa dimensione o maggiore; PDF: NVMe ≥ DRAM raccomandato |
| Slot | ≥ 2 per il tier; in più quelli per vSAN o dati locali se previsti | X210c M7: fino a 6 NVMe: verificare quanti slot restano |
| HA | +1 nodo (N+1) | Default del motore |
| CPU cap | 80% | Vincolo del motore |
| Active memory | ≤ 50% DRAM per host | Vincolo del PDF |

### 5.3 Base dati dei sistemi certificati: schema proposto

Campi per ogni riga (una riga per combinazione server + drive + versione ESXi):

| Campo | Esempio / note |
|---|---|
| Vendor, piattaforma, modello, PID | Cisco, UCS X-Series, X210c M8, PID da scheda |
| CPU (modello, socket, core max) | da scheda |
| DRAM max (GB) e slot DIMM | da scheda |
| NVMe: slot totali, form factor, PCIe gen, controller (passthrough/RAID) | da scheda |
| Drive NVMe supportati (PN, capacità, DWPD, classe D/F/G) | da BCG |
| Versione ESXi minima (9.1 + build) | da BCG |
| Riferimento BCG (ID, link, data verifica) | obbligatorio |
| **Stato verifica** | `verificato` / `non verificato` / `non supportato` |
| Note (coesistenza vSAN, firmware UCS Manager, limiti) | |

Regola: il motore **non propone** una riga come greenfield se lo stato non è `verificato`.

---

## 6. Ordine di lavoro proposto

1. **Lab (bloccante):** host ESXi 9.1 con NVMe Mixed Use dedicato, vCenter 9.1 → sblocca #15, #22, #29, #36 (validazione VM).
2. **Correzioni rapide:** versione 9.1 in #34, #36, #22 e nel codice (`Not supported`); merge di #1; #31; #2; #13 (scadenza nov. 2026).
3. **Fondamenta:** #4 (test sizing), poi #8 (CI), poi #3 (build exe verificabile).
4. **Compatibilità:** #36 per regole, a partire da quelle già rilevabili via API (versione, VM > 512 GB, `sched.mem.enableTiering`, reservation).
5. **Ambito e import:** #24 (decisione sulla chiave del gruppo), poi #26 (RVTools XLSX prima, poi template, Live Optics solo con file di esempio).
6. **Sicurezza di piattaforma:** #11, #12, #6, prima di #16.
7. **Piattaforma:** #16 → #17 → #18 → #20; #19 solo con GPU disponibile.
8. **#28** (Setup/Ripristino vCenter) ultimo: scrive sul vCenter del cliente, richiede disegno e test separati.

---

## 7. Domande aperte per Daniele

1. **Hardware brownfield:** compilare la scheda §4.3 (server, NVMe, slot, versioni).
2. **Lab:** esiste un host ESXi 9.1 con NVMe disponibile, o va pianificato l'upgrade? Senza, #15 e #36 restano ferme.
3. **Versione minima:** confermare 9.1 come soglia unica per MTAT (correggere #34, #36, #22 e il codice)?
4. **Cisco:** la "certificazione" di cui parli è la BCG per il Memory Tiering o un'altra lista? La verifica si fa sulla BCG: va bene se costruisco la base dati da lì?
5. **Issue GitHub:** vuoi che apra le issue per i punti nuovi emersi (versione 9.1, base dati Cisco, scadenza #13)? Le apro solo con tuo OK.
