# Log

Append-only. Each entry: `## [YYYY-MM-DD] ingest|query|lint | <title>`

## [2026-07-07] setup | wiki initialized

Vault created at `C:\Users\g.ortali\work\agos-wiki`, scoped to the `my_dwh-x-dbt` project (Agos DWH/dbt). Structure: raw/, entities/, concepts/, sources/, queries/, index.md, log.md, CLAUDE.md. Obsidian-friendly conventions (wikilinks + frontmatter).

## [2026-07-07] ingest | Agos X - Caricamento layer L0-L1.docx, Agos X - Caricamento layer L2.docx, guida_sviluppo.docx

Primo ingest sostanziale della wiki. Estratto testo dai tre .docx (via unzip + xml stripping, i .docx non sono leggibili direttamente) e letti integralmente. Creati: 3 pagine sources/, 4 entity layer (L0-L3), 7 entity tabelle tecniche di config/log, 11 pagine concepts/ (naming, storicizzazione L1/L2/L3, cancellazioni, data quality, data masking, file civetta, errori/retry L0, parsing COBOL, orchestrazione). Filata come queries/ un'analisi di incoerenze cross-documento riscontrate durante l'ingest, la più rilevante delle quali riguarda l'orchestrazione (Control-M vs dbt Cloud) — vedi [[incoerenze-doc-framework-vs-guida-sviluppo]]. Non ancora incrociato nulla col repo `my_dwh-x-dbt` (fuori scope di questo ingest, solo testo dei documenti).

## [2026-07-07] setup | dwh-code submodule

Aggiunto `dwh-code/` come git submodule verso `https://github.com/target-reply/my_dwh-x-dbt` (copia curata pubblicata dall'utente da `dwh-x-dbt`, allineata con `sync-from-dwh-x-dbt.ps1`: macros/templates/tests interi, file radice .yml/.py/.md/.ps1, models/L2 e L3 interi, sample L0/L1 ADOBE e OCS/AIN, snapshot L1/OCS/AIN). Aggiornato CLAUDE.md con la convenzione: citare path relativi a `dwh-code/` quando il file esiste nello snapshot, altrimenti testo semplice contro il repo live.

## [2026-07-07] lint | codice reale (dwh-code) vs documentazione

Confrontato un campione di macro/dbt_project.yml/modelli in `dwh-code/` con le pagine wiki derivate dai documenti di framework e dalla guida sviluppo. Trovate diverse incoerenze rilevanti, la più importante delle quali è che il meccanismo di logging reale (stored procedure custom `TECH.LOG_DBT` via macro `log_run_results`) è completamente diverso da quanto descritto nei documenti ufficiali (pacchetto dbt Artifacts, mai installato: nessun `packages.yml` nel repo). Altre: nomi colonna reali di `TECH.CFG_L1_SCHEMA` diversi da quelli documentati, severity di `primary_key_table` non risulta impostata a fail nel generatore, elenco aree funzionali L2 reali diverso da quello ufficiale (con un caso di schema disallineato dalla cartella: CARTE → schema L2_PRODOTTO). Dettaglio completo in [[incoerenze-codice-vs-documentazione]]. Verifica su campione, non esaustiva.

## [2026-07-07] query | risoluzione incoerenze doc framework vs guida sviluppo + TODO

L'utente ha commentato punto per punto le 8 incoerenze in [[incoerenze-doc-framework-vs-guida-sviluppo]]: confermati come reali/da documentare i punti 1 (orchestrazione: Control-M esegue, jobs-as-code gestisce la creazione job, responsabilità del team), 5 (cluster A1/A2 reali) e 6 (S5 reale); confermati come refusi nel doc ufficiale i punti 3 (nome vero `TECH.CFG_L0_L1_PROCESS_MONITORING`), 4 (chiave vera `entita` senza accento) e i refusi `FL_DELETED`/`TS_INSERIMENTO`; punto 2 chiarito come non-incoerenza (test source solo in L1 by design); punto 7 confermato obsoleto (coerente con la scoperta separata in [[incoerenze-codice-vs-documentazione]] sul logging reale via `TECH.LOG_DBT`); punto 8 nessuna azione. Aggiornate le pagine wiki coinvolte con gli esiti, creata [[todo-allineamento-documentazione]] con le liste di azioni concrete per doc L0-L1, doc L2 e guida sviluppo.
