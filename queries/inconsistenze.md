---
title: "Inconsistenze: codice vs skill vs documentazione (dwh-x-dbt)"
type: query
tags: [inconsistenze, layer/L0, layer/L1, layer/L2, layer/L3, naming-convention]
updated: 2026-08-19
---

Ricostruita **da zero** il 2026-08-19 (non un incremento della versione precedente): ogni riga qui sotto è stata riverificata leggendo direttamente i file correnti in `raw/dwh-code/` e il contenuto attuale delle tre docx ([[caricamento-layer-l0-l1]], [[caricamento-layer-l2]], [[guida-sviluppo]]). Nessuna riga è stata portata avanti "per fiducia" dal giro precedente.

**Nota sui file rimossi da `raw/`**: `Agos X - Layer L2.xlsx` e i due export csv (`cfg_l1_schema.csv`, `cfg_l1_cluster_sto.csv`) sono stati cancellati dall'utente. Tutte le vecchie voci che dipendevano **solo** da quei file come lato "Doc" (flag S/N vs Y/N, prefissi `ID_`/`SK_` vs `PR_`, tassonomia sigle subject area) non sono più verificabili e sono state rimosse dalla tabella attiva — vedi sezione "Voci non più verificabili" in fondo.

## Tabella

| #   | Titolo                                                                                       | Codice                                                                        | Skill | Doc                                                     |
| --- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | ----- | -------------------------------------------------------- |
| 1   | `query_tag` L2/L3: obbligatorio da doc, ancora assente/errato in 18 file                       | ⚠️ CARTE (schema errato, 6 file) + basilea_core/monitoraggio_produzione/CAMPIONI (assente, 12 file) | —     | ✅ prescrive obbligo                                       |
| 2   | Cancellazioni L2: standard `pre_hook delete_l2` + filtro `FL_DELETED`, 6 modelli disallineati  | ⚠️ gap reale confermato                                                        | —     | ✅ prescrive il pattern come standard                      |
| 3   | Anomalia inversa: `pre_hook delete_l2` presente ma nessun filtro `FL_DELETED` nel SELECT       | ⚠️ 2 modelli confermati                                                        | —     | —                                                          |
| 4   | Macro documentate con nome diverso da quello reale (`remove_datamask`, `logical_delete_*`)     | ⚠️ nomi reali diversi                                                          | —     | ⚠️ nomi non corrispondenti                                 |
| 5   | Sentinella "finestra aperta": TIMESTAMP in L2/S1, DATE in L3/S5                                | ⚠️ due tipi diversi                                                            | —     | ⚠️ non documentato come intenzionale                       |
| 6   | `passaggi_a_perdita.sql`: `NULLIF` senza effetto per bug di sintassi (righe 8, 32)              | ⚠️ bug reale                                                                   | —     | —                                                          |
| 7   | `carte_utilizzi.sql:148`: condizione booleana rotta su placeholder NUMBER OCS (`FL_CONTRIBUTI_PROMO`) | ⚠️ bug reale                                                             | —     | ⚠️ sez. 5.5 guida-sviluppo copre solo VARCHAR, non NUMBER  |
| 8   | Log L2/L3: docx `caricamento-layer-l2` descrive ancora `dbt_artifacts`/`DBT_ARTIFACTS.MODELS`, il codice usa `log_run_results`/`LOGS.EVENT_LOG` | ✅ `log_run_results`/`LOGS.EVENT_LOG` confermato | —     | ⚠️ sezione L2 "Raccolta dei log" non aggiornata (a differenza della L0-L1, già corretta) |

Legenda: ✅ = coerente/conferma la riga; ⚠️ = incongruenza/gap rilevato; — = fonte non coinvolta in questa voce.

## Dettaglio

### 1. `query_tag` L2/L3: obbligatorio, ancora assente/errato in 18 file

