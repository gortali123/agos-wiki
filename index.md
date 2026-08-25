# Index

## Entities

- [Repo dwh-x-dbt](entities/repo-dwh-x-dbt.md) — progetto DBT unico, struttura reale vendorizzata
- [Layer L0](entities/layer-l0.md)
- [Layer L1](entities/layer-l1.md)
- [Layer L2](entities/layer-l2.md)
- [Layer L3](entities/layer-l3.md)
- [L2 ANAGR_CONTROPARTE](entities/l2-anagr-controparte.md) — area più documentata, VARIAZIONI_ANAGRAFICHE
- [L2 ANTIFRODE](entities/l2-antifrode.md)
- [L2 ASSICURAZIONI](entities/l2-assicurazioni.md)
- [L2 CARTE](entities/l2-carte.md) — query_tag schema mismatch sistematico
- [L2 GESTIONE_CREDITI](entities/l2-gestione-crediti.md)
- [L2 ONBOARDING](entities/l2-onboarding.md) — tutti i modelli S1 usano is_incremental_S1
- [L2 PRODOTTO](entities/l2-prodotto.md)
- [L2 PRODOTTO_M](entities/l2-prodotto-m.md)
- [L2 PROVVIGIONI_RAPPEL](entities/l2-provvigioni-rappel.md) — query_tag disattivato/errato
- [L2 RISCHI_ADEMPIMENTI](entities/l2-rischi-adempimenti.md)
- [L2 SALDI](entities/l2-saldi.md)
- [L2 SWORD](entities/l2-sword.md) — unico a leggere da XML

## Concepts

- [Catalogo macro DBT](concepts/macro-catalogo-dbt.md) — inventario completo macro raw/dwh-code/macros
- [Storicizzazione L1: cluster A/B/C](concepts/storicizzazione-l1-cluster-a-b-c.md)
- [Storicizzazione L2: pattern S1-S4](concepts/storicizzazione-l2-s1-s4.md)
- [Storicizzazione L3: S2-S4 e S5](concepts/storicizzazione-l3.md)
- [Cancellazioni logiche e FL_DELETED](concepts/cancellazioni-fl-deleted.md)
- [Naming convention Agos X](concepts/naming-convention-agos-x.md) — schemi/tabelle/campi, divergenze tra fonti
- [PROGRESSIVO_PK e PROGRESSIVO_CONTROPARTE](concepts/progressivo-pk-e-progressivo-controparte.md)
- [Data masking Agos X](concepts/data-masking-agos-x.md)
- [Parsing COBOL](concepts/cobol-parsing.md)
- [query_tag per monitoring](concepts/query-tag-monitoring.md) — copertura reale incompleta/errata nel codice
- [LASTMODIFIEDDATA](concepts/lastmodifieddata.md) — ruoli: ordine colonne, filtro incrementale, cancellazioni
- [Data Quality Framework (proposta)](concepts/data-quality-framework.md) — test dbt generati dinamicamente da tabella di config via Jinja negli schema.yml; primo pilota (check email) in develop/

## Sources

- [Caricamento layer L0-L1](sources/caricamento-layer-l0-l1.md)
- [Caricamento layer L2](sources/caricamento-layer-l2.md)
- [Guida Sviluppo](sources/guida-sviluppo.md)
- [Agos X - Layer L2.xlsx (reference)](sources/layer-l2-xlsx-reference.md) — non ingerito foglio per foglio, solo struttura
- [CFG_L1_SCHEMA e CFG_L1_CLUSTER_STO](sources/cfg-l1-schema-e-cluster-sto.md) — export tabelle tecniche, non ingerito riga per riga, solo struttura/statistiche

## Queries

