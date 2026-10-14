# Specifica dei requisiti – Memory Tiering over NVMe (VMware vSphere 9.1)

**Fonte:** *VMware vSphere 9.1 – Memory Tiering over NVMe* (documentazione VMware by Broadcom, pagine 1836–1865 del PDF `VMware vSphere 9.1 - MT.pdf`).
**Scopo:** elencare in forma strutturata e verificabile tutti i requisiti, i vincoli e le procedure necessari per abilitare e usare Memory Tiering in un ambiente vSphere.

> Nota: dove il testo sorgente è ambiguo o incoerente, il punto è segnalato con **[DA VERIFICARE]** ed elencato nella sezione 12.

---

## 1. Glossario

| Termine | Significato |
|---|---|
| **Memory Tiering over NVMe** | Funzione che estende la memoria di un host ESX usando dispositivi NVMe locali come secondo livello di memoria. |
| **Tier 0** | DRAM dell'host. |
| **Tier 1** | Partizione NVMe dedicata, usata **solo per pagine di memoria delle VM**. |
| **Cold page** | Pagina poco acceduta, candidata a essere spostata su Tier 1. |
| **Active memory** | Memoria effettivamente usata dai workload in un dato momento (working set). È sempre ≤ consumed memory. |
| **DRAM:NVMe ratio** | Rapporto tra DRAM e capacità NVMe usata come tier (espresso anche come `tier_size_pct`). |
| **tier_size_pct** | Dimensione del tier NVMe in percentuale della DRAM (1–400, default 100). |
| **Configuration Manager** | Strumento di vSphere Configuration Profiles dal quale si configura il tiering a livello cluster. |

---

## 2. Requisiti di componenti software

| ID | Requisito | Obbligatorietà |
|---|---|---|
| SW-01 | vCenter Server **9.1 o successivo**. | Obbligatorio |
| SW-02 | ESX host **9.1 o successivo**. | Obbligatorio |
| SW-03 | Per la configurazione a livello cluster: il cluster deve essere gestito da **una singola immagine** tramite **vSphere Configuration Profiles** (Configuration Manager). | Obbligatorio per config. cluster |
| SW-04 | Per la configurazione a livello host con ESXCLI/PowerCLI: l'host deve essere in **maintenance mode** prima di attivare, disattivare o riconfigurare il tiering. | Obbligatorio |

---

## 3. Requisiti dei dispositivi NVMe

### 3.1 Tipo e caratteristiche

| ID | Requisito | Obbligatorietà |
|---|---|---|
| NV-01 | Il dispositivo deve essere un drive **simile alla cache vSAN**, classe **Mixed Use**. | Obbligatorio |
| NV-02 | Endurance: **≥ 3 DWPD** (Drive Writes Per Day). | Obbligatorio |
| NV-03 | Il dispositivo deve essere **NVMe** (non over fabric né Ethernet). | Obbligatorio |
| NV-04 | Il dispositivo deve essere **installato localmente** nell'host. | Obbligatorio |
| NV-05 | Il dispositivo deve essere **dedicato** al Memory Tiering: non può essere condiviso con boot, vSAN o altri servizi. | Obbligatorio |
| NV-06 | Il dispositivo **non deve** far parte di un vSAN cache o data disk già configurato. Un vSAN data disk può essere riutilizzato solo **rimuovendolo dal disk group vSAN**. | Obbligatorio |
| NV-07 | Tutte le **partizioni esistenti** sul dispositivo devono essere eliminate (riferimento: Broadcom KB 323144). | Obbligatorio |
| NV-08 | Dimensione: NVMe di dimensione **≥ DRAM** dell'host è raccomandata in generale. Se la capacità NVMe è inferiore alla DRAM, il sistema usa la capacità minore. | Raccomandato |

### 3.2 Criteri di selezione (Broadcom Compatibility Guide)

