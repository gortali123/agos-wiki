---
title: "Inconsistenze: codice vs skill vs documentazione (dwh-x-dbt)"
type: query
tags: [inconsistenze, layer/L0, layer/L1, layer/L2, layer/L3, naming-convention]
updated: 2026-07-20
---

Elenco **solo delle incongruenze attualmente aperte** tra le tre fonti di verità del progetto: **codice** (`raw/dwh-code/`), **skill** (`.claude/skills/develop-l2`, `develop-l3`, `dm-reader`) e **documentazione** (docx/xlsx ingeriti in [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]], [[guida-sviluppo]], [[layer-l2-xlsx-reference]]). Le voci risolte vengono rimosse, non archiviate qui — vedi la sezione "Verifiche eseguite" per lo stato attuale confermato.

## Tabella

| # | Titolo | Codice | Skill | Doc |
|---|---|---|---|---|
| 1 | query_tag L2: obbligatorio, assente/errato nel codice | ⚠️ incompleto/errato | — | ✅ prescrive obbligo |
| 2 | Cancellazioni L2: due meccanismi non equivalenti | ⚠️ incompleto in più aree | — | ✅ prescrive 2 step sempre |
| 3 | Flag: xlsx dice S/N, codice/docx usano Y/N | ✅ Y/N pervasivo | — | ⚠️ xlsx diverge dal docx |
| 4 | Prefissi campo: `PROGRESSIVO_CONTROPARTE` senza prefisso `PR_` | ⚠️ parziale | — | ⚠️ xlsx/docx non riconciliate su `ID_`/`SK_` |
| 5 | Subject area: due tassonomie di sigle | ✅ solo nome esteso osservato | — | ⚠️ xlsx sigle mai viste nel codice |
| 6 | `dbt_artifacts.upload_results` documentato, non presente | ✅ usa log_run_results/TECH.LOG_DBT | — | ⚠️ descrive dbt_artifacts |
| 7 | Nomi test generici: doc dice `_table`, codice no | ✅ nomi senza `_table` | — | ⚠️ doc con suffisso `_table` |
| 8 | Macro documentate ma non trovate/nome diverso | ✅ nomi reali diversi | — | ⚠️ nomi non corrispondenti |
| 9 | Sentinella finestra aperta: TIMESTAMP (L2/S1) vs DATE (L3/S5) | ⚠️ due tipi diversi | — | ⚠️ non documentato come intenzionale |
| 10 | Bug applicativi minori (vari) | ⚠️ vedi dettaglio | — | — |

Legenda: ✅ = coerente/conferma la riga; ⚠️ = incongruenza/gap rilevato; — = fonte non coinvolta in questa voce.

## Dettaglio

### 1. `query_tag` L2: obbligatorio secondo la doc, assente in metà del codice, sbagliato in un'altra parte

- **Doc**: [[guida-sviluppo]] lo rende **obbligatorio** in checklist pre-rilascio (sezione 5.2/5.4); [[caricamento-layer-l2]] lo richiede per il monitoring dettagliato delle query.
- **Codice**: assente del tutto in ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, SWORD. Dove presente: **CARTE** ha tutti e 6 i modelli con `schema: "L2_PRODOTTO"` invece di `L2_CARTE`; **PROVVIGIONI_RAPPEL** ha `schema: "L2_MAIN"` (sigla non riconosciuta) e il `query_tag` è **commentato con `#`** in entrambi i modelli (quindi disattivo); `indice_rischio_m` ha `entita: "INDICE_RISCHIO"` invece di `"INDICE_RISCHIO_M"`. Solo RISCHI_ADEMPIMENTI e SALDI sono coerenti.
- **Impatto**: il monitoring per-query su Snowflake (query_tag) descritto come pilastro dell'osservabilità DBT è di fatto inaffidabile per gran parte del progetto.
- **Dettagli**: [[query-tag-monitoring]], [[storicizzazione-l2-s1-s4]], [[l2-carte]], [[l2-provvigioni-rappel]].

### 2. Cancellazioni L2: due meccanismi non equivalenti, non è chiaro quale sia lo standard

- **Doc**: [[caricamento-layer-l2]]/[[guida-sviluppo]] (sezione 5.3) descrivono un processo a 2 step sempre presente — filtro `FL_DELETED` + `pre_hook delete_l2(...)` per la DELETE fisica.
- **Codice**: molti modelli (es. `ANTIFRODE.archivio_tessere`, gran parte di GESTIONE_CREDITI, PRODOTTO) hanno **solo** il filtro `WHERE FL_DELETED = 'N'`, senza `pre_hook delete_l2`. Una riga già caricata e poi cancellata alla fonte **resta stale nel target L2** per questi modelli.
- **Impatto**: query di business su queste entità possono contare/mostrare pratiche/controparti/eventi cancellati alla fonte, se non filtrate esplicitamente anche a valle.
- **Dettagli**: [[cancellazioni-fl-deleted]], [[l2-antifrode]].

### 3. Convenzione valori flag: xlsx dice "S"/"N", codice e docx usano "Y"/"N"

