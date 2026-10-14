# Roadmap: da MTAT a piattaforma di assessment e simulazione

Obiettivo: passare da uno strumento che **misura** un cluster oggi a una piattaforma che
**conserva lo storico di più clienti, lo confronta, simula scenari** e lo spiega con un LLM
self-hosted (vLLM) basato su una knowledge library. Un passo alla volta: ogni fase è
utilizzabile da sola e non rompe la precedente.

## Fase 0: MTAT containerizzato (beta) ✅ in questo branch
- `docker compose up -d --build` → motore v3.1 headless + PowerCLI su Linux.
- Script originale invariato nel comportamento desktop (modalità container solo via env var).
- CI: build reale con PowerCLI + smoke test; immagine su GHCR.
- **Da validare**: run su vCenter/ESXi reali (stato tiering via `Get-EsxCli` su Linux).

## Fase 1: persistenza dei risultati
Oggi ogni analisi vive solo nel browser (export CSV manuale).
- Il motore salva ogni risultato di `/api/analyze` come JSON nel volume
  (`cliente / vcenter / cluster / range / timestamp`).
- Schema dati normalizzato e versionato (host, VM, metriche, contesto di raccolta).
- Import dello storico già esistente: CSV MTAT ed export RVTools (il parser JS esiste già).
- **Anonimizzazione** opzionale (hash di nomi host/VM/cluster) al salvataggio: i dati di
  più clienti sono soggetti a NDA/GDPR.

## Fase 2: servizio dati + motore di simulazione condiviso
- PostgreSQL (eventualmente TimescaleDB per le serie temporali) come servizio compose.
- API in Python (FastAPI) separata dal collector PowerShell, che diventa un worker di raccolta.
- **Port della matematica di simulazione** (oggi in JS nella UI: Brownfield/Greenfield,
  rapporto DRAM:NVMe, limite 4 TB NVMe) in una libreria Python con test di equivalenza
  contro l'implementazione JS, così UI, API e LLM usano gli stessi numeri.

## Fase 3: knowledge library
- Corpus: documentazione VMware Memory Tiering, KB, best practice, note interne, report passati.
- Ingestion → chunking → embeddings → `pgvector` (stesso Postgres della fase 2).

## Fase 4: vLLM + analisi assistita
- Servizio `vllm` (API OpenAI-compatible) nel compose, profilo `ai`, richiede GPU NVIDIA.
- Modello open con tool-calling; RAG sulla knowledge library.
- Regola chiave: **l'LLM non calcola i numeri**. Chiama tool deterministici
  (query sullo storico, motore di simulazione della fase 2) e spiega/commenta i risultati.

## Fase 5: simulazioni e confronti
- What-if: rapporto tiering, numero/tipo host, crescita del carico, consolidamento.
- Confronto tra raccolte dello stesso cliente nel tempo (trend, stagionalità).
- Benchmark anonimo tra clienti (percentili di active/consumed per tipologia di workload).
- Report generati (HTML/PDF) con numeri dal motore e narrativa dall'LLM.

## Architettura target (compose profiles)

| Profilo | Servizi |
|---|---|
| `core` | `mtat` (collector + UI attuale) |
| `platform` | `postgres` (+pgvector), `api` |
| `ai` | `vllm`, `embeddings` |
