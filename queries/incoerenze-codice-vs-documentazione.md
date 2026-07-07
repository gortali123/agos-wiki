---
title: Incoerenze tra codice reale (dwh-code) e documentazione
type: query
tags: [lint, incoerenze, dwh-code]
updated: 2026-07-07
---

Verifica incrociata tra i documenti di framework/guida sviluppo e il codice reale sincronizzato in [[dwh-code]] (macros, `dbt_project.yml`, modelli L2 campione, sample L1/snapshot). A differenza di [[incoerenze-doc-framework-vs-guida-sviluppo]] (doc vs doc), qui il confronto è **doc vs codice effettivo**, quindi ha priorità quando i due sono in conflitto: il codice è la sorgente di verità.

## 1. Raccolta log: dbt Artifacts (documentato) vs stored procedure custom (reale) — rilevanza alta

Entrambi i documenti di framework descrivono la raccolta log tramite il **pacchetto dbt Artifacts** (`{{ dbt_artifacts.upload_results(results) }}`), con tabelle `MODELS`/`TESTS`/`SNAPSHOTS`/`MODEL_EXECUTIONS`/`TEST_EXECUTIONS`/`SNAPSHOT_EXECUTIONS` e viste `V_L1_DBT_RUN_MODELS`/`V_L2_DBT_RUN_MODELS` ecc.

Il `dbt_project.yml` reale ha invece:
```yaml
on-run-end:
  - "{{ log_run_results(results) }}"
  - "{{ pop_test_log_records(results) }}"
```
Non c'è alcun `packages.yml` nel repo (quindi dbt Artifacts non risulta nemmeno installato), e `macros/log/log_run_results.sql` è una macro **custom** che costruisce un JSON dai `results` dell'invocazione e lo passa a una stored procedure `AGOS_DEV_16000.TECH.LOG_DBT(PARSE_JSON(...))`. Il meccanismo di logging reale è quindi completamente diverso da quello descritto nei documenti ufficiali: niente pacchetto esterno, niente tabelle `MODELS`/`TESTS`/ecc, ma una singola stored procedure alimentata da JSON costruito in Jinja.

**Implicazione pratica**: le viste `V_L1_DBT_RUN_MODELS`, `V_L1_TEST`, `V_L1_TEST_RESULTS`, `V_L2_DBT_RUN_MODELS`, `V_L2_TEST`, `V_L2_TEST_RESULTS` descritte nei doc ufficiali potrebbero non esistere più, o essere costruite su una sorgente dati diversa da quella descritta. Da verificare con chi gestisce `TECH.LOG_DBT` prima di fidarsi della sezione "Raccolta dei log" di [[agosx-caricamento-l0-l1]] / [[agosx-caricamento-l2]].

## 2. `TECH.CFG_L1_SCHEMA`: nomi colonna reali diversi da quelli documentati — rilevanza alta

Il documento ufficiale L0-L1 descrive la tabella con colonne `NM_CAMPO`, `DS_MODULO`, `DS_TABELLA`, `DS_CAMPO`, `DS_FORMATO`, `NM_LUNGHEZZA`, `FL_PK`, `FL_NULL`, `TS_INSERIMENTO` (con un refuso interno già segnalato: il testo esplicativo usa anche `DT_INSERIMENTO`).

La macro reale `macros/generate_models/generate_source.sql` interroga `AGOS_DEV_16000.TECH.CFG_L1_SCHEMA` con colonne: `ds_archivio`, `cd_modulo`, `ds_sorgente`, `ds_column_name`, `ds_data_type`, `ds_length_col`, `fl_is_nullable`, `fl_is_primary_key`, `ts_riferimento`, `nm_campo`. Nessuno di questi nomi coincide esattamente con quelli del documento ufficiale (`DS_TABELLA`→`DS_ARCHIVIO`, `DS_MODULO`→`CD_MODULO`, `DS_CAMPO`→`DS_COLUMN_NAME`, `DS_FORMATO`→`DS_DATA_TYPE`, `NM_LUNGHEZZA`→`DS_LENGTH_COL`, `FL_PK`→`FL_IS_PRIMARY_KEY`, `FL_NULL`→`FL_IS_NULLABLE`, `TS_INSERIMENTO`→`TS_RIFERIMENTO`), e c'è anche una colonna reale (`ds_sorgente`) mai menzionata nel documento. La pagina [[cfg-l1-schema]] documenta lo schema "ufficiale" — va corretta o quantomeno segnalata come divergente dal reale.

