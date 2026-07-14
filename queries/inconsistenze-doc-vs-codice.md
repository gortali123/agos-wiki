---
title: "Inconsistenze tra documentazione e codice (dwh-x-dbt)"
type: query
tags: [inconsistenze, layer/L0, layer/L1, layer/L2, layer/L3, naming-convention]
updated: 2026-07-14
---

Confronto sistematico tra i tre documenti tecnici/operativi ([[caricamento-layer-l0-l1]], [[caricamento-layer-l2]], [[guida-sviluppo]] + xlsx [[layer-l2-xlsx-reference]]) e lo stato reale del codice in `raw/dwh-code/` (snapshot verificato 2026-07-14). Ordinate per severità/impatto pratico decrescente. Per ciascuna: cosa dice la doc, cosa fa il codice, perché è rilevante, dove sono i dettagli.

## 1. `query_tag` L2: obbligatorio secondo la doc, assente in metà del codice, sbagliato in un'altra parte

- **Doc**: [[guida-sviluppo]] lo rende **obbligatorio** in checklist pre-rilascio; [[caricamento-layer-l2]] lo richiede per il monitoring dettagliato delle query.
- **Codice**: assente del tutto in ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, SWORD. Dove presente: **CARTE** ha tutti e 6 i modelli con `schema: "L2_PRODOTTO"` invece di `L2_CARTE`; **PROVVIGIONI_RAPPEL** ha `schema: "L2_MAIN"` (sigla non riconosciuta) e il `query_tag` è **commentato con `#`** in entrambi i modelli (quindi disattivo); `indice_rischio_m` ha `entita: "INDICE_RISCHIO"` invece di `"INDICE_RISCHIO_M"`. Solo RISCHI_ADEMPIMENTI e SALDI sono coerenti.
- **Impatto**: il monitoring per-query su Snowflake (query_tag) descritto come pilastro dell'osservabilità DBT è di fatto inaffidabile per gran parte del progetto.
- **Dettagli**: [[storicizzazione-l2-s1-s4]], [[l2-carte]], [[l2-provvigioni-rappel]], [[l2-rischi-adempimenti]].

## 2. Cancellazioni L2: due meccanismi non equivalenti, non è chiaro quale sia lo standard

