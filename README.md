# Memory Tiering Assessment Tool (MTAT)

*English · [Italiano](README_IT.md)*

**MTAT** is a workload planning and sizing utility for vSphere **Memory Tiering over NVMe**. It reads
a cluster's hosts and VMs from vCenter (or from an offline import), checks them against the Memory
Tiering requirements and estimates what tiering would deliver and cost, for an existing cluster
(**Brownfield**) or a new one (**Greenfield**).

> **This is a working fork of MTAT v3.1.** The fork adds a headless Docker deployment, a digital
> twin of vCenter/ESXi for tests and demos, and the Memory Tiering rule checks described below. It
> is evolving towards an assessment, history and simulation platform: see
> [`docs/ROADMAP.md`](docs/ROADMAP.md). With no `MTAT_*` environment variable set, the desktop
> behaviour of `MTAT_v3_1.ps1` is the same as the original v3.1. The v3.0 release is preserved
> under **Releases → v3.0.0**; `CHANGELOG.md` lists the changes up to v3.1.

## 🗂️ Repository contents

| Path | Content |
|---|---|
| `MTAT_v3_1.ps1` | engine and UI in a single file (PowerShell with embedded HTML/JS), cross-platform |
| `MTAT_v3_1.exe` | Windows executable of the original v3.1 (not rebuilt by this fork) |
| `docker/`, `docker-compose.yml` | headless container deployment ([`docker/README.md`](docker/README.md)) |
| `twin/`, `docker-compose.twin.yml` | **digital twin** of vCenter/ESXi ([`twin/README.md`](twin/README.md)) |
| `tests/` | sizing unit tests and the twin end-to-end test |
| `docs/` | Memory Tiering requirements, how MTAT applies them, feasibility, roadmap (in Italian) |

## 🧭 What the UI does

1. **vCenter Connection**: one or more vCenters, read-only account. When live access is not
   available, the Matrix/History import works offline.
2. **Baseline Assessment**: CPU, active and consumed memory per range (Real-Time, 24 h, 7 and
   30 days), per host and per VM tables, CSV export. Per host it reports the tiering state and the
   **support level of the ESXi version** (below 8.0 U3 Not supported, 8.0 U3 Tech preview, 9.0
   and later Supported). The checklist flags hosts and VMs above the **active-memory thresholds**:
   - host peak above 50% of DRAM;
   - VM average above its DRAM share;
   - VM demand above host DRAM.
3. **Sizing & Savings**:
   - Brownfield: add NVMe to the current hosts;
   - Greenfield: size new hosts, with or without tiering.

   Both take into account the 4 TB NVMe cap per host, the 1–400% ratio range, VMs that must stay
   in DRAM, an optional ESXi system memory per host, and warnings for NVMe smaller than DRAM or
   without redundancy.
4. **Brownfield Readiness Checklist**: one row per prerequisite with Passed / Failed / Warning /
   Skipped. Some rules are automatic, from the analysis; the others are confirmed by hand (HA/DRS,
   vSAN, NVMe hardware, VM exclusions).

The rules, their sources and their IDs are in
[`docs/vsphere-memory-tiering-requisiti.md`](docs/vsphere-memory-tiering-requisiti.md) and
[`docs/mtat-regole-memory-tiering.md`](docs/mtat-regole-memory-tiering.md).

## 🐳 Docker (beta)

Run the engine headless in a Linux container, with PowerShell 7 and a pinned PowerCLI set:

```bash
docker compose up -d --build
# then browse to http://localhost:8600
```

The UI is published on the host loopback only, and the API rejects foreign `Host`/`Origin` headers
(DNS rebinding and CSRF protection). Configuration (`MTAT_HEADLESS`, `MTAT_PORT`, `MTAT_BIND_HOST`,
`MTAT_ALLOWED_HOSTS`, `MTAT_DATA_DIR`) and security notes are in
[`docker/README.md`](docker/README.md).

## 🧪 Digital twin (no vCenter needed: tests and demos)

