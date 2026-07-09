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

## [2026-07-07] query | risoluzione incoerenze codice vs documentazione + TODO

L'utente ha commentato le 8 incoerenze in [[incoerenze-codice-vs-documentazione]]. Confermati da aggiornare nel doc framework: punto 1 (logging reale via `TECH.LOG_DBT`), punto 2 (nomi colonna reali di `TECH.CFG_L1_SCHEMA`), punto 6 (`ts_updated_at` è il nome corretto). Punto 3 (severity `primary_key_table`) **ritirato come falso allarme** dopo verifica diretta di `tests/generic/primary_key_table.sql`: la severity `error` è hardcoded nel test stesso via `config(severity='error')`. Punto 4 (aree funzionali L2) da allineare ma a bassa priorità. Punto 5 (naming schema L1_E_/L1_O_) da documentare. Punto 7 (logica PROGRESSIVO_PK/PROGRESSIVO_CONTROPARTE) da allineare con la descrizione reale. Aggiornate le pagine [[cfg-l1-schema]] e [[layer-l1]] con i nomi reali confermati; estesa [[todo-allineamento-documentazione]] con le nuove azioni.

## [2026-07-08] query | ottimizzazione performance variazioni_anagrafiche (SCD2 su CCANALOG)

Diagnosticato perché `variazioni_anagrafiche.sql` ricalcola `LEAD`/`LAG` (TS_FINE_VALIDITA + dedup hash) su tutta la storia di CCANALOG ad ogni run incrementale, prima che `is_incremental_S1` applichi il filtro: il filtro arriva dopo i window function, non prima. Proposta di design strutturale: sostituire con pattern "delta + last-open row dal target", ricalcolando i window function solo su un set minuscolo (1 riga aperta + poche nuove per controparte) e lasciando che il merge di dbt faccia UPDATE/INSERT in base all'unique_key esistente. Prima iterazione della proposta troppo complessa (7+ CTE, macro-wrapper inutili) — semplificata su richiesta dell'utente a 3 CTE (stesso numero dell'originale), senza macro nuove e senza `SELECT *`. Codice SQL completo scritto in [[variazioni_anagrafiche_ottimizzato.sql|queries/variazioni_anagrafiche_ottimizzato.sql]], dettaglio/diagnosi/punti aperti in [[ottimizzazione-variazioni-anagrafiche-scd2]]. Proposta non ancora implementata nel repo live né testata su dati reali.

## [2026-07-07] ingest | seconda passata su dwh-code (macro rimanenti + template)

Letta la parte rimanente di `dwh-code`: macro `generate_models/*` (incl. `transcod_dtype`, `get_model_names`), `materialization/get_dt_osservazione`/`last_day_past_month`, `apply_privacy_to_l0_from_matrix`, `generate_schema_name`, `truncate_models`, template `models/L1/{A,B,C,D}` e `models/L2/{S1..S4}`. Due scoperte rilevanti: (1) un **Cluster D** di storicizzazione L1 (append mensile, campo `sys_change_operation` da CDC SQL Server) mai documentato in nessun documento — aggiunto a [[storicizzazione-l1-cluster]]; (2) una seconda macro di masking, `apply_privacy_to_l0_from_matrix`, applica tag/policy **direttamente su L0**, in contraddizione esplicita con l'affermazione del documento ufficiale che il masking parte solo da L1 — aggiornato [[data-masking]]. Aggiunta anche [[transcodifica-datatype-l0-l1]] per documentare la macro `transcod_dtype`. Aggiornata [[incoerenze-codice-vs-documentazione]] con i punti 9-11. Non ancora validato con l'utente.

## [2026-07-08] setup | dwh-code spostato in raw/

Spostato il submodule `dwh-code` dentro `raw/dwh-code` (era a livello radice del vault), su richiesta dell'utente — coerente con la sua natura di sorgente immutabile. Aggiornati `.gitmodules`, i puntatori interni gitdir/worktree del submodule, `CLAUDE.md` e tutte le pagine wiki che citavano il path `dwh-code/` (ora `raw/dwh-code/`). Verificato che il submodule resta funzionante dopo lo spostamento (`git submodule status` OK).

## [2026-07-08] setup | remote dwh-code cambiato da target-reply a gortali123

Il remote GitHub del submodule `raw/dwh-code` è cambiato da `target-reply/my_dwh-x-dbt` a `gortali123/my_dwh-x-dbt` (stesso contenuto, verificato via `git ls-remote` prima dell'aggiornamento: stesso commit HEAD `95747d6`). Aggiornati `.gitmodules`, il remote `origin` dentro `raw/dwh-code`, e i riferimenti testuali in `CLAUDE.md` e `index.md`.

## [2026-07-08] setup | dwh-code: da git submodule a cartella semplice

Su richiesta dell'utente, convertito `raw/dwh-code` da git submodule a semplice cartella di file tracciati normalmente. Il deinit del submodule ha inizialmente svuotato la working tree; il contenuto è stato ripristinato con un clone pulito da `https://github.com/gortali123/my_dwh-x-dbt` (stesso commit `95747d6` di prima), poi rimosso il relativo `.git` interno e aggiunto tutto come file normali. Rimosso `.gitmodules`. Aggiornati `CLAUDE.md` e `index.md` per riflettere che non è più un submodule (nessun comando `git submodule` necessario per aggiornarlo: l'utente ri-sincronizza e ricopia i file direttamente).

## [2026-07-08] ingest | riletto guida_sviluppo.docx dopo modifica utente

L'utente ha incollato in [[guida-sviluppo]] §5.1 (subito dopo "S1 — SCD2") il blocco di documentazione preparato in [[bozza-doc-s1-main-senza-pk]] sulla variante S1 per tabelle main L1 senza PK propria (PK = ROWID, disambiguazione via `PROGRESSIVO_PK`). Ri-estratto il testo del docx e confrontato: inserimento verificato integrale, nessun'altra modifica al resto del documento. Aggiornate [[guida-sviluppo]] (takeaway), [[storicizzazione-l2-s1-s4]] (variante ora "applicata" non più bozza), [[bozza-doc-s1-main-senza-pk]] (marcata come applicata), e chiuso parzialmente il punto 7 di [[incoerenze-codice-vs-documentazione]] e la relativa voce in [[todo-allineamento-documentazione]] (resta aperto solo l'allineamento del documento di framework ufficiale, non toccato da questa modifica).

## [2026-07-08] ingest | Agos X - Layer L2.xlsx (solo struttura, non contenuto)

Ingerita solo la **struttura, il significato e l'uso** del nuovo file `raw/Agos X - Layer L2.xlsx` (data model dettagliato L2/L3, citato dalla guida sviluppo come "data model" con sheet `catalogo_entita`), su richiesta esplicita dell'utente — non un ingest completo del contenuto (~230 fogli, ~140 entità con dettaglio campo per campo, troppo per questa sessione). Ispezionato via Excel COM in sola lettura (nessuna scrittura/export del file). Creata [[agosx-layer-l2-datamodel]] con la mappa dei fogli (meta: Nomenclatura Campi/Frequenza/SubjectArea, Catalogo Entità, Catalogo Categorie Campi, DataQualityInterna; poi un foglio per entità con schema colonne costante). Trovata una **terza tassonomia di codici area L2** (foglio Nomenclatura SubjectArea) diversa sia dal documento ufficiale sia dalle cartelle reali in dbt_project.yml — aggiunta come incoerenza aperta in [[naming-conventions]], non ancora discussa con l'utente. Segnalati anche fogli da ignorare (_OLD, WIP, note personali, alcuni fogli con range colonne anomalo/gonfiato).

## [2026-07-08] query | risoluzione incoerenze codice vs documentazione (punti 9-11)

L'utente ha risposto alle domande sui punti 9-11 di [[incoerenze-codice-vs-documentazione]]: punto 11 (Cluster D di storicizzazione L1) confermato reale, da aggiungere al documento di framework — aggiornata [[storicizzazione-l1-cluster]] e [[todo-allineamento-documentazione]]. Punti 9 (masking su L0 via `apply_privacy_to_l0_from_matrix`) e 10 (`remove_datamask()` mancante dal codice) lasciati aperti come TODO generico verso il team infra/sicurezza, senza prendere posizione in wiki — aggiornate [[data-masking]] e [[todo-allineamento-documentazione]] (nuova sezione "Security/masking").

## [2026-07-09] query | ottimizzazione incrementale indirizzi_postalizzazione (SCD2 su BAPRATAG)

Applicato a `indirizzi_postalizzazione.sql` lo stesso pattern già proposto per `variazioni_anagrafiche.sql` ([[ottimizzazione-variazioni-anagrafiche-scd2]]): stessa struttura a 3 CTE COMBINED→DEDUP→DEDUP_FV, senza rescan full-history su LEAD/LAG prima del filtro incrementale. Versione più semplice dell'originale perché il modello non ha PROGRESSIVO_PK/PROGRESSIVO_CONTROPARTE né join di lookup nel SELECT finale — vedi [[ottimizzazione-indirizzi-postalizzazione-scd2]] e il codice in [[indirizzi_postalizzazione_ottimizzato.sql|queries/indirizzi_postalizzazione_ottimizzato.sql]]. Seconda istanza confermata del pattern, rafforza il caso per una futura pagina concepts/pattern-incrementale-scd2. Non implementata né testata su dati reali.

## [2026-07-09] query | ottimizzazione incrementale variazioni_anagrafiche_day (SCD2 giorno su variazioni_anagrafiche)

Terza istanza dello stesso pattern di ottimizzazione, applicato a `variazioni_anagrafiche_day.sql`. Rispetto ai due casi precedenti ([[ottimizzazione-variazioni-anagrafiche-scd2]], [[ottimizzazione-indirizzi-postalizzazione-scd2]]) emersa una complicazione nuova: il ramo delta non può limitarsi alle righe nuove della fonte (`variazioni_anagrafiche`), deve includere tutte le righe dei `(controparte, giorno)` toccati per rideterminare correttamente il "vincitore" del giorno via `ROW_NUMBER` — la fonte qui è già un aggregato SCD2, non un evento a grana atomica con PK naturale. Vedi [[ottimizzazione-variazioni-anagrafiche-day-scd2]] e il codice in [[variazioni_anagrafiche_day_ottimizzato.sql|queries/variazioni_anagrafiche_day_ottimizzato.sql]]. Non implementata né testata su dati reali; dipende anche dall'ottimizzazione (non ancora implementata) del modello upstream.

## [2026-07-09] query | bug delete_l2 al primo run/full-refresh

Confermato: `delete_l2` (raw/dwh-code/macros/logic_delete/delete_l2.sql) non ha guard `is_incremental()`, quindi il `DELETE FROM {{ this }}` nel pre-hook fallisce al primo run di un'entità o dopo `--full-refresh`, quando la tabella target non esiste ancora. Verificato su tutti i ~15 modelli che lo usano come pre-hook (nessuno lo condiziona lato chiamante). Vedi [[bug-delete_l2-primo-run]] per diagnosi e fix proposto (guard dentro la macro). Aggiornato [[gestione-cancellazioni]] con nota del bug. Non verificato contro un run reale né discusso col team dwh-x-dbt.

## [2026-07-09] query | fix delete_l2 pronto

Aggiunto il codice della macro corretta ([[delete_l2_fix.sql|queries/delete_l2_fix.sql]]) come seguito di [[bug-delete_l2-primo-run]]: unica modifica il guard `{% if is_incremental() %}` attorno al DELETE, nessun cambio lato chiamante.
