# MTAT: come applica i requisiti del Memory Tiering

**Stato**: bozza v0.2 (2026-10-14). Epic #36, sub-issue #37–#42.
**Requisiti di riferimento**: [`vsphere-memory-tiering-requisiti.md`](vsphere-memory-tiering-requisiti.md);
analisi di fattibilità e ordine di lavoro: [`vsphere-memory-tiering-fattibilita.md`](vsphere-memory-tiering-fattibilita.md)
(specifica dei requisiti vSphere 9.1, ID `SW-`, `NV-`, `HW-`, `FN-`, `CP-`, `MN-`, `SM-`, `DR-`, …).

Questo documento non ripete i requisiti: per ciascuno dice **cosa fa MTAT**, cioè se lo verifica, lo
calcola, lo chiede come prerequisito o lo riporta come nota, con quale soglia ed esito, e in quale
issue viene sviluppato. È il riferimento per lo sviluppo e per i test (#4).

## 1. Modalità ed esiti

| Modalità | Significato |
|---|---|
| **AUTO** | verificato automaticamente dai dati raccolti (vCenter live o import) |
| **CALC** | entra nei calcoli di Sizing & Savings |
| **CHECK** | non rilevabile: prerequisito da confermare in checklist ed export |
| **NOTE** | informazione nel report, senza esito |

Esiti per host, cluster o VM: `PASS` · `WARN` · `FAIL` · `UNKNOWN` (dato non disponibile o query
fallita, mai assimilato a PASS o FAIL).

## 2. Regole MTAT

### 2.1 Versioni (#37)

| ID MTAT | Requisito | Modalità | Esito |
|---|---|---|---|
| M-VER-01 | SW-02 (ESX) | AUTO per host | vedi tabella |
| M-VER-02 | SW-01 (vCenter) | AUTO per vCenter | stessa logica |

**Decisione di Daniele (2026-10-14)**: la specifica indica 9.1+, ma per gli assessment MTAT usa tre
livelli. Fonti raccolte in #42: 8.0 U3 = tech preview (release notes 8.0.3, KB 95944); produzione da
9.0 secondo fonti secondarie (release notes VCF 9.0 da leggere); la doc 9.1 indica 9.1+.
*In discussione*: `vsphere-memory-tiering-fattibilita.md` §2 propone la soglia unica 9.1.

| Versione | Stato mostrato | Esito |
|---|---|---|
| < 8.0 U3 | `Not supported (ESXi x.y.z)` | FAIL |
| ≥ 8.0 U3 e < prima release GA | `Tech preview (not for production)` | WARN |
| ≥ GA | `Supported` | PASS |

*Aperto*: la versione GA esatta va presa dalle release notes (#42). Oggi il codice implementa solo
il livello "< 8.0 U3" (#29).

### 2.2 Workload (#38)

| ID MTAT | Requisito | Modalità | Soglia / esito |
|---|---|---|---|
| M-WL-01 | CP-04 | AUTO per host e cluster | **picco** active / DRAM ≤ 50% → PASS, altrimenti WARN |
| M-WL-02 | CP-03 | AUTO per VM | active medio della VM ≤ DRAM disponibile alla VM (dal ratio) → altrimenti WARN e VM elencata |
| M-WL-03 | CP-05 | AUTO per host | somma dell'active delle VM ≤ DRAM disponibile alle VM |
| M-WL-04 | soglia ~80% (spec. §12 punto 7) | NOTE + checklist | consumed < 80% → "il tiering non si attiverebbe oggi" |

### 2.3 Profili VM esclusi dal tiering (#38, #42)

Fonti: spec. §7.1 e §9.3; **KB 448305** (ufficiale, criteri di non idoneità per VM); blog VCF del
2026-08-06 (fonte secondaria). Dettaglio e link nel commento di `locale-windows` su #42.

| ID MTAT | Profilo | Come rilevarlo | Fonte | Effetto in MTAT |
|---|---|---|---|---|
| M-VM-01 | Low Latency | Latency Sensitivity = High | spec. §7.1, KB 448305 | DRAM-only |
| M-VM-02 | Confidential | SEV / SGX / TDX attivi | spec. §7.1 | DRAM-only |
| M-VM-03 | Fault Tolerant | FT configurata | spec. §7.1, blog | DRAM-only |
| M-VM-04 | Large | > 512 GB **e** 64 vCPU | spec. §7.1 | DRAM-only + nota (tiering off e reservation completa) |
| M-VM-05 | Nested | `vhv.enable = TRUE` (eccezione VBS: `sched.mem.enableNestedTiering`) | spec. §7.1, KB 448305 | DRAM-only salvo eccezione |
| M-VM-06 | Esclusa esplicitamente | `sched.mem.enableTiering = FALSE` (già letto da MTAT) | spec. §9.3, KB 448305 | DRAM-only |
| M-VM-07 | Memoria "All locked" | reservation "Reserve all guest memory (All locked)" | KB 448305 | DRAM-only; **conflitto** con il blog (reservation tierabili): da verificare in lab |
| M-VM-08 | Passthrough / DirectPath | dispositivi passthrough (già rilevati da MTAT) | blog (memoria pinned esclusa) | DRAM-only; manca una fonte ufficiale |
| M-VM-09 | vGPU | profilo vGPU | nessuna fonte | trattata come M-VM-08 (prudenziale) finché non c'è una fonte |

Le VM DRAM-only entrano nel requisito **CP-01**: la loro memoria va coperta interamente da DRAM nel
sizing (§2.4). Diagnostica post-attivazione: `memstats` (vmtier-stats), secondo la KB 448305.

**HA admission control**: nessuna fonte ufficiale. Regola prudenziale proposta: la capacità NVMe
**non** conta come margine di failover (#42).

### 2.4 Sizing (#39)

| ID MTAT | Requisito | Modalità | Dettaglio |
|---|---|---|---|
| M-SZ-01 | NV-10 | CALC | ratio 1:1 di default; cap a 4096 GB per host (già presente) |
| M-SZ-02 | NV-08, NV-11 | CALC + WARN | con NVMe < DRAM vale la capacità minore; avviso se NVMe < DRAM (oggi manca) |
| M-SZ-03 | FN-04 | CALC | la memoria del kernel non è tierizzabile: sottrarla prima del calcolo (stima da definire) |
| M-SZ-04 | CP-01 | CALC | DRAM minima = memoria delle VM DRAM-only (§2.3) + quota tierizzabile |
| M-SZ-05 | CP-02 | CALC | le reservation si dimensionano su DRAM/NVMe secondo la spec. |
| M-SZ-06 | SM-01…03 | CALC + WARN | mirroring raccomandato (opzione già presente); il mirror deve essere ≥ del primo device |
| M-SZ-07 | tier_size_pct 1–400 (spec. §8.5) | CALC | range valido dei ratio personalizzati nel simulatore |

### 2.5 Hardware e host (#40)

| ID MTAT | Requisiti | Modalità |
|---|---|---|
| M-HW-01 | NV-03, NV-04, NV-05 (NVMe locale e dedicato) | AUTO se rilevabile in sola lettura, altrimenti CHECK |
| M-HW-02 | NV-06 (non usato da vSAN) | AUTO |
| M-HW-03 | NV-07 (nessuna partizione) | CHECK (comando/KB nel report) |
| M-HW-04 | NV-01, NV-02 (Mixed Use, ≥ 3 DWPD, classi BCG) | CHECK (Greenfield, export) |
| M-HW-05 | HW-02, HW-03 (niente PMem / NVDIMM-N) | AUTO se rilevabile |
| M-HW-06 | FN-02 (Quick Boot) | AUTO se rilevabile, altrimenti CHECK |
| M-HW-07 | SW-04, HW-04, HW-06 (maintenance mode, niente hot-plug) | NOTE nel piano Brownfield (#34) |

### 2.6 Rischi operativi (#41)

| ID MTAT | Requisiti | Modalità |
|---|---|---|
| M-OP-01 | FN-03 (niente overcommit) | AUTO: memoria configurata delle VM rispetto a DRAM + NVMe per host → WARN |
| M-OP-02 | FN-01 (suspend-to-memory) | NOTE (AUTO se rilevabile) |
| M-OP-03 | DR-03, DR-04 (vMotion 1,5–2×) | NOTE |
| M-OP-04 | DR-01, DR-02, DR-05 (DRS, cluster misti) | NOTE: abilita un Brownfield parziale |
| M-OP-05 | spec. §11 (guasto NVMe, HA restart policy) | NOTE + raccomandazione mirror/HA |
| M-OP-06 | MN-01…04 (monitoraggio) | NOTE nel report post-attivazione |

## 3. Impatto su MTAT

| Componente | Regole |
|---|---|
| Raccolta live (`api/analyze`) | M-VER, M-WL-01…03, M-VM, M-HW (AUTO), M-OP-01/02 |
| Import offline (#26) | M-WL e M-VM se i dati per VM ci sono; il resto UNKNOWN o CHECK |
| Checklist Baseline | M-VER, M-WL, riepilogo M-VM/M-HW/M-OP |
| Sizing & Savings | M-SZ, M-VM (DRAM-only) |
| Report / export | tutte, con esito e riferimento al requisito |
| Fase 0 Setup (#28) | privilegi in sola lettura per le query AUTO (da verificare) |

## 4. Punti aperti

1. Versione GA del Memory Tiering (M-VER) → #42.
2. Rilevamento in sola lettura di PMem/NVDIMM, uso degli NVMe, Quick Boot, profili VM (M-HW, M-VM).
3. Stima della memoria kernel (M-SZ-03): valore fisso, percentuale o dato rilevato.
4. Fonte ufficiale per passthrough/vGPU (M-VM-08/09), conflitto "All locked" (M-VM-07), HA admission
   control → #42 e verifica in lab.
5. Punti [DA VERIFICARE] della specifica dei requisiti (§12), in particolare il 6 (50% "must" contro
   "should") e il 7 (soglia 80%).
6. Forma dell'avviso di prerequisito nel Brownfield (#34).

## Storico

| Versione | Data | Modifiche |
|---|---|---|
| 0.2 | 2026-10-14 | Profili VM con le fonti di #42 (KB 448305, blog VCF), conflitto "All locked", regola HA prudenziale, link alla fattibilità |
| 0.1 | 2026-10-14 | Prima stesura: mappatura dei requisiti della specifica 9.1 e delle pagine web A/B/C (#36) sulle regole MTAT; decisione sulle versioni di Daniele |