- **Doc**: [[guida-sviluppo]] lo rende obbligatorio in checklist pre-rilascio; [[caricamento-layer-l0-l1]]/[[caricamento-layer-l2]] lo richiedono per il monitoring dettagliato delle query, con formato JSON specifico.
- **Verificato 2026-08-19**: tutti e 6 i modelli `raw/dwh-code/models/L2/CARTE/*.yml` (`carte_autorizzativo`, `carte_blocchi`, `carte_estratto_conto_m`, `carte_limitazioni_operativita`, `carte_mov_estratto_conto_m`, `carte_utilizzi`) hanno `query_tag` con `"schema": "L2_PRODOTTO"` invece di `"L2_CARTE"`.
- Nessun file `.yml` in `raw/dwh-code/models/L3/basilea_core/` (3 file), `models/L3/monitoraggio_produzione/` (6 file, incluso `dm_config_running_o.yml` non ancora segnalato prima) e `models/L3/CAMPIONI/` (3 file) contiene la stringa `query_tag` — 12 file totali, confermato con grep diretto.
- **Impatto**: monitoring per-query su Snowflake inaffidabile per CARTE (schema sbagliato nei filtri) e per le tre aree L3 (tag assente del tutto).
- **Dettagli**: [[query-tag-monitoring]], [[l2-carte]].

### 2. Cancellazioni L2: gap reale sui 6 modelli senza `pre_hook delete_l2`

- **Standard**: `pre_hook delete_l2(...)` (DELETE fisica) + filtro `FL_DELETED` in lettura è il meccanismo prescritto da [[caricamento-layer-l2]]/[[guida-sviluppo]] per gli archivi con storicizzazione S1/S2 (non si applica per design a S3 append-mensile o S4 insert_overwrite, il cui pattern di ricostruzione gestisce già le cancellazioni implicitamente).
- **Verificato 2026-08-19** (grep diretto su `pre_hook`/`delete_l2` nei relativi `.yml`): confermata l'assenza del `pre_hook delete_l2` in tutti e 6:
  - `ANTIFRODE/archivio_tessere.sql`, `ANTIFRODE/gestione_truffe.sql`
  - `PAGAMENTI_CONTABILITA/pagamenti_vidaut.sql`
  - `PRODOTTO/tabelle_finanziarie.sql`, `PRODOTTO/variazioni_stato_prat.sql`
  - `PROVVIGIONI_RAPPEL/proforma_prv_rap.sql`
- **Impatto**: pratiche/eventi/pagamenti cancellati alla fonte possono restare visibili su query di business che non applicano un filtro esplicito a valle.
- **Dettagli**: [[cancellazioni-fl-deleted]], [[l2-antifrode]].

### 3. Anomalia inversa: `pre_hook delete_l2` presente ma nessun filtro `FL_DELETED` nel SELECT

- **Verificato 2026-08-19**: `ANAGR_CONTROPARTE/legame_ditte_individuali.yml` e `ANAGR_CONTROPARTE/variazioni_anagrafiche_day.yml` hanno entrambi `pre_hook: delete_l2(...)` ma i rispettivi `.sql` non contengono alcun riferimento a `FL_DELETED` (grep negativo). La pulizia fisica dei record cancellati avviene comunque tramite il pre_hook stesso; da confermare che il SELECT non possa comunque reintrodurre righe già cancellate tra un run e l'altro (finestra tra il pre_hook e la lettura della sorgente).
- `CARTE/carte_autorizzativo.yml` ha lo stesso pattern (`pre_hook delete_l2` su `craut`) — verificato con lo stesso metodo.
- **Impatto**: basso, rischio residuo solo nella finestra fra pre_hook e lettura, non un bug come la voce 2.
- **Dettagli**: [[cancellazioni-fl-deleted]], [[l2-anagr-controparte]].

### 4. Macro documentate con nome diverso da quello reale