Ricerca nel BCG: *Programs* = **vSAN SSD** → card *Storage & Availability* → **vSAN SSD**, con filtri:

| Criterio | Valore richiesto (interpretazione – vedi [DA VERIFICARE] §12) |
|---|---|
| Device Type | NVMe |
| Endurance Class | **D** (≥ 7300 TBW) |
| Performance Class | **F** (100.000–349.999 write/s) **oppure G** (≥ 350.000 write/s) |
| Endurance – DWPD | **≥ 3** |
| Supported Release | ESX 9.1 |

Esempi di riferimento OEM citati nel documento (non esaustivi):
- **Dell:** drive "Enterprise NVMe Mixed Use" (es. 1.6 TB Enterprise NVMe Mixed Use AG Drive U.2 per R750), 3 DWPD.
- **HPE:** SSD Selector → *Workload = Mixed Use*, *Interface = NVMe* (Mainstream o High Performance), *Endurance DWPD ≥ 3*.
- **Lenovo:** drive *Mixed Use* NVMe con endurance 3 DWPD, classe Enterprise o Advanced Data-Center (es. ThinkSystem CD8P, PM1745, P5620, 7450, PS1030, Solidigm P5620, Intel P5600 *Mainstream*).

### 3.3 Partizione automatica

| ID | Requisito |
|---|---|
| NV-09 | Il sistema genera automaticamente una partizione dedicata. Se non è specificata una dimensione, usa l'intera capacità disponibile. |
| NV-10 | Limite predefinito: capacità tiering = **DRAM × 1:1**, con **massimo 4 TB**. |
| NV-11 | La partizione NVMe usata = **il minore tra** il rapporto DRAM:NVMe e la dimensione della partizione. |

---

## 4. Requisiti dell'host ESX

| ID | Requisito | Obbligatorietà |
|---|---|---|
| HW-01 | L'host deve avere un **dispositivo NVMe compatibile** (vedi §3). | Obbligatorio |
| HW-02 | L'host **non deve** avere **Intel Optane Persistent Memory** configurata: va rimossa. | Obbligatorio |
| HW-03 | L'host **non deve** avere **NVDIMM-N Persistent Memory** installata: va disattivata/rimossa secondo la documentazione OEM. | Obbligatorio |
| HW-04 | L'host deve essere in **maintenance mode** per attivare, disattivare o riconfigurare il tiering. | Obbligatorio |
| HW-05 | Dopo aver soddisfatto i requisiti, uscire dalla maintenance mode. | Procedurale |
| HW-06 | Hot-plug e "prepare to remove" **non sono supportati** per l'NVMe usato dal tiering. Per rimuovere/sostituire il drive occorre **disattivare il tiering** sull'host. | Vincolo |

---

## 5. Vincoli di funzionalità (cosa non funziona con il tiering attivo)

| ID | Vincolo | Note |
|---|---|---|
| FN-01 | **Suspend VM to memory non supportato** sugli host con tiering attivo. | Sono supportati: suspend to disk e snapshot. |
| FN-02 | **Quick Boot non supportato** sugli host con tiering attivo. | |
| FN-03 | **Memory overcommit non va usato** quando il tiering è attivo. | Ballooning, TPS e swap possono degradare le prestazioni. |
| FN-04 | Il **kernel memory non viene mai tierizzata**: solo le pagine delle VM. | |

---

## 6. Pianificazione della capacità

### 6.1 Requisiti di dimensionamento

| ID | Requisito | Obbligatorietà |
|---|---|---|
| CP-01 | Determinare la DRAM necessaria per le VM che richiedono tutta la memoria in DRAM (vedi §7.1). | Obbligatorio |
| CP-02 | Determinare DRAM e NVMe necessari in base alle **Memory Resource Reservations** delle VM. | Obbligatorio |
| CP-03 | L'**active memory media** della VM deve **stare nella DRAM** allocata alla VM in ogni momento. | Obbligatorio (hard) |
| CP-04 | L'active memory dell'host **non deve superare il 50% della DRAM** in nessun momento. | Raccomandato per performance ottimali |
| CP-05 | Per evitare problemi di latenza: active memory totale delle VM ≤ DRAM disponibile alle VM. | Obbligatorio per performance |