- **Doc**: [[caricamento-layer-l2]]/[[guida-sviluppo]] descrivono un processo a 2 step sempre presente — filtro `FL_DELETED` + `pre_hook delete_l2(...)` per la DELETE fisica.
- **Codice**: molti modelli (es. `ANTIFRODE.archivio_tessere`, gran parte di GESTIONE_CREDITI, PRODOTTO) hanno **solo** il filtro `WHERE FL_DELETED = 'N'`, senza `pre_hook delete_l2`. Questo significa che una riga già caricata e poi cancellata alla fonte **resta stale nel target L2** per questi modelli (il filtro nasconde solo le nuove righe cancellate lette dall'incrementale, non rimuove quelle già presenti).
- **Impatto**: query di business su queste entità possono contare/mostrare pratiche/controparti/eventi che sono stati cancellati alla fonte, se non filtrate esplicitamente anche a valle.
- **Dettagli**: [[cancellazioni-fl-deleted]].

## 3. Convenzione valori flag: xlsx dice "S"/"N", codice e docx usano "Y"/"N"

- **Doc (xlsx, foglio Nomenclatura Campi)**: "Indicatore Flag (FL_): Rigorosamente a 2 valori. 'S' o 'N'".
- **Doc (docx) e codice**: `FL_DELETED` (il flag più usato nel progetto) usa sistematicamente **'Y'/'N'**, non 'S'/'N'. Non abbiamo verificato se esistano anche flag con 'S'/'N' nel codice (non incluso nello scope degli agent di ricerca) — ma la convenzione di riferimento e l'uso più pervasivo del progetto sono disallineati.
- **Impatto**: chiunque scriva un nuovo modello guardando solo la xlsx come riferimento normativo potrebbe implementare un flag con valori 'S'/'N' non coerenti con `FL_DELETED` esistente, o viceversa.
- **Dettagli**: [[naming-convention-agos-x]], [[cancellazioni-fl-deleted]].

## 4. Prefissi campo: due liste diverse tra docx e xlsx

- **Docx**: `CD_, ID_, DS_, NM_, DT_, TS_, FL_, TP_, EU_, PC_, SK_, GN_`.
- **Xlsx**: `CD, DS, TP, DT, TS, EU, FL, NM, PC, PR (Progressivo), GN_`.
- Divergenza: `ID_`/`SK_` solo nei docx; `PR_` solo nella xlsx (e nemmeno usato coerentemente nel codice: `PROGRESSIVO_PK`/`PROGRESSIVO_CONTROPARTE` non hanno prefisso `PR_`).
- **Impatto**: basso/medio — ambiguità su quale lista sia normativa, specialmente per `PR_`/Progressivo.
- **Dettagli**: [[naming-convention-agos-x]].

## 5. Subject area: due tassonomie di sigle non riconciliate

- **Docx + codice**: aree funzionali per nome esteso (`ANAGR_CONTROPARTE`, `CARTE`, ...) = nome cartella = (quando presente) schema `L2_<NOME_ESTESO>`.
- **Xlsx** (foglio Nomenclatura SubjectArea): sigle a 3+3 lettere (`ANA_CNT`, `PRD_CRT`, `ADP_SLD`, `SDE_ANT`, ...) con schema previsto `L2_<SIGLA>` — **mai osservato nel codice reale**.
- **Impatto**: basso ma confusionario per chi consulta la xlsx aspettandosi di trovare quegli schemi Snowflake.
- **Dettagli**: [[naming-convention-agos-x]], [[layer-l2-xlsx-reference]].

## 6. `dbt_artifacts.upload_results` documentato ma non presente nel codice

- **Doc**: sia [[caricamento-layer-l0-l1]] che [[caricamento-layer-l2]] descrivono `on-run-end: dbt_artifacts.upload_results(results)` come meccanismo di raccolta log (tabelle `MODELS`, `TESTS`, `SNAPSHOTS`, `*_EXECUTIONS`).
- **Codice**: `dbt_project.yml` ha `on-run-end: [log_run_results(results), pop_test_log_records(results)]`. **Nessuna traccia** del pacchetto `dbt_artifacts` (né macro, né dipendenza in `package-lock.yml`, che contiene solo `dbt_utils`). Il logging reale passa da una stored procedure custom `TECH.LOG_DBT` chiamata da `log_run_results`, non dal pacchetto `dbt_artifacts`.
- **Impatto**: alto per chi cerca di orientarsi nel sistema di log basandosi sulla doc — le tabelle/viste descritte (`V_L1_DBT_RUN_MODELS` ecc.) potrebbero essere costruite su una fonte diversa da quella documentata, o essere esse stesse superate. Da chiarire con il team se `dbt_artifacts` è stato rimosso di recente o non è mai stato realmente adottato.
- **Dettagli**: [[repo-dwh-x-dbt]].

## 7. Nomi dei test generici custom: doc dice `primary_key_table`/`try_cast_table`, codice ha `primary_key`/`try_cast`

- **Doc**: entrambi i nomi con suffisso `_table`.
- **Codice**: implementati come `primary_key` / `primary_key_positional` / `try_cast` / `try_cast_from_sql` / `try_cast_positional` (nessuno con `_table`). Il suffisso `_table` sopravvive solo nel template scaffold `templates/models/L0/table_source.yml`, suggerendo che i test siano stati rinominati dopo la stesura del template (o del documento) senza aggiornare l'uno o l'altro.
- **Impatto**: medio — chi cerca questi test nel codice cercando il nome esatto dalla doc non li trova.
- **Dettagli**: [[repo-dwh-x-dbt]].

## 8. Macro documentate ma non trovate (o trovate con nome diverso)

- **`remove_datamask()`**: documentata in [[caricamento-layer-l2]], **non esiste nel codice**. Esiste solo `add_datamask()`. Vedi [[data-masking-agos-x]].
- **`decode_overpunch`**: documentata come se fosse una macro dbt in [[caricamento-layer-l0-l1]]; in realtà è una **UDF Snowflake** (`AGOS_DEV_16000.L0.DECODE_OVERPUNCH`), non una macro — e la sua implementazione non è nello snapshot `raw/dwh-code/macros/`. Vedi [[cobol-parsing]].
- **`logical_delete_merge` / `logical_delete_scd2`**: nel codice si chiamano `logic_delete_merge()` / `logic_delete_scd2()` (senza "-al"). Probabile refuso terminologico nella doc più che un problema funzionale.
- **Dettagli**: [[macro-catalogo-dbt]].

## 9. Due implementazioni del pattern S1 (SCD2) coesistono, con logica di dedup diversa

- La maggior parte dei modelli S1 (`variazioni_anagrafiche`, `indirizzi_postalizzazione`) implementa la logica di dedup/hash "a mano" con CTE esplicite.
- `wfl_istanza` (ONBOARDING) è l'unico che usa la macro condivisa `is_incremental_S1(...)`.
- Nessuna delle due fonti raw documenta esplicitamente questa doppia via — la doc descrive un solo pattern S1 "canonico" (quello bespoke, dettagliato passo-passo in [[guida-sviluppo]]).
- **Impatto**: rischio che la macro condivisa e l'implementazione bespoke producano risultati leggermente diversi in edge case (es. gestione dei duplicati); da validare se `is_incremental_S1` è effettivamente equivalente prima di usarla come riferimento per nuovi modelli.
- **Dettagli**: [[storicizzazione-l2-s1-s4]].

## 10. Sentinella "finestra aperta": TIMESTAMP in L2/S1, DATE in L3/S5

- Le macro L2 S1 (`ts_fine_validita`, `is_incremental_S1`) usano sentinella **TIMESTAMP** `9999-12-31 00:00:00.000`.
- La macro L3 S5 (`scd2_foto_mensile`) usa sentinella **DATE** `TO_DATE('9999-12-31')`.
- Non documentato esplicitamente in nessuno dei tre file raw come una differenza intenzionale.
- **Impatto**: basso ma rilevante per chi scrive JOIN cross-layer su condizioni di validità (mismatch di tipo TIMESTAMP vs DATE).
- **Dettagli**: [[storicizzazione-l3]].

## 11. Bug applicativi minori scoperti durante l'ispezione (non da doc, ma da segnalare)

- `custom_to_date`: la guard per input a 5 cifre referenzia una variabile Jinja non definita (`col_str` invece di `column`) — va in errore invece di dare un messaggio pulito. Vedi [[macro-catalogo-dbt]].
- `delete_month(column='DT_OSSERVAZIONE', ...)`: il parametro `column` è accettato ma **ignorato** — la DELETE usa sempre il letterale `DT_OSSERVAZIONE`. Se mai invocata con un nome colonna diverso, non farebbe l'effetto atteso.
- `call_proc_report_fondi_masterscale.sql`: contiene un workaround hardcoded che forza il mese di calcolo a marzo 2026, con commento esplicito "togliere il replace" — hack temporaneo attivo, da rimuovere.
- `RISCHI_ADEMPIMENTI/ristrutturazioni_o_sql` / `ristrutturazioni_o_yml`: nome file senza punto prima dell'estensione — come nominati, dbt non li riconoscerebbe come file modello.
- File orfani: `variazioni_anagrafiche.sql.old`, `variazioni_anagrafiche_day.sql.old`.
- `variazioni_anagrafiche_day.sql` si autodichiara nell'header come proposta di riscrittura non testata su dati reali — da verificare se è la versione realmente deployata.
- `models/L0/` copre solo ADOBE, CTC, OCS (manca CRIF, presente invece in L1) — snapshot vendorizzato parziale, non un bug del progetto reale ma un limite di questo wiki (vedi nota in [[repo-dwh-x-dbt]]).

## Cosa NON è ancora stato verificato

- Il contenuto puntuale dei ~170 fogli per-tabella della xlsx (tracciati campo-per-campo) non è stato confrontato modello per modello con lo YAML reale — solo un campione (ANAGR_CONTROPARTE via Catalogo Entità). Se serve una verifica puntuale su un'altra entità, va fatta come query mirata.
- Le aree L1 CRIF/ADOBE/CTC non sono state ispezionate in dettaglio quanto OCS.
- La sezione L3 dei tre documenti raw è la meno dettagliata; il confronto con `basilea_core`/`monitoraggio_produzione` è stato solo parziale (macro Basilea catalogate, modelli L3 specifici non letti riga per riga).

## Collegamenti

- [[caricamento-layer-l0-l1]], [[caricamento-layer-l2]], [[guida-sviluppo]], [[layer-l2-xlsx-reference]]
- [[naming-convention-agos-x]], [[cancellazioni-fl-deleted]], [[storicizzazione-l1-cluster-a-b-c]], [[storicizzazione-l2-s1-s4]], [[storicizzazione-l3]]
- [[macro-catalogo-dbt]], [[data-masking-agos-x]], [[cobol-parsing]], [[progressivo-pk-e-progressivo-controparte]]
- [[repo-dwh-x-dbt]]
