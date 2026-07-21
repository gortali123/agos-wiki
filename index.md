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

## Sources

- [Caricamento layer L0-L1](sources/caricamento-layer-l0-l1.md)
- [Caricamento layer L2](sources/caricamento-layer-l2.md)
- [Guida Sviluppo](sources/guida-sviluppo.md)
- [Agos X - Layer L2.xlsx (reference)](sources/layer-l2-xlsx-reference.md) — non ingerito foglio per foglio, solo struttura
- [CFG_L1_SCHEMA e CFG_L1_CLUSTER_STO](sources/cfg-l1-schema-e-cluster-sto.md) — export tabelle tecniche, non ingerito riga per riga, solo struttura/statistiche

## Queries

- [Inconsistenze: codice vs skill vs documentazione](queries/inconsistenze.md) — tabella riassuntiva (solo voci aperte) + 10 voci di dettaglio
- [NULL vs placeholder OCS (' ') in L2/L3](queries/null-vs-placeholder-ocs.md) — interventi da guida sviluppo: custom_is_null()/NULLIF, inventario completo

## Develop

- [variazioni_anagrafiche](develop/models/L2/ANAGR_CONTROPARTE/variazioni_anagrafiche.sql) — fix logica "primo record" (ROW_NUMBER su delta incrementale invece che su storia completa), proposto, non ancora portato upstream
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
- [log_run_results](develop/macros/log/log_run_results.sql) — fix macro logging (nm_execution_time con default(0) per evitare JSON invalido sugli SKIPPED), proposto
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
