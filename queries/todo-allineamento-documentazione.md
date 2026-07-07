---
title: TODO — Allineamento documentazione (framework e guida sviluppo)
type: query
tags: [todo, incoerenze]
updated: 2026-07-07
---

Liste di azioni concrete derivate dalla risoluzione delle incoerenze in [[incoerenze-doc-framework-vs-guida-sviluppo]], confermate dall'utente il 2026-07-07. Suddivise per documento da modificare.

## TODO — Documento framework "Agos X - Caricamento layer L0-L1" ([[agosx-caricamento-l0-l1]])

- [ ] **Orchestrazione**: aggiungere una sezione/nota che spiega che, oltre a Control-M (esecuzione), la creazione e gestione dei job dbt avviene tramite jobs-as-code/dbt Cloud sync, a cura del team. Chiarire il confine tra i due meccanismi. Vedi [[orchestrazione-control-m-vs-dbt-cloud]].
- [ ] **Nome tabella monitoraggio**: correggere `TECH.CFG_PROCESS_MONITORING` → `TECH.CFG_L0_L1_PROCESS_MONITORING` ovunque compaia nel documento.
- [ ] **Cluster A1/A2**: aggiungere la definizione dei sotto-cluster A1/A2 (oggi assente anche in guida sviluppo — va prodotta ex novo, verificando su [[cfg-l1-cluster-sto]]/codice quale criterio li distingue).
- [ ] **Sezione "Raccolta dei log" (L1)**: riscrivere. Il meccanismo reale non è dbt Artifacts ma una stored procedure custom `TECH.LOG_DBT` alimentata dalla macro `log_run_results` (vedi `dwh-code/macros/log/log_run_results.sql`). Verificare se le viste `V_L1_DBT_RUN_MODELS`/`V_L1_TEST`/`V_L1_TEST_RESULTS` esistono ancora e su quale sorgente dati si basano oggi.
- [ ] **Refuso**: `DT_INSERIMENTO` → `TS_INSERIMENTO` nel paragrafo esplicativo di [[cfg-l1-schema]] (il nome colonna corretto è `TS_INSERIMENTO`).
- [ ] Placeholder non risolti (fuori scope di questa sessione, ma da tracciare): periodo di retention file "xxx giorni" (spostamento `dati`→`archived`); rimando irrisolto a "capitolo xxx" per la forzatura del caricamento L1 dopo retry L0.

## TODO — Documento framework "Agos X - Caricamento layer L2" ([[agosx-caricamento-l2]])

- [ ] **Query tag**: correggere l'esempio con chiave accentata `"entità"` → `"entita"` (senza accento — coerente col resto del progetto, es. esempio Glue L0 nello stesso documento).
- [ ] **Storicizzazione S5**: aggiungere una sezione S5 "SCD2 mensile" per L3 (oggi documentata solo in guida sviluppo/`scd2_foto_mensile.sql`) — riepilogo strategia + quando si usa, senza necessariamente riportare tutto il dettaglio macro-per-macro già presente in guida sviluppo.
- [ ] **Sezione "Raccolta dei log" (L2)**: stesso intervento del documento L0-L1 — riscrivere sostituendo il riferimento a dbt Artifacts con la meccanica reale (`TECH.LOG_DBT`), e verificare `V_L2_DBT_RUN_MODELS`/`V_L2_TEST`/`V_L2_TEST_RESULTS`.
- [ ] **Refuso**: `FL_DELETE` → `FL_DELETED` nella sezione cancellazioni.
- [ ] Aree funzionali L2: valutare se aggiornare l'elenco ufficiale con `CARTE`, `SALDI`, `SWORD` (presenti nel codice, assenti dall'elenco) — vedi [[incoerenze-codice-vs-documentazione]] punto 4; non confermato dall'utente in questa sessione, da validare separatamente.

## TODO — Guida sviluppo interna ([[guida-sviluppo]])

- [ ] Nessuna correzione richiesta sui punti discussi in questa sessione (il nome tabella, la chiave query tag e S5 in guida sviluppo sono risultati corretti — è il documento framework che va allineato a questi).
- [ ] Punti aperti nel testo, ancora da risolvere (non trattati in questa sessione): "S1 non previsto?" per L3; quale colonna usare nel blocco incrementale S3 quando manca `DT_OSSERVAGIONE`; gestione di funzioni di conversione chiave più complesse in `delete_l2`.

## Non richiede TODO

- Duplicazione storicizzazione L2 in guida sviluppo §5.1/5.3: **lasciare com'è** (cheat-sheet voluto).

## Collegato da
[[incoerenze-doc-framework-vs-guida-sviluppo]], [[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]], [[guida-sviluppo]]