- **Doc (xlsx, foglio Nomenclatura Campi)**: "Indicatore Flag (FL_): Rigorosamente a 2 valori. 'S' o 'N'".
- **Doc (docx) e codice**: `FL_DELETED` (il flag più usato nel progetto) usa sistematicamente **'Y'/'N'**.
- **Impatto**: chi scrive un nuovo modello guardando solo la xlsx potrebbe implementare un flag 'S'/'N' non coerente con `FL_DELETED` esistente.
- **Dettagli**: [[naming-convention-agos-x]], [[cancellazioni-fl-deleted]].

### 4. Prefissi campo: `PROGRESSIVO_CONTROPARTE` ancora senza prefisso `PR_`; `ID_`/`SK_` non in xlsx

- **Aggiornamento 2026-07-20**: il campo `PROGRESSIVO_PK` è stato rinominato in `PR_PK` nel codice (`variazioni_anagrafiche.sql`/`.yml`) e la docx aggiornata usa ora lo stesso nome — quella parte della divergenza è **risolta**.
- **Residuo**: `PROGRESSIVO_CONTROPARTE` (stesso modello) resta scritto per esteso, senza prefisso `PR_`. La docx elenca inoltre `ID_`/`SK_` come prefissi validi, assenti dalla xlsx (foglio Nomenclatura Campi), e la xlsx elenca `PR_` che nel docx non compare come lista generale prefissi.
- **Impatto**: basso — ambiguità residua solo su `PROGRESSIVO_CONTROPARTE` e su `ID_`/`SK_`.
- **Dettagli**: [[naming-convention-agos-x]], [[progressivo-pk-e-progressivo-controparte]].

### 5. Subject area: due tassonomie di sigle non riconciliate

- **Docx + codice**: aree funzionali per nome esteso (`ANAGR_CONTROPARTE`, `CARTE`, ...) = nome cartella = (quando presente) schema `L2_<NOME_ESTESO>`.
- **Xlsx** (foglio Nomenclatura SubjectArea): sigle a 3+3 lettere (`ANA_CNT`, `PRD_CRT`, `ADP_SLD`, `SDE_ANT`, ...) con schema previsto `L2_<SIGLA>` — **mai osservato nel codice reale**.
- **Impatto**: basso ma confusionario per chi consulta la xlsx aspettandosi di trovare quegli schemi Snowflake.
- **Dettagli**: [[naming-convention-agos-x]], [[layer-l2-xlsx-reference]].

### 6. `dbt_artifacts.upload_results` documentato ma non presente nel codice

- **Doc**: sia [[caricamento-layer-l0-l1]] che [[caricamento-layer-l2]] descrivono `on-run-end: dbt_artifacts.upload_results(results)`.
- **Codice**: `dbt_project.yml` ha `on-run-end: [log_run_results(results), pop_test_log_records(results)]`. Nessuna traccia del pacchetto `dbt_artifacts` (né macro, né dipendenza in `package-lock.yml`). Il logging reale passa da una stored procedure custom `TECH.LOG_DBT` chiamata da `log_run_results`.
- **Impatto**: alto per chi si orienta nel sistema di log basandosi sulla doc.
- **Dettagli**: [[repo-dwh-x-dbt]].

### 7. Nomi dei test generici custom: doc dice `primary_key_table`/`try_cast_table`, codice ha `primary_key`/`try_cast`

- **Codice**: `primary_key`, `primary_key_positional`, `try_cast`, `try_cast_from_sql`, `try_cast_positional` (nessuno con `_table`). Il suffisso `_table` sopravvive solo nel template scaffold `templates/models/L0/table_source.yml`.
- **Impatto**: medio — chi cerca questi test nel codice col nome esatto della doc non li trova.
- **Dettagli**: [[repo-dwh-x-dbt]].

### 8. Macro documentate ma non trovate (o trovate con nome diverso)

- **`remove_datamask()`**: documentata in [[caricamento-layer-l2]], **non esiste nel codice**. Esiste solo `add_datamask()`. Vedi [[data-masking-agos-x]].
- **`decode_overpunch`**: documentata come macro dbt in [[caricamento-layer-l0-l1]]; in realtà è una **UDF Snowflake** (`AGOS_DEV_16000.L0.DECODE_OVERPUNCH`), non nello snapshot `raw/dwh-code/macros/`. Vedi [[cobol-parsing]].
- **`logical_delete_merge` / `logical_delete_scd2`**: nel codice si chiamano `logic_delete_merge()` / `logic_delete_scd2()` (senza "-al").
- **Dettagli**: [[macro-catalogo-dbt]].

### 9. Sentinella "finestra aperta": TIMESTAMP in L2/S1, DATE in L3/S5

