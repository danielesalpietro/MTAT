# Scheda hardware Brownfield: template

Template **pubblico e senza dati** per raccogliere le informazioni sull'hardware di un candidato Brownfield
(host esistenti a cui aggiungere NVMe per il Memory Tiering) che vCenter non espone o che MTAT non legge.
Riferimenti: issue #46 (questa scheda), #40 (controlli Brownfield), #34 (prerequisito di versione),
`docs/vsphere-memory-tiering-requisiti.md` (spec), `docs/vsphere-memory-tiering-fattibilita.md` §4.

## ⚠️ Dove vanno i dati reali

Il fork è **pubblico**. Questo file resta vuoto: **non compilarlo nel repository**.

1. Copia il template in `local/brownfield-<alias>.local.md` nella root del clone (la cartella `local/` e i
   file `*.local.md` sono esclusi da git, vedi `.gitignore`).
2. Usa per il candidato un **alias anonimo** (es. `bf-cand-01`) e per gli host gli alias di `assets.local.md`
   (es. `esxi-lab-01`). Niente nomi di clienti, hostname, IP, numeri di serie o service tag.
3. In issue, logbook e commit si citano solo l'alias e valori aggregati (es. "3 host, 2 slot NVMe liberi ciascuno").

Legenda esiti: **OK** · **KO** (blocca il tiering) · **?** (da verificare) · **n/a**.
Colonna "Fonte del dato": `vCenter` (MTAT lo può leggere), `scheda` (solo da questa scheda), `BCG` (Broadcom Compatibility Guide).

---

## 1. Candidato

| Campo | Valore |
|---|---|
| Alias del candidato | |
| Cluster / ambito (alias) | |
| Numero di host | |
| Data di compilazione | |
| Compilata da | |
| Obiettivo (es. raddoppio capacità, consolidamento, sostituzione refresh DRAM) | |

## 2. Versioni software

| Campo | Attuale | Target | Esito | Fonte del dato |
|---|---|---|---|---|
| vCenter (versione + build) | | | | vCenter |
| ESX (versione + build), per host se diverse | | | | vCenter |
| Licenza / edizione (VCF, VVF, vSphere) | | | | scheda |
| Cluster gestito con vSphere Configuration Profiles (immagine singola) | | | | vCenter |

Soglie (decisione #37): < 8.0 U3 **Not supported** · 8.0 U3 **Tech preview** · **≥ 9.0 Supported**.
Nota ESX 9.0.x: problema noto con VM > 60 vCPU (vedi #42).

## 3. Host (una riga per host o per modello identico)

| Alias host | Marca / modello server | CPU (modello × socket, core) | DRAM installata (GB) | DRAM max (GB) | DIMM liberi | Slot NVMe totali | Slot NVMe liberi | Controller storage (passthrough / RAID, modello) | Optane PMem / NVDIMM-N | Quick Boot attivo | Esito |
|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | |

Fonte del dato: modello, CPU e DRAM installata da `vCenter`; DRAM max, DIMM liberi, slot NVMe e controller dalla `scheda` (schede tecniche OEM); Optane/NVDIMM e Quick Boot da `vCenter` se rilevabili (#40), altrimenti `scheda`.

## 4. Dispositivi NVMe già presenti

| Alias host | Modello drive | Capacità (GB) | Uso attuale (vSAN cache / vSAN data / datastore VMFS / boot / libero) | Partizioni presenti | Esito per il tiering |
|---|---|---|---|---|---|
| | | | | | |

Regole: il dispositivo per il tiering deve essere **dedicato**, **locale** (no NVMe-oF), **senza partizioni**
(KB 323144) e **non claimato da vSAN**; un vSAN data disk va prima rimosso dal disk group.

## 5. Drive NVMe proposti per il tier

| Campo | Valore | Requisito | Esito | Fonte del dato |
|---|---|---|---|---|
| Marca / modello / part number | | in BCG per la versione ESX target | | BCG |
| Capacità per drive (GB) | | ≥ DRAM dell'host (raccomandato), tier max 4 TB per host | | scheda |
| Classe d'uso | | **Mixed Use** | | BCG |
| Endurance (DWPD) | | **≥ 3** | | BCG |
| Endurance class BCG | | **D** (≥ 7.300 TBW) | | BCG |
| Performance class BCG | | **F** (100.000–349.999 write/s) o **G** (≥ 350.000) | | BCG |
| Form factor / interfaccia / PCIe gen | | compatibile con gli slot liberi (§3) | | scheda |
| Drive per host | | 1, oppure **2** per il mirror software (mirror ≥ primario) | | scheda |
| Riferimento BCG (ID / link / data verifica) | | obbligatorio | | BCG |

## 6. Ridondanza e funzionalità di cluster

| Campo | Valore | Nota |
|---|---|---|
| Ridondanza del tier (nessuna / mirror software / RAID hardware) | | Mirror o RAID raccomandati contro il guasto di un singolo drive |
| vSAN nel cluster (OSA / ESA / no) | | Il drive del tier non deve essere claimato da vSAN |
| vSphere HA attivo, restart policy configurata | | Riavvio delle VM dopo un guasto NVMe senza mirror |
| DRS attivo (livello di automazione) | | Cluster misti (host tierizzati e non) supportati |
| Memory overcommit in uso (ballooning, swap, TPS) | | Da evitare con il tiering attivo |
| VM con FT, passthrough/vGPU, Latency Sensitivity High, nested/VHV | | Escluse dal tiering: memoria solo in DRAM (#36, #42) |

## 7. Piano di intervento

| Campo | Valore |
|---|---|
| Upgrade software necessario (da → a) | |
| Finestre di manutenzione disponibili (ogni host va in maintenance mode) | |
| Firmware / BIOS / driver da aggiornare | |
| Costo stimato upgrade per host (opzionale, per #34) | |
| Costo drive NVMe per host | |
| Vincoli (supporto OEM, contratti, fine vita hardware) | |

## 8. Note e punti aperti

-
