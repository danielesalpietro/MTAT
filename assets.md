# Assets: inventario dei sistemi di laboratorio

Riferimenti ai sistemi usati per sviluppo e validazione di MTAT (vCenter, ESXi, storage, rete…).
Le sessioni lo popolano man mano che i sistemi vengono usati (vedi `CLAUDE.md`).

## ⚠️ Dove vanno i dati reali

Il fork **è pubblico**. Questo file versionato contiene solo **il formato e le regole**: nessun
hostname, IP, utente o nome cliente reale.

I dati reali stanno in **`assets.local.md`**, nella root del clone sul PC di Daniele, **escluso da
git** (`.gitignore`), con le stesse colonne della tabella qui sotto. Lo mantiene la sessione
`locale-windows`. Se il repository diventa privato, le voci possono essere spostate qui.

Le **password non vanno mai** né qui né in `assets.local.md`: si indica solo il **percorso del file
locale** che la contiene (es. `%USERPROFILE%\.mtat\secrets\vc-lab-01.txt`). Le sessioni non leggono
e non stampano il contenuto di quei file: le credenziali le inserisce Daniele dalla UI di MTAT.

## Formato

| Alias | Tipo | Ruolo | Versione | Host / IP | Porta | Utente | Password (file locale) | Accesso da | Note |
|---|---|---|---|---|---|---|---|---|---|

Colonne:
- **Alias**: nome stabile e anonimo (`vc-lab-01`, `esxi-lab-01`), l'unico da usare in issue,
  logbook e commit.
- **Tipo**: `vCenter`, `ESXi`, `NVMe/storage`, `rete`, `altro`.
- **Ruolo**: a cosa serve (es. "cluster con Memory Tiering attivo", "test sola lettura").
- **Versione**: build vSphere/ESXi (il tiering richiede 8.0 U3+).
- **Utente**: account e privilegi (es. `svc-mtat-ro`, sola lettura).
- **Accesso da**: quale sessione/macchina lo raggiunge (es. `locale-windows`).
- **Note**: Statistics Level, cluster rilevanti, vincoli, finestre di manutenzione.

## Esempio (fittizio)

| Alias | Tipo | Ruolo | Versione | Host / IP | Porta | Utente | Password (file locale) | Accesso da | Note |
|---|---|---|---|---|---|---|---|---|---|
| vc-lab-01 | vCenter | lab principale, test sola lettura | 8.0 U3 | vcenter.example.invalid | 443 | svc-mtat-ro@vsphere.local | `%USERPROFILE%\.mtat\secrets\vc-lab-01.txt` | locale-windows | Statistics Level 2 su 1 g/7 g |