> **Target d'uso:** il tiering è appropriato dove il **consumo di memoria è alto (> 50% allocato tra tutte le VM)** ma l'**active memory è bassa (< 50% della DRAM totale)**.
> La maggior parte dei workload ha active memory tra il **10% e il 30%**.

### 6.2 Tabella DRAM:NVMe

| DRAM | Rapporto DRAM:NVMe | % DRAM | Partizione NVMe | NVMe usata |
|---|---|---|---|---|
| 256 GB | 1:1 (default) | 100% | 512 GB | 256 GB |
| 256 GB | 1:1 | 100% | 256 GB | 256 GB |
| 256 GB | 2:1 | 50% | 512 GB | 128 GB |
| 256 GB | 2:1 | 50% | 128 GB | 128 GB |
| 1 TB | 4:1 | 25% | 4 TB | 256 GB |
| 2 TB | 4:1 | 25% | 2 TB | 512 GB |

### 6.3 Esempio di dimensionamento
Host con DRAM 1 TB, active memory 200 GB (20%), consumed 800 GB (80%). Raddoppiando VM e memoria (active 400 GB = 20% di 2 TB) con DRAM 1 TB e NVMe tier 1 TB, l'active memory resta sotto il 50% della DRAM → performance attese ottimali.

### 6.4 Soglie di monitoraggio

| ID | Soglia | Azione |
|---|---|---|
| MN-01 | Lettura NVMe **> 200 MB/s** | Iniziare il monitoraggio delle latenze del dispositivo. |
| MN-02 | Latenza di lettura **< 200 µs** con ~400 MB/s | Riferimento di prestazioni buone con i dispositivi testati. Con altri NVMe si sono osservati valori attorno a **300 µs** a banda simile. |
| MN-03 | Monitorare la latenza in quanto ha **impatto diretto sulle prestazioni** del workload. | |
| MN-04 | Per investigare una VM lenta: monitorare la **read bandwidth per-VM**. | |

Metriche disponibili in vCenter (Advanced Memory Performance chart, per-VM):
- **Memory Write Bandwidth** = pagine fredde spostate sul tier NVMe.
- **Memory Read Bandwidth** = pagine riportate da NVMe quando diventano attive e non sono in DRAM.

---

## 7. Profili VM

### 7.1 VM che possono usare solo Tier 0 (DRAM)

Queste VM sono forzate a usare **solo DRAM**; il sistema lo garantisce automaticamente.

| Tipo | Stato nel documento |
|---|---|
| Low Latency VM | Eseguibile su host con tiering, ma **esclusa** dal processo di tiering |
| Confidential VM | Eseguibile, **esclusa** dal tiering |
| Fault Tolerant VM | Eseguibile, **esclusa** dal tiering |
| Large VM | Eseguibile, **esclusa** dal tiering |
| Nested Virtualization VM | Eseguibile, **esclusa** dal tiering (eccezione VBS, vedi sotto) |

**Caso VBS (Virtualization-Based Security) in Nested VM:** il tiering è disattivato per default; può essere attivato impostando il parametro vmx `sched.mem.enableNestedTiering = TRUE`. Il host base può anche usare il tiering. Richiede test del workload e le linee guida del white paper performance.

**Nota VM grandi:** VM con **> 512 GB di RAM e 64 vCPU** su host con tiering possono avere degrado prestazionale. Per evitarlo: disattivare il tiering su queste VM e configurarle con **reservation completa**.

### 7.2 VM su tiering "normale"
Usano sia DRAM sia NVMe; il sistema sposta le pagine in base a recency e frequency.