The digital twin replaces PowerCLI with a fake `VMware.VimAutomation.Core` module that answers from
a **JSON scenario**:
- vCenters, clusters, ESXi hosts of different versions;
- tiering on, off, or failing;
- VMs with pinned memory, tiering exclusions, more than 60 vCPUs;
- historical statistics.

It exercises the whole of MTAT, from connection to sizing and export, with no lab and no
credentials. This makes it handy for **demos** too.

```bash
MTAT_TWIN=mixed-90 docker compose -p mtat-twin -f docker-compose.yml -f docker-compose.twin.yml up -d --build
# browse to http://localhost:8601 and connect to vCenter "vc-twin-90" with any user name and password
```

| Scenario (`MTAT_TWIN`) | vCenter to type | Shows |
|---|---|---|
| `mixed-90` | `vc-twin-90` | vCenter 9.0, mixed cluster of five hosts (8.0.2, 8.0.3 tech preview, 9.0 with tiering on, off and failing); DRAM-only and > 60 vCPU VMs; hosts and VMs above the active thresholds |
| `lab-802` | `vc-twin-lab` | a small single-host 8.0.2 lab (Not supported) |
| `no-clusters` | `vc-twin-empty`, `vc-twin-denied` | a vCenter without clusters and a refused login |

The twin runs as a separate compose project on port 8601, next to a real MTAT container. The
engine log starts with `[TWIN] *** MTAT DIGITAL TWIN active`, so its data cannot be taken for a
real vCenter. Adding scenarios: [`twin/README.md`](twin/README.md).

## ✅ Requirements (live mode)

### Software & environment

*   **PowerShell:** Windows PowerShell on Windows, or PowerShell 7 on Windows, macOS and Linux.
*   **VMware PowerCLI:** the `VMware.VimAutomation.Core` module must be installed. The engine checks
    for it at launch and stops with a critical error if it is missing. The Docker image already
    includes it.
*   **A modern web browser:** the engine starts a local web server and opens an HTML5 interface.
*   **A free local TCP port:** default `8600`. On the desktop, the engine moves to the next free
    port (`8601`, `8602`…) if `8600` is taken.

### vSphere & connectivity

*   **vCenter network access** over HTTPS (port 443) from the machine running MTAT.
*   **Credentials:** a **read-only** account is enough to read the inventory (clusters, hosts, VMs)
    and the performance statistics. Assign it the Read-only role on the vCenter root, with
    propagation. Querying the tiering state through `esxcli` may also need the
    `Host > Configuration > Advanced settings` privilege; without it the state shows as
    `Unknown (query failed)`.

### Historical data (optional)

*   **vCenter statistics level 2** is required for the historical ranges (24 hours, 7 and 30 days).
    With lower levels the tool falls back to the available ranges. "Active Memory (Peak)" is the
    maximum of the standard `.average` samples in the window, so level 2 is enough.

## 🚀 Installation & setup

### Windows (executable)
1. Download `MTAT_v3_1.exe` from the repository. It is the original v3.1: the additions of this
   fork are only in `MTAT_v3_1.ps1`.
2. Double-click it to launch the tool.

### Any OS (PowerShell)
1. Clone the repository or download `MTAT_v3_1.ps1`.
2. Open PowerShell and make sure scripts are allowed to run:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. Run the script:
   ```powershell
   .\MTAT_v3_1.ps1
   ```

### Docker
See [Docker (beta)](#-docker-beta) above.

## 🔧 Development

```bash
node tests/sizing.test.js                                                # unit tests of the sizing and rule helpers
node tests/twin-e2e.js twin/scenarios/mixed-90.json http://127.0.0.1:8601  # end-to-end on a running twin
```

The CI (`.github/workflows/docker-image.yml`) does three things:
- builds the real image and runs a smoke test;
- runs the unit tests;
- runs every twin scenario end to end.

Project rules (issues, sessions, logbook, commit conventions, CRLF line endings of the script) are in
[`CLAUDE.md`](CLAUDE.md).