- [Inconsistenze: codice vs skill vs documentazione](queries/inconsistenze.md) — ricostruita da zero 2026-08-19, 8 incongruenze attive verificate contro il codice corrente (query_tag CARTE/L3, gap/anomalie delete_l2, naming macro, sentinella TIMESTAMP/DATE, 2 bug applicativi, log L2 non allineato); voci S/N, ID_/SK_ vs PR_ e sigle subject area rimosse (dipendevano dalla xlsx ora cancellata da raw/)
- [NULL vs placeholder OCS (' ') in L2/L3](queries/null-vs-placeholder-ocs.md) — interventi da guida sviluppo: custom_is_null()/NULLIF, inventario completo
- [Proposta testo: L0-L1 - Normalizzazione VARCHAR vuoti OCS](queries/proposta-testo-varchar-vuoti-l0-l1.md) — trim + normalizzazione a `' '` in L1
- [Proposta testo: L2 - Placeholder OCS VARCHAR/NUMBER](queries/proposta-testo-null-placeholder-l2.md) — custom_is_null/NULLIF(' ') e nuovo caso NUMBER=0/NULLIF(0)
- [Proposta testo: L2 - Placeholder $$$$ su JOIN non-PK](queries/proposta-testo-placeholder-dollari-l2.md) — obsoletizzazione campi anagrafici, esempio legame_ditte_individuali
- [Proposta testo: L0-L1 - Cluster D mensile/settimanale](queries/proposta-testo-mensili-l0-l1.md) — get_dt_osservazione/compute_dt_osservazione/delete_dt_osservazione
- [Proposta testo: L2 - S3 mensile/settimanale](queries/proposta-testo-mensili-l2-l3.md) — stesse 3 macro lato L2

## Develop

