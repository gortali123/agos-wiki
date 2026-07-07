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
- [ ] **Sezione "Raccolta dei log" (L1)**: riscrivere. Il meccanismo reale non è dbt Artifacts ma una stored procedure custom `TECH.LOG_DBT` alimentata dalla macro `log_run_results` (vedi `raw/dwh-code/macros/log/log_run_results.sql`). Verificare se le viste `V_L1_DBT_RUN_MODELS`/`V_L1_TEST`/`V_L1_TEST_RESULTS` esistono ancora e su quale sorgente dati si basano oggi.
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

## TODO — da [[incoerenze-codice-vs-documentazione]] (doc vs codice reale)

Documento framework "Agos X - Caricamento layer L0-L1":
- [ ] **Raccolta log**: sostituire il riferimento a dbt Artifacts con il meccanismo reale — stored procedure `TECH.LOG_DBT`, alimentata dalla macro `log_run_results` (JSON dei `results` dell'invocazione). Verificare se le viste `V_L1_DBT_RUN_MODELS`/`V_L1_TEST`/`V_L1_TEST_RESULTS` sono ancora valide o vanno riscritte di conseguenza.
- [ ] **`TECH.CFG_L1_SCHEMA`**: aggiornare i nomi colonna con quelli reali (`ds_archivio`, `cd_modulo`, `ds_sorgente`, `ds_column_name`, `ds_data_type`, `ds_length_col`, `fl_is_nullable`, `fl_is_primary_key`, `ts_riferimento`, `nm_campo`), sostituendo l'elenco attuale (`NM_CAMPO`, `DS_MODULO`, `DS_TABELLA`, `DS_CAMPO`, `DS_FORMATO`, `NM_LUNGHEZZA`, `FL_PK`, `FL_NULL`, `TS_INSERIMENTO`).
- [ ] **Refuso**: `ts_update_at` → `ts_updated_at` (nome colonna tecnica snapshot SCD2).
- [ ] **`PROGRESSIVO_PK`/`PROGRESSIVO_CONTROPARTE`**: arricchire la descrizione con la logica incrementale reale (oggi il documento descrive solo il caso full-refresh) — vedi `models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql` in `raw/dwh-code`.
- [ ] **Naming schema L1**: documentare il pattern `L1_E_<codice>` (sorgenti esterne non-OCS) / `L1_O_<modulo>` (OCS), oggi assente.
- [ ] **Cluster D**: aggiungere la definizione formale del Cluster D di storicizzazione L1 (materializzazione incremental/append, `pre_hook: delete_month(...)`, campo `sys_change_operation` da CDC SQL Server) accanto ai cluster A/B/C e ai sotto-cluster A1/A2 — **confermato reale e da documentare** (2026-07-08). Vedi [[storicizzazione-l1-cluster]].

Documento framework "Agos X - Caricamento layer L2":
- [ ] **Raccolta log**: stesso intervento del documento L0-L1 (sostituire dbt Artifacts con `TECH.LOG_DBT`), verificando `V_L2_DBT_RUN_MODELS`/`V_L2_TEST`/`V_L2_TEST_RESULTS`.
- [ ] **Aree funzionali**: allineare l'elenco ufficiale con la realtà del codice (`CARTE`, `SALDI`, `SWORD` presenti nel codice ma non nell'elenco; 9 aree elencate ma senza cartella nel codice), incluso chiarire il caso `CARTE` → schema `L2_PRODOTTO`. **Priorità bassa, da fare con calma** (indicazione esplicita dell'utente).

Nessuna azione richiesta: severity di `primary_key_table` (già corretta, hardcoded `error` nel test generico).

## TODO — Security/masking (da verificare col team infra/sicurezza)

Voce generica, come indicato dall'utente (2026-07-08) — non prendere posizione in wiki finché non c'è un riscontro dal team security:
- [ ] **Masking su L0**: `apply_privacy_to_l0_from_matrix()` applica tag/masking policy direttamente su tabelle L0, in contraddizione con l'affermazione del documento ufficiale ("il masking parte da L1 perché L0 non è accessibile agli utenti finali"). Verificare con team infra/sicurezza se è un meccanismo voluto (e quindi da documentare) o un errore di implementazione da correggere. Vedi [[data-masking]], [[incoerenze-codice-vs-documentazione]] punto 9.
- [ ] **`remove_datamask()` mancante**: citata in guida sviluppo ma assente dal codice sincronizzato in `raw/dwh-code`. Verificare con team infra/sicurezza se esiste altrove nel repo GitLab non ancora copiato, se è prevista ma non scritta, o se il riferimento in guida sviluppo va rimosso. Vedi [[data-masking]], [[incoerenze-codice-vs-documentazione]] punto 10.

## Non richiede TODO

- Duplicazione storicizzazione L2 in guida sviluppo §5.1/5.3: **lasciare com'è** (cheat-sheet voluto).

## Collegato da
[[incoerenze-doc-framework-vs-guida-sviluppo]], [[incoerenze-codice-vs-documentazione]], [[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]], [[guida-sviluppo]]
