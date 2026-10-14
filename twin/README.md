# MTAT digital twin (#47)

Gemello digitale di vCenter/ESXi: un modulo PowerShell con lo stesso nome del modulo PowerCLI
(`VMware.VimAutomation.Core`, versione `99.0.0`) che implementa **solo** le chiamate e le proprietà
usate da `MTAT_v3_1.ps1`, a partire da uno **scenario JSON**. Serve a validare la logica di MTAT
end-to-end (raccolta, stati del tiering, regole, sizing) senza laboratorio e senza credenziali.

> Valida la **logica di MTAT**, non il comportamento di vSphere. La forma degli oggetti va tenuta
> allineata a registrazioni reali in sola lettura (`locale-windows`): se differiscono, si corregge
> il gemello, non MTAT.

## Uso

```bash
MTAT_TWIN=mixed-90 docker compose -p mtat-twin -f docker-compose.yml -f docker-compose.twin.yml up -d --build
# UI: http://localhost:8601, poi connettersi al vCenter dello scenario (es. vc-twin-90), con utente e password qualsiasi
node tests/twin-e2e.js twin/scenarios/mixed-90.json     # test end-to-end dello scenario
```

Il motore stampa `[TWIN] *** MTAT DIGITAL TWIN active ***` nei log: non può essere scambiato per
un vCenter reale. Il progetto separato (`-p mtat-twin`, porta 8601) non tocca il container reale.

## Scenari (`scenarios/*.json`)

| Scenario | Copre |
|---|---|
| `lab-802` | riproduce `vc-lab-01`: 1 host ESXi 8.0.2 da 96 GB, 2 VM accese, una spenta; Not supported |
| `mixed-90` | vCenter 9.0, cluster misto: 8.0.3 con tiering attivo (Tech preview), 9.0 con CLI legacy e `Mem.TierNVMePct=50`, 9.0 disattivo, 9.0 con esxcli in errore, 8.0.2; VM pinned, `sched.mem.enableTiering=FALSE`, Latency Sensitivity High, VM non risolvibile; storici a livello 2 |
| `no-clusters` | vCenter senza cluster e vCenter con login rifiutato |

Struttura: `vcenters[]` → `statsIntervals[]` (key, samplingPeriod, level, enabled) e `clusters[]` →
`hosts[]`.

Per ogni host:
- `version`, `build`, `cpu` {mhz, cores}, `memoryGB`;
- `realtime` {cpuUsageMhz, memUsageMB};
- `tiering`: {esxcli: `memtier` | `kernel` | `none` | `error`, status, ratio, runtime, error, delaySeconds};
- `advancedOptions`;
- `stats` {cpuPct, activePctOfDram, consumedPctOfDram: {avg, peak}};
- `vms[]`.

Per ogni VM: `memoryGB`, `vcpu`, `powerState`, `realtime.activeMB`, `stats.activePct`, `pinned`,
`extraConfig`, `latencySensitivity`, `unresolvable`.

Le serie storiche sono deterministiche: un solo campione al picco e tutti gli altri uguali, quindi
media e massimo sono esatti e i valori attesi si calcolano a mano. Il blocco `expect` contiene ciò
che `tests/twin-e2e.js` verifica.

## Aggiungere un caso

1. Nuovo file in `scenarios/` (oppure un host o una VM in uno esistente) con il relativo `expect`.
2. Se MTAT legge una proprietà nuova, aggiungerla al modulo con lo stesso nome e la stessa forma di
   PowerCLI. Possibilmente verificarla su una registrazione reale.
3. La CI (`twin-e2e`) esegue tutti gli scenari a ogni push.