---

## 8. Configurazione

### 8.1 Metodi disponibili
- **vCenter Configuration Manager** (vSphere Client)
- **ESXCLI**
- **PowerCLI**

Operazioni supportate con questi strumenti: identificare i dispositivi NVMe, configurare il tiering per cluster e per host, verificarne la correttezza.

### 8.2 Attivazione a livello cluster (Configuration Manager)

Prerequisito: il cluster deve soddisfare tutti i requisiti della §2–§4.

1. vSphere Client → selezionare il **cluster**.
2. Tab **Configure** → **Desired State > Configuration**.
3. Tab **Draft** → **esx > memtier**.
4. Cliccare il link **nvme** → **Configure Settings** → **Configure Settings**.
5. Nel pannello *Edit* impostare:
   - **enable** = `True` (obbligatorio);
   - **device** = almeno un dispositivo NVMe (obbligatorio). Può essere specifico per host (*View host-specific details*): aggiungere host tramite **BIOS UUID**, selezionare il device da *Show unconfigured hosts*. Alternativa: copiare il *Location path* da *Storage > Storage Devices* dell'host;
   - **mirror_device** (opzionale, consigliato): deve essere **diverso** dal device primario;
   - **encryption** = `True` / `False` (default `False`);
   - **tier_size_pct** = valore tra **1 e 400** (default **100** = 1:1).
6. **Save**.

Comportamenti:
- Il Configuration Manager **mette automaticamente l'host in maintenance mode** e applica i parametri.
- Il tiering è applicato a **tutti gli host del cluster**, salvo override host-specifici.
- I dispositivi NVMe e i mirror sono **specifici per host**.

**Modifica:** Configure → Desired State → Draft → esx > memtier → **nvme** → **Edit** → modificare → **Save**.
**Eliminazione (disattivazione a livello cluster):** Configure → Desired State → Draft → esx > memtier → **nvme** → selezionare la config → **Delete**.

### 8.3 Attivazione a livello host (ESXCLI)

Prerequisiti: cluster gestito con vSphere Configuration Profiles (per coerenza); host in **maintenance mode**.

| Passo | Comando | Scopo |
|---|---|---|
| 1 | `esxcli memtier device list` | Identificare i dispositivi disponibili |
| 2 | `esxcli memtier enable -d <device_1>` | Attivare il tiering |
| 3a | `esxcli memtier enable -d <device_1,device_2>` | Attivare con mirroring |
| 3b | `esxcli memtier enable -d <device_1> -c t -r 50` | Attivare con cifratura e rapporto 50% **[DA VERIFICARE: significato dei flag `-c` e `-r`]** |

### 8.4 Verifica della configurazione

| Verifica | Come |
|---|---|
| Cluster configurato | vSphere Client → cluster → **Summary** → card **Memory** |
| Host configurato (GUI) | vSphere Client → host → **Summary** → card **Memory** |
| Host configurato (CLI) | `esxcli memtier status get` e `esxcli memtier config get` |
| Hosts di un cluster | Cluster → **Hosts** → colonna **Memory Tiering** (valore "Software" = configurato). Numero di host anche in Cluster → Summary → Memory |

Interpretazione CLI:
- Campo **Enable = False** → host **non** configurato.
- **Enable = True** ma `status get` restituisce **Status: Disabled** → errore. Consultare log di sistema o allarmi.

### 8.5 Modifica della configurazione (ESXCLI)

Sostituzione del device NVMe (con host in maintenance mode):
```
esxcli memtier config set -d "new_device"
```

Modifica del rapporto DRAM:NVMe (host in maintenance mode):
```
esxcli memtier config set --tier-size-pct 25
```
`tier-size-pct = 25` → 25% della DRAM come tier NVMe → rapporto **4:1**.
In alternativa: Configuration Manager.