- **`remove_datamask()`**: documentata in [[caricamento-layer-l2]] ("una seconda macro DBT, `remove_datamask()`, consente di rimuovere puntualmente un tag..."); grep su tutto `raw/dwh-code/` non trova alcuna occorrenza — esiste solo `add_datamask()` (`raw/dwh-code/macros/add_datamask.sql`). Vedi [[data-masking-agos-x]].
- **`logical_delete_merge()` / `logical_delete_scd2()`**: la docx [[caricamento-layer-l0-l1]] (capitolo "L1: Gestione cancellazioni OCS") li chiama così; nel codice i file/macro si chiamano `logic_delete_merge()` (`raw/dwh-code/macros/logic_delete/logic_delete_merge.sql`) e `logic_delete_scd2()` (`.../logic_delete_scd2.sql`) — senza "-al".
- **Non incluso come mismatch** (solo non verificabile): `decode_overpunch` è documentata come UDF Snowflake (`val`, `scale`) nel capitolo COBOL della docx L0-L1; non è vendorizzata in `raw/dwh-code/` (grep negativo su tutto il repo) — coerente con l'essere una UDF Snowflake-side, non un oggetto dbt. Non è un mismatch confermabile, solo fuori dallo snapshot.
- **Dettagli**: [[macro-catalogo-dbt]], [[data-masking-agos-x]], [[cancellazioni-fl-deleted]].

### 5. Sentinella "finestra aperta": TIMESTAMP in L2/S1, DATE in L3/S5

