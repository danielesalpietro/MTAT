# Memory Tiering Assessment Tool (MTAT)

*[English](README.md) · Italiano*

**MTAT** è uno strumento di pianificazione e dimensionamento per il **Memory Tiering over NVMe** di
vSphere. Legge host e VM di un cluster da vCenter oppure da un import offline. Li confronta con i
requisiti del Memory Tiering e stima cosa renderebbe il tiering e quanto costerebbe, sia su un
cluster esistente (**Brownfield**) sia su uno nuovo (**Greenfield**).

> **Questo è un fork di lavoro di MTAT v3.1.** Il fork aggiunge:
> - un deploy Docker headless;
> - un gemello digitale di vCenter/ESXi per test e demo;
> - i controlli delle regole del Memory Tiering descritti sotto.
>
> Il progetto evolve verso una piattaforma di assessment, storico e simulazione
> ([`docs/ROADMAP.md`](docs/ROADMAP.md)). Senza variabili d'ambiente `MTAT_*`, il comportamento
> desktop di `MTAT_v3_1.ps1` è uguale alla v3.1 originale. La release v3.0 è conservata in
> **Releases → v3.0.0**; `CHANGELOG.md` elenca le modifiche fino alla v3.1.

## 🗂️ Contenuto del repository

| Percorso | Contenuto |
|---|---|
| `MTAT_v3_1.ps1` | motore e UI in un solo file (PowerShell con HTML/JS incorporati), multipiattaforma |
| `MTAT_v3_1.exe` | eseguibile Windows della v3.1 originale (non rigenerato da questo fork) |
| `docker/`, `docker-compose.yml` | deploy in container headless ([`docker/README.md`](docker/README.md)) |
| `twin/`, `docker-compose.twin.yml` | **gemello digitale** di vCenter/ESXi ([`twin/README.md`](twin/README.md)) |
| `tests/` | unit test del sizing e test end-to-end sul gemello |
| `docs/` | requisiti del Memory Tiering, come MTAT li applica, fattibilità, roadmap |

## 🧭 Cosa fa la UI

1. **vCenter Connection**: uno o più vCenter, con un account in sola lettura. Senza accesso live si
   può usare l'import offline (Matrix/History).
2. **Baseline Assessment**:
   - CPU, memoria attiva e consumata per intervallo: Real-Time, 24 ore, 7 e 30 giorni;
   - tabelle per host e per VM, con export CSV;
   - per ogni host, lo stato del tiering e il **livello di supporto della versione ESXi**: sotto la
     8.0 U3 Not supported, 8.0 U3 Tech preview, dalla 9.0 Supported;
   - una checklist che segnala gli host e le VM oltre le **soglie di memoria attiva**: picco
     dell'host sopra il 50% della DRAM, media della VM sopra la sua quota di DRAM, domanda delle
     VM sopra la DRAM dell'host.
3. **Sizing & Savings**:
   - Brownfield: aggiunge NVMe agli host attuali;
   - Greenfield: dimensiona host nuovi, con o senza tiering.

   Entrambi tengono conto di:
   - limite di 4 TB di NVMe per host;
   - ratio tra 1% e 400%;
   - VM che devono restare in DRAM;
   - memoria di sistema ESXi per host, opzionale;
   - avvisi per NVMe più piccolo della DRAM o senza ridondanza.
4. **Brownfield Readiness Checklist**: una riga per ogni prerequisito, con esito Passed, Failed,
   Warning o Skipped. Alcune regole sono automatiche e partono dall'analisi; le altre si
   confermano a mano: HA/DRS, vSAN, hardware NVMe, esclusioni delle VM.

Le regole, le fonti e gli ID sono in
[`docs/vsphere-memory-tiering-requisiti.md`](docs/vsphere-memory-tiering-requisiti.md) e
[`docs/mtat-regole-memory-tiering.md`](docs/mtat-regole-memory-tiering.md).

## 🐳 Docker (beta)

Il motore gira headless in un container Linux, con PowerShell 7 e una versione fissata di PowerCLI:

```bash
docker compose up -d --build
# poi aprire http://localhost:8600
```

La UI è pubblicata solo sull'interfaccia di loopback dell'host. L'API rifiuta header `Host` o
`Origin` estranei, a protezione da DNS rebinding e CSRF. Configurazione (`MTAT_HEADLESS`,
`MTAT_PORT`, `MTAT_BIND_HOST`, `MTAT_ALLOWED_HOSTS`, `MTAT_DATA_DIR`) e note di sicurezza sono in
[`docker/README.md`](docker/README.md).

## 🧪 Gemello digitale (senza vCenter: test e demo)