## 3. Severity di `primary_key_table`: non risulta impostata a "fail" nel generatore — rilevanza alta (da verificare)

Il documento ufficiale afferma che `primary_key_table` ha severity **fail** (blocca il caricamento in L1) mentre `try_cast_table` è **warn**. Il progetto imposta però un default globale `tests: +severity: warn` in `dbt_project.yml`, e la macro `generate_source.sql` che genera i blocchi `data_tests` nello yml delle source **non scrive mai una chiave `severity`** per nessuno dei due test (né per `try_cast_table` né per `primary_key_table`) — solo `arguments` (`pk_columns`, `rtrim_varchar`). Se non c'è un override altrove (es. nella definizione del test generico stesso, non ispezionata in questa sessione), `primary_key_table` erediterebbe il default di progetto `warn`, **contraddicendo** il comportamento "fail" descritto nella documentazione. Da verificare leggendo la definizione del test generico `primary_key_table` (probabilmente in `tests/generic/`) prima di considerare questo un bug confermato.

## 4. Aree funzionali L2: elenco codice diverso dall'elenco documentato, e un caso di schema disallineato dalla cartella — rilevanza alta

Il documento ufficiale L2 elenca 16 aree funzionali (vedi [[naming-conventions]]). Le cartelle realmente presenti in `models/L2/` (e in `dbt_project.yml`) sono invece: `ANAGR_CONTROPARTE`, `ANTIFRODE`, `ASSICURAZIONI`, `CARTE`, `ONBOARDING`, `PRODOTTO`, `PRODOTTO_M`, `RISCHI_ADEMPIMENTI`, `SALDI`, `SWORD`, `GESTIONE_CREDITI`.

- **`CARTE`, `SALDI`, `SWORD`** sono cartelle/subject area reali **non presenti** nell'elenco ufficiale delle aree funzionali.
- Aree elencate nel documento ma **assenti dal codice** (probabilmente non ancora sviluppate): `ANAGR_COMMERCIALE`, `ANTIRICICLAGGIO`, `BUDGET`, `CONTATTI`, `DIGITAL`, `HR`, `PAGAMENTI_CONTABILITA`, `PROVVIGIONI_RAPPEL`, `SCORE_BANCHE_DATI`.
- **Caso concreto di violazione della naming convention**: la cartella/subject-area `CARTE` è mappata allo schema Snowflake **`L2_PRODOTTO`** (`+schema: L2_PRODOTTO` nel `dbt_project.yml`, sotto la chiave `CARTE`), non `L2_CARTE`. La regola dichiarata è "schema = `L2_<area_funzionale>`" — qui l'area funzionale della cartella (CARTE) e lo schema effettivo (L2_PRODOTTO) non corrispondono. Va chiarito se è intenzionale (CARTE è un sotto-dominio di PRODOTTO) o un refuso di configurazione.

## 5. Naming schemi L1 per sorgente esterna (E) vs OCS (O): pattern non documentato in nessun doc

Il `dbt_project.yml` usa sistematicamente `L1_E_<CODICE>` per le sorgenti esterne non-OCS (es. `L1_E_ADB` per ADOBE, `L1_E_SAP` per SAP, `L1_E_SWD` per SWORD, `L1_E_XER` per XEROX...) e `L1_O_<MODULO>` per i moduli OCS (es. `L1_O_ANA`, `L1_O_AIN`...). Questo schema di naming (`E`=esterno/non-OCS, `O`=OCS) **non è menzionato in nessuno dei tre documenti letti** — è un pattern reale utile da aggiungere in [[naming-conventions]], non necessariamente una "incoerenza" ma un gap documentale.

## 6. Campo tecnico snapshot: `ts_update_at` (doc) vs `ts_updated_at` (codice) — rilevanza bassa