Sostituzione device/mirror con software mirroring:
```
esxcli memtier config set --devices=<new-device>,<old-mirror-device-if-any>   # sostituisce il primario
esxcli memtier config set --devices=<old-device>,<new-mirror-device>         # sostituisce il mirror
```

Disattivazione solo del mirror (host in maintenance mode):
```
esxcli memtier config set -d "old-device-1"
```

**[DA VERIFICARE]:** il documento usa `-d` in alcuni comandi e `--devices=` in altri per la stessa operazione.

### 8.6 Cifratura NVMe

Stato di default: **non cifrata**.

| Livello | Come attivare | Requisito |
|---|---|---|
| **Host** (tutte le VM, protezione da furto fisico/accesso hardware) | `esxcli memtier config set --encryption true` | Host in maintenance mode |
| **VM** (protezione granulare, contro minacce interne/intra-VM) | Power off VM → Edit Settings → tab **Advanced Parameters** → `sched.mem.EncryptTierNVMe = TRUE` → Power on | VM spenta |

La cifratura NVMe è **diversa** dalla VM encryption (vedi "Configure Virtual Machine Encryption Options").

### 8.7 Ridondanza

Due approcci supportati. Nel documento è indicato che la **Software Mirroring** è quella da usare con vSphere 9.1 al posto del RAID hardware.

#### 8.7.1 Software Mirroring (software RAID) – **raccomandato in 9.1**

| ID | Requisito |
|---|---|
| SM-01 | Ridondanza con **2 dispositivi NVMe** sull'host: un guasto di un solo device non fa fallire tutte le VM con pagine sul device guasto. |
| SM-02 | I dati sono **replicati** sul mirror, stesso partition e stesso block number. |
| SM-03 | La dimensione del mirror **deve essere ≥** del primo tier disk. |
| SM-04 | Attivazione durante l'attivazione del tiering: `esxcli memtier enable -d "device-1,device-2"`. |
| SM-05 | Attivazione dopo: `esxcli memtier config set -d "old-device,new-mirror-device"` (host in maintenance mode). |
| SM-06 | Disattivazione del solo mirror: host in maintenance mode, poi `esxcli memtier config set -d "old-device-1"`. |
| SM-07 | Attivazione del mirror può essere fatta anche a livello cluster tramite Configuration Manager (campo `mirror_device`). |

#### 8.7.2 RAID hardware

| ID | Requisito |
|---|---|
| RH-01 | Il controller RAID deve essere supportato (es. Intel Virtual RAID on CPU, Tri-Mode Technology, 24G NVMe Tri-mode RAID/HBA). |
| RH-02 | Creare un **singolo logical device** con più dispositivi fisici tramite il controller. |
| RH-03 | Configurare il logical device come tier per ciascun host (PowerCLI / ESXCLI). |
| RH-04 | Gestire il cluster con una singola immagine e Configuration Profiles. |
| RH-05 | Attivare il tiering a livello cluster. |
| RH-06 | Creare VM sufficienti a generare active memory che attivi l'uso del tier. |

### 8.8 Attivazione con vSAN

Tre approcci. In tutti, il dispositivo scelto per il tiering **non deve essere claimed da vSAN**.

**Approccio 1 – vSAN prima, poi tiering:**
1. Attivare vSAN sul cluster (Configure > vSAN > Services > Configure, Enablement Wizard).
2. Completare l'installazione e verificare le disk assignment (Disk Groups / Storage Devices).
3. **Disattivare Auto Disk Claim** (vSAN Managed Disk Claim) nel passo *vSAN Configuration* (in ESA se richiesto).
4. Inserire un nuovo NVMe in uno slot libero e attivare il tiering selezionando il nuovo disco.