Il gemello digitale sostituisce PowerCLI con un modulo finto `VMware.VimAutomation.Core`. Il modulo
risponde a partire da uno **scenario JSON**, che descrive:
- vCenter, cluster e host ESXi di versioni diverse;
- tiering attivo, disattivo o in errore;
- VM con memoria bloccata, esclusioni dal tiering, più di 60 vCPU;
- statistiche storiche.

Il gemello fa girare tutto MTAT, dalla connessione al sizing e all'export, senza laboratorio e
senza credenziali. Per questo è comodo anche per le **demo**.

```bash
MTAT_TWIN=mixed-90 docker compose -p mtat-twin -f docker-compose.yml -f docker-compose.twin.yml up -d --build
# aprire http://localhost:8601 e connettersi al vCenter "vc-twin-90" con utente e password qualsiasi
```

| Scenario (`MTAT_TWIN`) | vCenter da inserire | Cosa mostra |
|---|---|---|
| `mixed-90` | `vc-twin-90` | vCenter 9.0 con un cluster misto di cinque host: 8.0.2, 8.0.3 in tech preview, 9.0 con tiering attivo, disattivo e in errore. VM che restano in DRAM e VM con più di 60 vCPU; host e VM oltre le soglie di memoria attiva |
| `lab-802` | `vc-twin-lab` | piccolo laboratorio con un solo host 8.0.2 (Not supported) |
| `no-clusters` | `vc-twin-empty`, `vc-twin-denied` | un vCenter senza cluster e un login rifiutato |

Il gemello è un progetto compose separato sulla porta 8601, quindi può girare accanto a un
container MTAT reale. Nel log del motore compare `[TWIN] *** MTAT DIGITAL TWIN active`, così i
suoi dati non si confondono con quelli di un vCenter reale. Per aggiungere scenari:
[`twin/README.md`](twin/README.md).

## ✅ Requisiti (modalità live)

### Software e ambiente

*   **PowerShell:** Windows PowerShell su Windows, oppure PowerShell 7 su Windows, macOS e Linux.
*   **VMware PowerCLI:** serve il modulo `VMware.VimAutomation.Core`. Il motore lo cerca all'avvio e,
    se manca, si ferma con un errore critico. L'immagine Docker lo contiene già.
*   **Un browser recente:** il motore avvia un web server locale e apre un'interfaccia HTML5.
*   **Una porta TCP locale libera:** di default la `8600`. In modalità desktop, se è occupata, il
    motore passa alla successiva libera (`8601`, `8602`…).

### vSphere e connettività

*   **Accesso di rete al vCenter** in HTTPS (porta 443) dalla macchina che esegue MTAT.
*   **Credenziali:** basta un account in **sola lettura** per leggere l'inventario (cluster, host,
    VM) e le statistiche di performance. L'account va assegnato con il ruolo Read-only sulla
    radice del vCenter, con propagazione. Per leggere lo stato del tiering via `esxcli` può servire
    anche il privilegio `Host > Configurazione > Impostazioni avanzate`; senza, lo stato risulta
    `Unknown (query failed)`.

### Dati storici (opzionali)

*   Per gli intervalli storici (24 ore, 7 e 30 giorni) serve il **livello 2 delle statistiche di
    vCenter**. Con livelli più bassi lo strumento usa gli intervalli disponibili.
    "Active Memory (Peak)" è il massimo dei campioni `.average` standard nella finestra, quindi il
    livello 2 basta.

## 🚀 Installazione e avvio

### Windows (eseguibile)
1. Scaricare `MTAT_v3_1.exe` dal repository. È la v3.1 originale: le aggiunte di questo fork sono
   solo in `MTAT_v3_1.ps1`.
2. Avviarlo con un doppio clic.

### Qualsiasi sistema (PowerShell)
1. Clonare il repository o scaricare `MTAT_v3_1.ps1`.
2. Aprire PowerShell e verificare che l'esecuzione degli script sia consentita:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Avviare lo script:
   ```powershell
   .\MTAT_v3_1.ps1
   ```

### Docker
Vedi [Docker (beta)](#-docker-beta) sopra.

## 🔧 Sviluppo

```bash
node tests/sizing.test.js                                                  # unit test degli helper di sizing e delle regole
node tests/twin-e2e.js twin/scenarios/mixed-90.json http://127.0.0.1:8601  # test end-to-end su un gemello avviato
```

La CI (`.github/workflows/docker-image.yml`):
- costruisce l'immagine reale ed esegue uno smoke test;
- esegue gli unit test;
- esegue end-to-end tutti gli scenari del gemello.

Le regole del progetto sono in [`CLAUDE.md`](CLAUDE.md): issue, sessioni, logbook, convenzioni di
commit, fine riga CRLF dello script.
