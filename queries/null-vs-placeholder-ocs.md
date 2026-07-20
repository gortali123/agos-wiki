---
title: "NULL vs placeholder OCS (' ') in L2/L3: interventi secondo guida sviluppo"
type: query
tags: [layer/L1, layer/L2, layer/L3, ocs, data-quality]
updated: 2026-07-20
---

Regole ufficiali (guida sviluppo, sez. 5.5 "Gestione campi varchar vuoti OCS"):

1. **IS NULL su campi OCS** → sostituire con `{{ custom_is_null('campo') }}` (copre `campo IS NULL OR campo = ' '`).
2. **COALESCE con primo input OCS** → aggiungere `NULLIF(campo, ' ')`.
3. **JOIN/UNION** su campi OCS-OCS: nessuna modifica attesa. JOIN OCS↔non-OCS dove il campo può essere `' '` da un lato e NULL vero dall'altro: caso per caso, tema separato non ancora chiuso dalla guida stessa.

**Unica eccezione nota**: archivio `BACCPTES`, dove `' '` significa "Poste Italiane" (non un NULL). Non referenziata in nessun modello L2/L3 vendorizzato, quindi nessuna eccezione attiva oggi. La guida non ne cita altre.

## Da fare

### IS NULL da sostituire con `custom_is_null()`

| Macro area | Tabella | Righe | Campo |
|---|---|---|---|
| RISCHI_ADEMPIMENTI | `svalutazioni_m.sql` | 47 | SVCRSC_COD_TRANSAZIONE |
| RISCHI_ADEMPIMENTI | `flessibilita_m.sql` | 51 | PSVT_BLOCCO |
| GESTIONE_CREDITI | `perdite_minime_abb.sql` | 43 | PSVT_BLOCCO |
| PRODOTTO | `carta.sql` | 73-74 | CEMPR_INVIO_EC_MAIL, CEMPR_INVIO_EC_INTERNET |
| PRODOTTO_M | `carta_m.sql` | 70-71 | CEMPR_INVIO_EC_MAIL, CEMPR_INVIO_EC_INTERNET |
| CARTE | `carte_utilizzi.sql` | 143 | CRVOC_CODICE_CAMP |
| CARTE | `carte_utilizzi.sql` | 191 | CRVOC_CONTR_DEALER |
| PRODOTTO | `pratica.sql` | 149 | CHC_CES_PERDITA |
| PRODOTTO_M | `pratica_m.sql` | 154 | CHC_CES_PERDITA |
| PRODOTTO | `carta.sql` | 86 | CAB_COD_BLOCCO_OCS |
| PRODOTTO_M | `carta_m.sql` | 83 | CAB_COD_BLOCCO_OCS |
| CARTE | `carte_limitazioni_operativita.sql` | 12 | CAB_COD_BLOCCO_OCS |
| ONBOARDING | `wfl_fase.sql` | 12 | WFISFA_STATO |
| ONBOARDING | `wfl_istanza.sql` | 14 | WFISWFL_STATO |
| ONBOARDING | `wfl_sottofase.sql` | 13 | WFISSF_STATO |

Nota: le 3 righe `wfl_fase`/`wfl_istanza`/`wfl_sottofase` già replicano manualmente `IS NULL OR campo = ' '` (funzionalmente corrette) ma vanno migrate a `custom_is_null()` per uniformità, come richiesto dalla guida.

### COALESCE da integrare con `NULLIF(campo, ' ')`

| Macro area | Tabella | Righe | Campo (primo input COALESCE) |
|---|---|---|---|
| ONBOARDING | `doc_istruttoria.sql` | 19-26 | SEDO.OXDOTSEDO_OPE_BLOCCATA |
| GESTIONE_CREDITI | `passaggi_a_perdita.sql` | 8, 32 | B.TABTPP_CONCORDATA |
| ASSICURAZIONI | `provvigioni_assicurative.sql` | 7-8 | A.BAPV_SERVIZIO (workaround `TRIM(...)=''` ancora in uso, da migrare a `COALESCE(NULLIF(...))`) |

## Già corretto

| Macro area | Tabella | Righe | Nota |
|---|---|---|---|
| ANAGR_CONTROPARTE | `legame_ditte_individuali.sql` | 24-25 | Usa già `{{ custom_is_null('P.CD_PARTITA_IVA') }}` e `{{ custom_is_not_null('F.CD_PARTITA_IVA') }}` |

## Esclusi / non applicabili

- `ONBOARDING/wfl_attivita.sql` (16-24): non contiene più un check `IS NULL` — è un `CASE` per valore esplicito (`WHEN ' ' THEN ...`, `WHEN '' THEN ...`), già gestito ad hoc.
- `RISCHI_ADEMPIMENTI/moratorie_m.sql` (56, 68), OXPSRIO_ORIGINE_RICHIESTA: NULL da `LEFT JOIN` senza match, non da placeholder OCS — condizione `IS NOT NULL` corretta così com'è.
- `L3/basilea_core/dm_controlli_basilea_m.sql` (righe 28,47,50,57,60), letture da `L1_O_BAS.IFBLFSCRCO_TEST`/`IFBLFSCRCA_TEST` via `env_var()` hardcoded: provenienza non classificabile con certezza, da verificare prima di applicare la macro.
- `ANTIFRODE/gestione_truffe.sql` (53, 56), letture da `L0.OXTRFTRU_TEST`/`OXTRFPTR_TEST`: stesso motivo, provenienza incerta.
- `PRODOTTO/pratica.sql:570` e `PRODOTTO_M/pratica_m.sql:590` (CACSCES_TOT_PERDITA): tipo colonna probabilmente numerico, da verificare prima di applicare la macro.
- SWORD (14 modelli, XML `master_data`), SCORE_BANCHE_DATI (11 modelli, XML `cde`): sorgenti NO-OCS, nessun intervento richiesto.

## Collegamenti

- [[l2-anagr-controparte]], [[l2-rischi-adempimenti]], [[l2-gestione-crediti]], [[l2-prodotto]], [[l2-prodotto-m]], [[l2-carte]], [[l2-onboarding]]
- [[cfg-l1-schema-e-cluster-sto]]
- [[inconsistenze]]