**Approccio 2 – riservare il disco prima di claimare:**
1. Attivare vSAN; disattivare Auto Disk Claim.
2. Navigare il wizard **senza claimare dischi**; completare l'attivazione (cluster con dischi non claimati).
3. Identificare e **riservare** il disco NVMe (non includerlo nei claim).
4. Claimare manualmente i dischi dati: Cluster > Configure > vSAN > Disk Management > **Claim Unused Disks for vSAN**, selezionando **solo** i dati, non il riservato.
5. Verificare le disk group; il disco riservato resta non claimato.
6. Attivare il tiering selezionando il disco riservato.

**Approccio 3 – rimuovere un device da vSAN:**
1. Verificare che il cluster abbia spazio sufficiente per migrare i dati dal device.
2. Cluster > Configure > vSAN > **Disk Management**; selezionare il pool; **Remove Disk**.
3. Selezionare **Full data migration**; **Go To Pre-Check** per verificare l'impatto; **Remove**.
4. Attivare il tiering sul device rimosso.

Riferimento per ambienti vSAN esistenti: rimozione con le procedure "vSAN OSA / ESA / Device Removal UI".

---

## 9. Procedure operative

### 9.1 Disattivazione del tiering su un host

Requisito: **host in maintenance mode** (vMotion evacua le VM sull'host verso altri host eligibili del cluster).

| Opzione | Comando |
|---|---|
| Disattivare e **mantenere** la partizione tier | `esxcli memtier disable` **[DA VERIFICARE]** |
| Disattivare e **eliminare** la partizione tier | `esxcli memtier disable -d` **[DA VERIFICARE]** |

**Impatto:** la disattivazione riduce la memoria totale disponibile al cluster. Se un cluster sovra-impegnato non ha memoria sufficiente, le VM possono **non riaccendersi**.

### 9.2 Eliminazione completa della configurazione a livello host

1. Host in maintenance mode.
2. Eseguire: `esxcli memtier config delete` (rimuove la configurazione e la partizione tier).

### 9.3 Disattivazione del tiering per una singola VM

Usare quando la VM ha requisiti di latenza/prestazioni che richiedono solo DRAM. Il sistema disattiva automaticamente il tiering per le VM dei profili della §7.1.

**Prerequisito:** **riservare tutta la memoria della VM** (Reserve all guest memory / "All locked") per evitare problemi di reclaim e lo swap su host swap file.

Procedura:
1. Power off della VM.
2. Edit Settings → **VM Options → Advanced Parameters** (Configuration Parameters).
3. Attribute: `sched.mem.enableTiering` · Value: `FALSE`.
4. Tab **Virtual Hardware** → **Memory** → spuntare **Reserve all guest memory (All locked)**.
5. Power on.

### 9.4 Sostituzione di un NVMe guasto

1. Se l'interfaccia segnala il guasto, sostituire il drive secondo la sezione "Modify Configuration After Activating Memory Tiering".
2. Host in maintenance mode.
3. Sostituire con `esxcli memtier config set -d "new_device"` (oppure `--devices=` in presenza di mirror, vedi §8.5).
4. Hot-plug non supportato: serve disattivare il tiering se si rimuove il drive senza procedura di sostituzione.

### 9.5 Cambio del rapporto DRAM:NVMe

1. Host in maintenance mode.
2. `esxcli memtier config set --tier-size-pct <valore>` oppure Configuration Manager.
3. Esempi: `25` → 4:1; `50` → 2:1; `100` → 1:1 (default).

---

## 10. Interazioni con altre funzionalità

### 10.1 DRS e vMotion

| ID | Requisito / Comportamento |
|---|---|
| DR-01 | DRS integra il tiering: monitora gli host del cluster e bilancia l'uso della memoria. |
| DR-02 | Durante il placement, DRS valuta anche l'**active memory** dell'host target. |
| DR-03 | vMotion: impatto prestazionale quasi nullo sulla VM in esecuzione, ma **la migrazione richiede 1,5× – 2×** più tempo (le pagine vanno recuperate dal tier NVMe). |
| DR-04 | vMotion non aumenta il fabbisogno DRAM dell'host di destinazione: le pagine sono **streamed** durante la migrazione. |
| DR-05 | In ambiente misto (host tiered e non tiered) DRS può spostare VM su host meno carichi. |
| DR-06 | Evoluzione prevista (release futura): trasferimento delle informazioni di *heat* (frequenza accessi) tra host durante vMotion. |

### 10.2 Maintenance mode e disattivazione
- Entrare in maintenance mode → vMotion evacua **tutte** le VM (tiered e non tiered).
- All'uscita dalla maintenance mode, DRS può riportare le VM sull'host se migliora l'utilizzo.

### 10.3 Memory reservations
- Le reservations (non "pinned memory") **possono** convivere con il tiering.
- Se tutte le VM hanno la memoria riservata e il consumo combinato supera la DRAM, le reservations possono essere divise tra DRAM e tier NVMe.

### 10.4 Swap
- Il tiering **non è swap**. Differenze chiave:

| Aspetto | Memory Tiering | Swap |
|---|---|---|
| Selezione pagine | Aging avanzato per recency e frequency | Selezione casuale |
| Device | NVMe locale dedicato | Spesso condiviso (NAS/SAN) con altri sottosistemi |
| Prestazioni | Consistenti | Variabili |
| Correttezza in condizioni estreme (3–4× overcommit, vMotion) | Dipende dal dimensionamento | Garantita |

- Lo swap guest (*swap file*) e il meccanismo di reclaim sono descritti nella sezione "Using Swap Files with vSphere" e restano separati dal tiering.

### 10.5 Memory overcommit
- **Non usare** overcommit con il tiering attivo (vedi FN-03).

### 10.6 Server OEM e hardware
Dai documenti OEM citati:
- **Dell** (es. R750): usare drive Mixed-Use Enterprise dalla configurazione Dell (es. 1.6 TB Enterprise NVMe Mixed Use AG Drive U.2). Possibile dover scegliere una coppia diversa da quella usata per vSAN ReadyNode.
- **HPE**: SSD Selector Tool → Mixed Use + NVMe, verificare *Endurance DWPD ≥ 3*.
- **Lenovo**: drive Mixed Use 3 DWPD, backplane NVMe, classe Enterprise o Advanced Data-Center.

---

## 11. Guasti e failure scenarios

| Scenario | Comportamento | Azione |
|---|---|---|
| Guasto di **un** NVMe **senza** mirror | Le VM con pagine sul device **continuano** finché le pagine non vengono accedute. Un **page fault** non risolvibile **spegne la VM**. | Ripristinare il device; valutare mirror |
| Guasto di **un** NVMe **con** software mirror | Le VM non vengono interrotte (il mirror mantiene i dati) | Sostituire il device |
| VM **solo DRAM** | Non influenzate | Nessuna |
| VM spenta per guasto NVMe in cluster **HA** | Con *VM restart policy* configurata, vSphere HA riavvia la VM su un altro host | Configurare HA restart policy |
| Requisito HA | Cluster con vSphere HA attivo e risorse sufficienti sugli altri host. **Non è richiesto un host di failover dedicato.** | |

**Triggering della maintenance mode dopo un guasto NVMe:**
- In vSphere 9.1 è una **operazione manuale**: da vSphere Client o ESXCLI.
- Oppure automatica tramite plug-in di gestione hardware (Dell OpenManage, HPE OneView), se configurato per rilevare guasti e mettere in maintenance mode.

---

## 12. Punti da verificare nel documento sorgente

| # | Punto | Dettaglio |
|---|---|---|
| 1 | **Criteri BCG** | Il filtro "Endurance Class / Performance Class / DWPD" è stampato con valori disallineati nel PDF. L'interpretazione in §3.2 è la più coerente con gli esempi OEM. |
| 2 | **Flag `-c` e `-r`** | `esxcli memtier enable -d <device_1> -c t -r 50` usa flag non documentati altrove (il documento usa `--encryption` e `--tier-size-pct`). |
| 3 | **Sintassi mirror/replace** | `-d` e `--devices=` compaiono per la stessa operazione. |
| 4 | **Disattivazione tiering** | La tabella "Deactivate Memory Tiering and retain / delete the tier partition" ha la colonna comandi disallineata. Dedotto: *retain* = `esxcli memtier disable`; *delete* = `esxcli memtier disable -d`. Verificare. |
| 5 | **Eliminazione configurazione** | §9.2 usa `esxcli memtier config delete` per rimuovere la partizione, distinto dalla disattivazione. Verificare la differenza. |
| 6 | **Active memory ≤ 50%** | Due formulazioni: "must fit" (§6.1, CP-03) e "should not exceed 50%" (§6.2). Il primo è il requisito minimo, il secondo quello raccomandato. |
| 7 | **Soglia 80% DRAM** | Il tiering delle cold page inizia a circa l'80% della DRAM (§11 Mechanism). Il documento non specifica se è un valore fisso o configurabile. |
| 8 | **Nested VM / VBS** | Il parametro `sched.mem.enableNestedTiering` è citato per VBS; il comportamento per altri nested non è dettagliato. |
| 9 | **Testo corrotto** | Nel PDF sono presenti refusi ("emory iering", "NVMDIMM-N", "Virutal", "returnsStatus"): il significato è stato dedotto dal contesto. |

---

## 13. Checklist di conformità (pre-attivazione)

**Software**
- [ ] vCenter 9.1+ e ESX 9.1+
- [ ] Cluster gestito con vSphere Configuration Profiles (se config a livello cluster)

**Hardware**
- [ ] NVMe locale, non over fabric
- [ ] Mixed Use, endurance ≥ 3 DWPD, classe D (endurance) e F/G (performance) BCG
- [ ] Dispositivo dedicato (non vSAN, non boot)
- [ ] Partizioni precedenti eliminate (KB 323144)
- [ ] Nessun Intel Optane PMem e nessun NVDIMM-N sull'host
- [ ] Dimensione NVMe ≥ DRAM (raccomandato)
- [ ] Mirror: secondo NVMe della stessa dimensione o superiore (se si usa Software Mirroring)

**Workload**
- [ ] Consumo memoria > 50% allocato, active memory < 50% DRAM
- [ ] Verifica con vCenter: Memory Read/Write Bandwidth, latenze
- [ ] VM > 512 GB RAM e 64 vCPU: escluse dal tiering e reservation completa
- [ ] VM con Low Latency / Confidential / FT / Large / Nested (non VBS): valutare esclusione
- [ ] Nessun uso di memory overcommit

**Operatività**
- [ ] Host in maintenance mode prima di ogni modifica
- [ ] No Quick Boot, no suspend-to-memory
- [ ] HA configurata con VM restart policy (consigliato)
- [ ] Monitoraggio latenze se NVMe read > 200 MB/s

---

## 14. Riferimenti nel documento sorgente

- Broadcom Compatibility Guide → vSAN SSD (filtri §3.2)
- Broadcom KB 323144 (eliminazione partizioni)
- Using vSphere Configuration Profiles to Manage Host Configuration at a Cluster Level
- VMware PowerCLI and ESXCLI Concepts and Examples
- Memory Tiering Performance in VMware Cloud Foundation 9.0 (vMotion, performance)
- NVMe Memory Tiering Design and Sizing on VMware Cloud Foundation 9 Part 4: vSAN Compatibility and Storage Considerations
- Enabling NVMe Memory Tiering on Dell PowerEdge servers using VMware vSphere 9.0
- Implementing Memory Tiering over NVMe using VMware ESX 9.0 (Lenovo)
- vSAN OSA / ESA / Device Removal UI
- Configure Virtual Machine Encryption Options
- Using Swap Files with vSphere