- [variazioni_anagrafiche](develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql) — riconfermata struttura S1 classica (macro `is_incremental_S1`, no split ramo1/ramo2, `BASE` rilegge tutta la storia da `ccanalog` a ogni run) con `AL_DATA_INSERIMENTO` come `TS_INIZIO_VALIDITA` solo per il vero primo record storico e `PR_CONTROPARTE` come semplice `ROW_NUMBER()` (nessun `OLD_PROGRESSIVO`); proposto, non ancora portato upstream
- [variazioni_anagrafiche_day](develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche_day.sql) — stessa conversione a S1 classica: nessuna union con la riga aperta nel target, `COMBINED`/`DAY` rileggono tutta la storia da `variazioni_anagrafiche` a ogni run, filtro incrementale (manuale, non `is_incremental_S1` perché qui non c'e' `HASHED_COLS`) replica lo stesso criterio LASTMODIFIEDDATA/boundary; proposto, non ancora portato upstream
- [dm_ca_campioni](develop/models/L3/campioni_accettazione/dm_ca_campioni.sql) — DM_CA_CAMPIONI, proposto, non ancora portato upstream
- [dm_co_campioni](develop/models/L3/campioni_accettazione/dm_co_campioni.sql) — DM_CO_CAMPIONI, proposto, non ancora portato upstream
- [dm_ca_imp_rata](develop/models/L3/campioni_accettazione/dm_ca_imp_rata.sql) — DM_CA_IMP_RATA, proposto, non ancora portato upstream
- [dm_ca_matrix_inat](develop/models/L3/campioni_accettazione/dm_ca_matrix_inat.sql) — DM_CA_MATRIX_INAT, proposto, non ancora portato upstream
- [dm_ca_tab_blocchi](develop/models/L3/campioni_accettazione/dm_ca_tab_blocchi.sql) — DM_CA_TAB_BLOCCHI, proposto, non ancora portato upstream
- [dm_ca_matrix_utlz](develop/models/L3/campioni_accettazione/dm_ca_matrix_utlz.sql) — DM_CA_MATRIX_UTLZ, proposto, non ancora portato upstream
- [dm_ca_mod_ripagamento](develop/models/L3/campioni_accettazione/dm_ca_mod_ripagamento.sql) — DM_CA_MOD_RIPAGAMENTO, proposto, non ancora portato upstream
- [dm_ca_matrix](develop/models/L3/campioni_accettazione/dm_ca_matrix.sql) — DM_CA_MATRIX, proposto, non ancora portato upstream
- [dm_ca_target](develop/models/L3/campioni_accettazione/dm_ca_target.sql) — DM_CA_TARGET, proposto, non ancora portato upstream
- [dm_co_target](develop/models/L3/campioni_accettazione/dm_co_target.sql) — DM_CO_TARGET, proposto, non ancora portato upstream
- [dm_co_matrix](develop/models/L3/campioni_accettazione/dm_co_matrix.sql) — DM_CO_MATRIX, proposto, non ancora portato upstream
- [v_event_log](develop/views/logs/v_event_log.sql) — vista LOGS.V_EVENT_LOG corretta (rimosso filtro che nascondeva gli SKIPPED, timestamp con fallback), proposta
- [v_last_run_status](develop/views/logs/v_last_run_status.sql) — vista di monitoring ultimo stato model/test per tabella, proposta
- ~~log_run_results~~ — **applicato upstream nel resync 2026-08-03**: `raw/dwh-code/macros/log/log_run_results.sql` usa ora `default(x, true)` su `nm_execution_time`/`nm_failures`, coerente col fix proposto
- [appuntamento](develop/models/L2/MAIN/appuntamento.sql) — APPUNTAMENTO (CONTATTI), proposto — PK e 4 RT con gap gravi nel data model, vedi WARN inline
- [contatto_ngs](develop/models/L2/MAIN/contatto_ngs.sql) — CONTATTO_NGS (CONTATTI), proposto
- [preventivi](develop/models/L2/MAIN/preventivi.sql) — PREVENTIVI (CONTATTI), proposto
- [survey_input](develop/models/L2/VOC/survey_input.sql) — SURVEY_INPUT (CONTATTI/VOC), proposto
- [survey_output](develop/models/L2/VOC/survey_output.sql) — SURVEY_OUTPUT (CONTATTI/VOC), proposto
- [recensioni](develop/models/L2/VOC/recensioni.sql) — RECENSIONI (CONTATTI/VOC), proposto
- [ana_versioni_form](develop/models/L2/FORM_E_PREVENTIVATORI/ana_versioni_form.sql) — ANA_VERSIONI_FORM (DIGITAL), proposto
- [form](develop/models/L2/FORM_E_PREVENTIVATORI/form.sql) — FORM (DIGITAL), proposto
- [ana_campagne_tig](develop/models/L2/FORM_E_PREVENTIVATORI/ana_campagne_tig.sql) — ANA_CAMPAGNE_TIG (DIGITAL), proposto
- [riconoscimento](develop/models/L2/TRACCIATURA_DIGITAL/riconoscimento.sql) — RICONOSCIMENTO (DIGITAL), proposto
- [accessi](develop/models/L2/AREA_RISERVATA/accessi.sql) — ACCESSI (DIGITAL), proposto
- [iscritti](develop/models/L2/AREA_RISERVATA/iscritti.sql) — ISCRITTI (DIGITAL), proposto
- [abilitazioni_push](develop/models/L2/AREA_RISERVATA/abilitazioni_push.sql) — ABILITAZIONI_PUSH (DIGITAL), proposto
- [sessioni](develop/models/L2/FORM_E_PREVENTIVATORI/sessioni.sql) — SESSIONI (DIGITAL), proposto, recuperata dopo fix bug dm-reader
- [ana_iniziative_commerciali](develop/models/L2/FORM_E_PREVENTIVATORI/ana_iniziative_commerciali.sql) — ANA_INIZIATIVE_COMMERCIALI (DIGITAL), proposto, ricostruita da uno shift di colonna nello sheet
- [contact_history](develop/models/L2/MAIN/contact_history.sql) — CONTACT_HISTORY (CONTATTI), proposto, recuperata dopo secondo fix bug dm-reader (blocco MODULO)
- ~~ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI query_tag fixes~~ — **applicati upstream nel resync 2026-07-24**, file rimossi da `develop/` (vedi [[inconsistenze]] voce 1)
- [carte_autorizzativo (query_tag)](develop/models/L2/CARTE/carte_autorizzativo.yml) — fix query_tag, proposto, non ancora portato upstream
- [carte_blocchi (query_tag)](develop/models/L2/CARTE/carte_blocchi.yml) — fix query_tag, proposto, non ancora portato upstream
- [carte_estratto_conto_m (query_tag)](develop/models/L2/CARTE/carte_estratto_conto_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [carte_limitazioni_operativita (query_tag)](develop/models/L2/CARTE/carte_limitazioni_operativita.yml) — fix query_tag, proposto, non ancora portato upstream
- [carte_mov_estratto_conto_m (query_tag)](develop/models/L2/CARTE/carte_mov_estratto_conto_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [carte_utilizzi (query_tag)](develop/models/L2/CARTE/carte_utilizzi.yml) — fix query_tag, proposto, non ancora portato upstream
- ~~GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, RISCHI_ADEMPIMENTI (indice_rischio_m), SCORE_BANCHE_DATI, SWORD query_tag fixes~~ — **applicati upstream nel resync 2026-07-24**, file rimossi da `develop/` (vedi [[inconsistenze]] voce 1)
- [dm_basilea_ca_var_pv_k_m (query_tag)](develop/models/L3/basilea_core/dm_basilea_ca_var_pv_k_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_basilea_co_var_pv_k_m (query_tag)](develop/models/L3/basilea_core/dm_basilea_co_var_pv_k_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_controlli_basilea_m (query_tag)](develop/models/L3/basilea_core/dm_controlli_basilea_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_dim_produz_pratiche (query_tag)](develop/models/L3/monitoraggio_produzione/dm_dim_produz_pratiche.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_dim_produz_pratiche_m (query_tag)](develop/models/L3/monitoraggio_produzione/dm_dim_produz_pratiche_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_dim_produz_utilizzi_carte (query_tag)](develop/models/L3/monitoraggio_produzione/dm_dim_produz_utilizzi_carte.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_dim_produz_utilizzi_carte_m (query_tag)](develop/models/L3/monitoraggio_produzione/dm_dim_produz_utilizzi_carte_m.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_mov_produzione (query_tag)](develop/models/L3/monitoraggio_produzione/dm_mov_produzione.yml) — fix query_tag, proposto, non ancora portato upstream
- [dm_mov_produzione_m (query_tag)](develop/models/L3/monitoraggio_produzione/dm_mov_produzione_m.yml) — fix query_tag, proposto, non ancora portato upstream
- ~~generate_source/generate_yaml/generate_model/generate_snapshots (join CFG_L0_L1_MODULO_LOOKUP), generate_jobs (modulo=sottofolder)~~ — **applicati upstream nel resync 2026-07-24**, byte-identici al proposto in `develop/` — **ATTENZIONE**: quella versione ha l'ordine soprafolder/sottofolder invertito, vedi voce sotto
- ~~generate_source/generate_yaml/generate_model/generate_snapshots (fix join + path)~~ — **applicato upstream nel resync 2026-08-03**: `raw/dwh-code/macros/generate_models/generate_source.sql` ha ora il join corretto `mlk.cd_modulo = s.cd_modulo` e il path a due livelli `<cd_modulo_l1>/<cd_modulo>`, coerente col fix proposto in `develop/`; anche la docx [[caricamento-layer-l0-l1]] documenta ora questo meccanismo
- ~~generate_models (Resolve-Mod per segmento)~~ — **applicato upstream**: `raw/dwh-code/generate_models.ps1` ha già lo split su `/` con `Resolve-Mod` per segmento
- [generate_models](develop/generate_models.ps1) — `Invoke-Dbt` si fidava solo di `$LASTEXITCODE`: `dbt run-operation` può stampare `Compilation Error`/`Database Error` nell'output e comunque uscire con exit code 0, quindi lo script proseguiva silenziosamente sugli step successivi invece di fermarsi; fix: scan dell'output per marker di errore, trattati come fallimento anche a exit code 0, proposto
- [plan-jobs](develop/plan-jobs.ps1) — output di `dbt-jobs-as-code.exe plan` ora scritto anche su file di default `plan_output.txt` (oltre a stdout), proposto
- [custom_to_date](develop/macros/dtype_conversion/custom_to_date.sql) — fix variabile non definita `col_str` nel messaggio d'errore (era `column`), proposto
- [delete_month](develop/macros/materialization/delete_month.sql) — fix parametro `column` ignorato nella DELETE (hardcoded `DT_OSSERVAZIONE`), proposto
- [get_dt_accettazione](develop/macros/materialization/get_dt_accettazione.sql) — nuova macro, analoga a `get_dt_osservazione` ma su base settimanale (venerdì precedente invece di fine mese precedente), proposta
- [delete_week](develop/macros/materialization/delete_week.sql) — nuova macro, analoga a `delete_month` ma su `DT_ACCETTAZIONE`/`get_dt_accettazione()`, proposta
- [generate_schema_name](develop/macros/generate_schema_name.sql) — versione strict: raise_compiler_error se un modello non ha `schema:` custom, invece del fallback silenzioso su `target.schema`, proposta
- [mailc_esiti_tgb (POSTE)](develop/models/L1/POSTE/mailc_esiti_tgb.yml) — MAILC_ESITI_TGB riclassificato da cluster C (ephemeral+snapshot) a cluster D (incremental append + `delete_week`), rinominato da `stg_mailc_esiti_tgb`, SELECT filtrato sullo stesso `get_dt_accettazione()` cancellato dal pre_hook; proposto, snapshot/stg vecchi da rimuovere upstream
- [generate_model (fix filtro cluster D mensile)](develop/macros/generate_models/generate_model.sql) — aggiunge `WHERE get_dt_osservazione('ts_riferimento') = get_dt_osservazione()` al SELECT generato per cluster D, per allineare sempre delete e insert sullo stesso periodo target; solo mensile (nessun campo di cadenza in `TECH.CFG_L1_CLUSTER_STO`, `mailc_esiti_tgb` settimanale resta manuale), proposto
- ~~try_cast / try_cast_from_sql / try_cast_positional / primary_key / primary_key_positional (no where_clause)~~ — **applicato upstream nel resync 2026-08-03**: confermato nessun parametro `where_clause` in `raw/dwh-code/tests/generic/try_cast.sql` e `primary_key.sql`, coerente col fix proposto
- [primary_key_from_sql (nuovo test)](develop/tests/generic/primary_key_from_sql.sql) — analogo a `try_cast_from_sql` ma per PK: `null_pks`/`duplicate_pks` invariate (agiscono sui valori grezzi), `cast_failed_pks` riusa il parsing del `raw_code` L1 per testare l'espressione di cast reale della/e colonna/e PK invece di un `TRY_CAST(col AS tipo_dichiarato)` ricostruito a mano; `where_clause` auto-rilevato dal `raw_code` L1 (stesso meccanismo di `try_cast_from_sql`), nessun parametro. Da usare al posto di `primary_key` quando una o più `pk_columns` hanno logica di cast particolare (es. `TRY_TO_DATE` con formato custom), proposto
- [is_valid_email (nuovo test)](develop/tests/generic/is_valid_email.sql) — pilota [[data-quality-framework]]: generic test custom formato email (`regexp_like`), proposto
- [anagrafica_controparte (dq test dinamici)](develop/models/L2/ANAGR_CONTROPARTE/anagrafica_controparte.yml) — schema.yml completo con generazione dinamica generica del blocco `tests:` per colonna da `cfg.dq_test_config`, pilota `DS_EMAIL`/`is_valid_email`, proposto
- [dq_test_config (setup)](develop/setup/dq_test_config.sql) — `CREATE TABLE cfg.dq_test_config` + riga pilota `DS_EMAIL`/`is_valid_email`, proposto