Il documento ufficiale L0-L1 elenca il campo tecnico SCD2 come `ts_update_at`. Il mapping reale in `dbt_project.yml` (`snapshot_meta_column_names.dbt_updated_at`) lo chiama **`ts_updated_at`**. Probabile refuso nel documento (manca la "d"), ma è il nome di una colonna reale — se qualcuno scrive query basandosi sul documento otterrebbe un errore di colonna inesistente.

## 7. `PROGRESSIVO_PK` e `PROGRESSIVO_CONTROPARTE`: logica reale più ricca di quanto descritto — rilevanza media

Nel modello reale `variazioni_anagrafiche.sql`:
- `PROGRESSIVO_PK` è calcolato con `ROW_NUMBER() OVER (PARTITION BY AL_CODICE, AL_DATA_MODIFICA, AL_ORA_MODIFICA ORDER BY ROWID)`, cioè partizionato su **chiave + timestamp di modifica**, non sulla sola chiave come suggerisce la sintesi del documento ufficiale ("si partiziona l'entità sorgente considerando i campi chiave").
- `PROGRESSIVO_CONTROPARTE` in run incrementale usa una logica con `COALESCE` tra un valore già esistente (`EX.PROGRESSIVO_CONTROPARTE`, da una CTE non mostrata nella porzione letta) e un nuovo progressivo calcolato a partire dal massimo esistente (`MX.MAX_PROGRESSIVO_CONTROPARTE`) — molto più elaborata della descrizione "partizionata per `AL_CODICE`, progressivo su `ROWID`" del documento ufficiale, che sembra descrivere solo il caso full-refresh.

Non è un errore, ma la sintesi del framework doc **sottostima la complessità reale** dell'implementazione incrementale — utile saperlo prima di usare la sola descrizione testuale per replicare la logica altrove.

## 8. Conferme (il codice valida la documentazione, non solo la contraddice)

Per onestà, molte parti sono state **confermate** dal codice, in particolare quelle della [[guida-sviluppo]]:
- La macro `scd2_foto_mensile.sql` (S5, L3) corrisponde quasi letteralmente all'esempio numerico descritto nella guida sviluppo (stesse CTE `snap`/`open_win`/`new_rows`/`close_rows` per il ramo incrementale, `ver_dedup`/`win_starts`/`emitted` per il full-refresh).
- `is_incremental_S1.sql` conferma il meccanismo di dedup S1 basato su `HASHED_COLS` + `LAG` descritto nella guida.
- `delete_l2.sql` conferma il pattern di pre-hook descritto nella guida (stessa firma `delete_l2(source_name, tgt_keys, src_keys)`), e usa correttamente `FL_DELETED` (non `FL_DELETE`) — conferma che il refuso nel documento L2 era solo un refuso.
- `dbt_project.yml` conferma `+contract.enforced: true` e `on_schema_change: append_new_columns` project-wide come descritto.

## Nota di scope

Verifica basata su un campione: `dbt_project.yml`, macro principali (`add_datamask`, `delete_l2`, `logic_delete_merge/scd2`, `delete_month`, `hash_cols`, `is_incremental_S1`, `scd2_foto_mensile`, `ts_fine_validita`, `log_run_results`, `pop_test_log_records`, `generate_source`), un modello L2 (`variazioni_anagrafiche`), un modello L1 (`aictfpdp`) e uno snapshot (`aitbfatt`). Non sono stati letti: `generate_yaml.sql`, `generate_model.sql`, `generate_snapshots.sql`, `transcod_dtype.sql`, macro `cobol.sql`/`xml_to_data.sql`, i test generici in `tests/generic/` (in particolare le definizioni di `try_cast_table` e `primary_key_table`, che risolverebbero il punto 3), né altri modelli L2/L3. Ulteriori incoerenze possono emergere da un'ispezione più ampia.

## Collegato da
[[agosx-caricamento-l0-l1]], [[agosx-caricamento-l2]], [[guida-sviluppo]], [[cfg-l1-schema]], [[naming-conventions]], [[incoerenze-doc-framework-vs-guida-sviluppo]]