- Le macro L2 S1 (`ts_fine_validita`, `is_incremental_S1`) usano sentinella **TIMESTAMP** `9999-12-31 00:00:00.000`.
- La macro L3 S5 (`scd2_foto_mensile`) usa sentinella **DATE** `TO_DATE('9999-12-31')`.
- Non documentato esplicitamente in nessuno dei tre file raw come una differenza intenzionale.
- **Impatto**: basso ma rilevante per chi scrive JOIN cross-layer su condizioni di validità.
- **Dettagli**: [[storicizzazione-l3]], [[macro-catalogo-dbt]].

### 10. Bug applicativi minori scoperti durante l'ispezione (non da doc, ma da segnalare)

- `custom_to_date`: la guard per input a 5 cifre referenzia una variabile Jinja non definita (`col_str` invece di `column`) — va in errore invece di dare un messaggio pulito.
- `delete_month(column='DT_OSSERVAZIONE', ...)`: il parametro `column` è accettato ma **ignorato** — la DELETE usa sempre il letterale `DT_OSSERVAZIONE`.
- `call_proc_report_fondi_masterscale.sql`: workaround hardcoded che forza il mese di calcolo a marzo 2026, commento esplicito "togliere il replace" — hack temporaneo attivo.
- `RISCHI_ADEMPIMENTI/ristrutturazioni_o_sql` / `ristrutturazioni_o_yml`: nome file senza punto prima dell'estensione — dbt non li riconoscerebbe come file modello.
- File orfani: `variazioni_anagrafiche.sql.old`, `variazioni_anagrafiche_day.sql.old`.
- `variazioni_anagrafiche_day.sql` si autodichiara nell'header come proposta di riscrittura non testata su dati reali — da verificare se è la versione realmente deployata.
- `models/L0/` copre solo ADOBE, CTC, OCS (manca CRIF, presente invece in L1) — limite di questo wiki, non del progetto reale.

## Verifiche eseguite (stato attuale, nessuna incongruenza rilevata)

Confermato contro `raw/dwh-code/` risincronizzato e guida sviluppo aggiornata al 2026-07-20:

- **Pattern S1 (SCD2)**: due implementazioni coesistono ma sono equivalenti funzionalmente — `is_incremental_S1()` (macro condivisa, usata da 8+ modelli: `indirizzi_postalizzazione`, `carte_utilizzi`, tutti i `wfl_*` di ONBOARDING, `tabelle_finanziarie`, `variazioni_stato_prat`) assorbe lo stesso dedup-hash del pattern bespoke residuo (`variazioni_anagrafiche`, unico modello ancora manuale). Nessun rischio di risultati diversi. Solo gap: la doc descrive solo il pattern bespoke, non la macro condivisa (gap di documentazione, non funzionale). Vedi [[storicizzazione-l2-s1-s4]].
- **`PROGRESSIVO_PK`→`PR_PK`**: rinominato nel codice e nella docx in modo coerente (vedi voce 4 sopra, risolta per questo campo). Vedi [[progressivo-pk-e-progressivo-controparte]].
- **Sezione OCS varchar vuoti (5.5 docx)**: nuova sezione ingerita in [[guida-sviluppo]]; analisi puntuale del codice delegata a [[null-vs-placeholder-ocs]] (gestita separatamente).
- **Macro core** (`custom_to_date`, `delete_month`, `is_incremental_S1`, `ts_fine_validita`, `scd2_foto_mensile`, `add_datamask`/assenza `remove_datamask`, `log_run_results`, `call_proc_report_fondi_masterscale`): invariate rispetto al resync precedente.
- **Copertura skill vs codice**: convenzioni in `.claude/skills/develop-l2/SKILL.md` e `develop-l3/SKILL.md` (macro dtype, sentinella TIMESTAMP, ordine campi, pattern S1-S4/S2-S4) coerenti con `raw/dwh-code/`. `dm-reader/SKILL.md` non fa claim sul codice dbt.

## Cosa NON è ancora stato verificato

- Il contenuto puntuale dei ~170 fogli per-tabella della xlsx (tracciati campo-per-campo) non è stato confrontato modello per modello con lo YAML reale — solo un campione (ANAGR_CONTROPARTE via Catalogo Entità).
- Le aree L1 CRIF/ADOBE/CTC non sono state ispezionate in dettaglio quanto OCS.
- La sezione L3 dei tre documenti raw è la meno dettagliata; il confronto con `basilea_core`/`monitoraggio_produzione` è solo parziale.
- La sezione 5.5 OCS (varchar vuoti) non è stata verificata riga per riga in questo giro — delegata a [[null-vs-placeholder-ocs]].

## Collegamenti

- [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]], [[guida-sviluppo]], [[layer-l2-xlsx-reference]]
- [[naming-convention-agos-x]], [[cancellazioni-fl-deleted]], [[storicizzazione-l1-cluster-a-b-c]], [[storicizzazione-l2-s1-s4]], [[storicizzazione-l3]]
- [[macro-catalogo-dbt]], [[data-masking-agos-x]], [[cobol-parsing]], [[progressivo-pk-e-progressivo-controparte]]
- [[query-tag-monitoring]], [[lastmodifieddata]]
- [[repo-dwh-x-dbt]]
- [[null-vs-placeholder-ocs]]