- Verificato riga per riga: `raw/dwh-code/macros/materialization/ts_fine_validita.sql` e `is_incremental_S1.sql` usano `TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')`.
- `raw/dwh-code/macros/materialization/scd2_foto_mensile.sql` usa `fine_validita_max="TO_DATE('9999-12-31')"` (DATE, non TIMESTAMP).
- Anche `chiudi_finestre_scd2_sword.sql` usa un terzo formato, `'9999-12-31 00:00:00'::TIMESTAMP_NTZ` (letterale castato, stesso valore/tipo di `ts_fine_validita` ma sintassi diversa — non è un'incongruenza di tipo, solo di stile).
- Non documentato in nessuna delle tre docx come differenza intenzionale tra L2 e L3.
- **Impatto**: basso ma rilevante per chi scrive JOIN cross-layer su condizioni di validità (confronto TIMESTAMP vs DATE).
- **Dettagli**: [[storicizzazione-l3]], [[macro-catalogo-dbt]].

### 6. `passaggi_a_perdita.sql`: `NULLIF` senza effetto per bug di sintassi

- **Verificato 2026-08-19**, ancora presente riga per riga: `raw/dwh-code/models/L2/GESTIONE_CREDITI/passaggi_a_perdita.sql` righe 8 e 32 — `COALESCE(nullif('B.TABTPP_CONCORDATA', ' '), 'N')`. Il nome colonna è passato come **stringa letterale tra apici singoli** invece che come identificatore SQL: il confronto `NULLIF` valuta sempre la costante `'B.TABTPP_CONCORDATA'` contro `' '` (mai uguali), quindi non ha mai effetto — l'espressione collassa sempre al primo argomento, mai al fallback `'N'`.
- **Impatto**: il placeholder OCS `' '` su questo campo non viene mai normalizzato, `FL_SALDI_STRALCIO` può risultare valorizzato in modo scorretto quando `B.TABTPP_CONCORDATA` è il placeholder.
- **Da fare**: rimuovere gli apici attorno all'identificatore colonna in entrambe le occorrenze.
- **Dettagli**: [[null-vs-placeholder-ocs]], [[l2-gestione-crediti]].

### 7. `carte_utilizzi.sql:148`: condizione booleana rotta su placeholder NUMBER OCS

- **Verificato 2026-08-19**: `raw/dwh-code/models/L2/CARTE/carte_utilizzi.sql:148` — `CASE WHEN (f.CRVOC_CONTR_DEALER <> 0 OR f.CRVOC_CONTR_DEALER IS NOT NULL) THEN 'S' ELSE 'N' END AS FL_CONTRIBUTI_PROMO`. La condizione `X <> 0 OR X IS NOT NULL` è vera per **qualunque** valore non-NULL di `X`, incluso `0` (perché `IS NOT NULL` è comunque vero quando `X = 0`) — quindi la clausola non discrimina mai il placeholder NUMBER OCS `0` come previsto dalla regola generale (`NULLIF(campo, 0)`), a differenza dei campi gemelli nello stesso file (`CRVOA_CONVENZIONATO`/`SUB_AGENTE`/`AGENTE`, righe 15-17/44-52/59-66) che usano correttamente `NULLIF(a.CRVOA_..., 0)`.
- **Nota**: il caso precedentemente sospettato su `CRVOA_NUMERO_ASSEGNO` (riga 109) risulta ora **corretto** — usa `{{ custom_is_not_null('a.CRVOA_NUMERO_ASSEGNO') }}` (macro VARCHAR OCS), coerente con un campo di tipo VARCHAR; non più un caso aperto.
- **Doc**: [[guida-sviluppo]] sez. 5.5/placeholder NUMBER tratta solo la regola generale (`NULLIF(campo, 0)`), non menziona questo caso specifico né la classe di bug "OR ridondante che vanifica il controllo".
- **Da fare**: sostituire con `NULLIF(f.CRVOC_CONTR_DEALER, 0) IS NOT NULL` (o equivalente).
- **Dettagli**: [[l2-carte]], [[null-vs-placeholder-ocs]].

### 8. Log L2/L3: docx non aggiornata rispetto al codice (a differenza della docx L0-L1)

- **Verificato 2026-08-19**: `raw/Agos X - Caricamento layer L2.docx` (capitolo finale "Raccolta dei log") descrive ancora il pacchetto **`dbt_artifacts`** (`dbt_artifacts.upload_results(results)` come hook `on-run-end`, tabelle `DBT_ARTIFACTS.MODELS/TESTS/SNAPSHOTS/*_EXECUTIONS`, viste `V_L2_DBT_RUN_MODELS`/`V_L2_TEST`/`V_L2_TEST_RESULTS`).
- Il codice reale (`raw/dwh-code/macros/log/log_run_results.sql`, richiamato da `dbt_project.yml` come `on-run-end`) scrive invece nella event table nativa `LOGS.EVENT_LOG` tramite la stored procedure `LOG_DBT` — stesso meccanismo già documentato correttamente in [[caricamento-layer-l0-l1]] (sezione "L1: raccolta log", riscritta 2026-08-03) con le viste `V_EVENT_LOG`/`DT_EVENT_LOG`/`V_LAST_RUN_STATUS`.
- Nessuna occorrenza di `dbt_artifacts` in `raw/dwh-code/` (grep negativo) — la sezione L2 del docx non ha ricevuto lo stesso aggiornamento della sezione L0-L1 equivalente, pur descrivendo lo stesso meccanismo di logging condiviso da tutto il progetto (un solo hook `on-run-end` in un unico `dbt_project.yml`, non ce n'è uno separato per L2).
- **Impatto**: chi legge solo la docx L2 troverebbe riferimenti a un pacchetto/tabelle mai esistite nel codice attuale; le viste `V_L2_*` descritte non sono state trovate in `raw/dwh-code/` (probabile DDL solo Snowflake-side, non verificabile).
- **Da fare**: allineare il capitolo "Raccolta dei log" di `caricamento-layer-l2.docx` allo stesso contenuto già presente in `caricamento-layer-l0-l1.docx` (correzione lato utente, non modificabile qui).
- **Dettagli**: [[caricamento-layer-l0-l1]].

## Verifiche eseguite (stato attuale, nessuna incongruenza rilevata)

Confermato il 2026-08-19 contro `raw/dwh-code/` e le tre docx correnti:

- **Macro Cluster D (`get_dt_osservazione`/`compute_dt_osservazione`/`delete_dt_osservazione`)**: la vecchia voce (nomi/firme sbagliati in doc, macro `delete_month` inesistente) è **risolta**. La sezione "Cluster D" di [[caricamento-layer-l0-l1]] ora usa i nomi e le firme reali verificate riga per riga in `raw/dwh-code/macros/materialization/get_dt_osservazione.sql`, `compute_dt_osservazione.sql`, `delete_dt_osservazione.sql`: `get_dt_osservazione(schedule='monthly')` (nessun parametro `ts_riferimento`/timestamp), `compute_dt_osservazione(column, schedule='monthly')` (la macro che normalizza un timestamp arbitrario), `delete_dt_osservazione(column='DT_OSSERVAZIONE', schedule='monthly')` (usa correttamente `{{ column }}` nel WHERE, non hardcoded). Il ramo `weekly` è ora documentato in doc. Non c'è più menzione di `last_day_past_month()`.
- **`query_tag` ANAGR_COMMERCIALE**: tutti e 12 i modelli in `models/L2/ANAGR_COMMERCIALE/*.yml` hanno `query_tag` presente e corretto (schema `L2_ANAGR_CONTROPARTE`/coerente con l'area — nessun gap).
- **Copertura skill vs codice**: `.claude/skills/develop-l2/SKILL.md` e `develop-l3/SKILL.md` restano coerenti con le convenzioni osservate in `raw/dwh-code/` (materializzazioni S1-S4/S2-S5, query_tag, delete_l2).
- **`custom_is_not_null`/`custom_is_null`**: macro presenti e usate in `carte_utilizzi.sql:109`, coerenti con la sez. 5.5 di [[guida-sviluppo]].
- **Placeholder obsoletizzazione `$$$$...$$$$`**: confermato ancora isolato a `ANAGR_CONTROPARTE/legame_ditte_individuali.sql` (righe 26-27), già correttamente escluso nel JOIN insieme a `custom_is_not_null`.
- **Pattern S1 (SCD2)**: `is_incremental_S1()` invariata, condivisa da più modelli; sentinella TIMESTAMP `9999-12-31 00:00:00.000` coerente su tutte le occorrenze L2.

## Voci non più verificabili (rimosse in questo giro per assenza della fonte)

Le seguenti voci comparivano nel giro precedente ma il loro lato "Doc" dipendeva esclusivamente da `raw/Agos X - Layer L2.xlsx` o dai csv `cfg_l1_schema`/`cfg_l1_cluster_sto`, ora cancellati da `raw/`. Non sono presentate come incongruenze attive perché non ri-verificabili con le fonti correnti:

- Convenzione valori flag `FL_`: xlsx riportava `'S'/'N'` contro lo standard reale `'Y'/'N'` — lo `'Y'/'N'` nel codice resta confermato (es. `delete_l2.sql` usa `FL_DELETED = 'Y'`), ma il lato doc non è più leggibile.
- Prefissi campo `ID_`/`SK_` (docx) vs `PR_` (xlsx) — xlsx non più disponibile per il confronto.
- Tassonomia sigle subject area (`ANA_CNT`, `PRD_CRT`, ...) vs nome esteso nel codice — xlsx non più disponibile.

Se l'utente reintroduce questi file o un loro sostituto, queste aree vanno ri-verificate da capo.

## Cosa NON è ancora stato verificato

- Il contenuto puntuale dei ~170 fogli per-tabella della xlsx non è più disponibile: quel confronto campo-per-campo non è più possibile in questo wiki.
- Le aree L1 CRIF/ADOBE/CTC non sono state ispezionate in dettaglio quanto OCS in questo giro.
- La sezione 5.5 OCS (varchar vuoti) non è stata riverificata riga per riga oltre ai casi citati sopra — delegata a [[null-vs-placeholder-ocs]].
- La ristrutturazione di CFG.json descritta in [[guida-sviluppo]] riguarda la libreria Glue (`dwh-x-glue-library`, repo separata non vendorizzata) — non verificabile contro codice in questo wiki.
- Bug applicativi minori già noti e non ridiscussi in questo giro (hardcode `marzo 2026` in `call_proc_report_fondi_masterscale.sql`, file `variazioni_anagrafiche_day.sql` che si autodichiara non testato su dati reali) — non ricontrollati, nessuna ragione di ritenerli cambiati.

## Collegamenti

- [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]], [[guida-sviluppo]]
- [[naming-convention-agos-x]], [[cancellazioni-fl-deleted]], [[storicizzazione-l1-cluster-a-b-c]], [[storicizzazione-l2-s1-s4]], [[storicizzazione-l3]]
- [[macro-catalogo-dbt]], [[data-masking-agos-x]], [[cobol-parsing]], [[progressivo-pk-e-progressivo-controparte]]
- [[query-tag-monitoring]], [[lastmodifieddata]]
- [[repo-dwh-x-dbt]]
- [[null-vs-placeholder-ocs]]
