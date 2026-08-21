---
title: "NULL vs placeholder OCS (' ') in L2/L3: interventi secondo guida sviluppo"
type: query
tags: [layer/L1, layer/L2, layer/L3, ocs, data-quality]
updated: 2026-08-03
---

Regole ufficiali (guida sviluppo, sez. 5.5 "Gestione campi varchar vuoti OCS"):

1. **IS NULL su campi OCS** → sostituire con `{{ custom_is_null('campo') }}` (copre `campo IS NULL OR campo = ' '`).
2. **COALESCE con primo input OCS** → aggiungere `NULLIF(campo, ' ')`.
3. **JOIN/UNION** su campi OCS-OCS: nessuna modifica attesa. JOIN OCS↔non-OCS dove il campo può essere `' '` da un lato e NULL vero dall'altro: caso per caso, tema separato non ancora chiuso dalla guida stessa.

**Unica eccezione nota**: archivio `BACCPTES`, dove `' '` significa "Poste Italiane" (non un NULL). Non referenziata in nessun modello L2/L3 vendorizzato, quindi nessuna eccezione attiva oggi. La guida non ne cita altre.

## Da fare (rivalutato 2026-08-03 contro codice reale — la maggior parte dei punti aperti nel giro precedente è stata migrata upstream)

### IS NULL/COALESCE ancora aperti

| Macro area       | Tabella                  | Righe | Campo                | Problema |
| ---------------- | ------------------------ | ----- | --------------------- | -------- |
| CARTE            | `carte_utilizzi.sql`     | 148   | CRVOC_CONTR_DEALER    | `IS NOT NULL` puro invece di `custom_is_not_null()`; possibile campo NUMBER, vedi [[inconsistenze]] voce 12 |
| GESTIONE_CREDITI | `passaggi_a_perdita.sql` | 8, 32 | B.TABTPP_CONCORDATA   | `NULLIF('B.TABTPP_CONCORDATA', ' ')` — nome colonna passato come stringa letterale tra apici, il confronto non ha mai effetto reale (bug di sintassi, non solo gap di migrazione). Vedi [[inconsistenze]] voce 14 |

### Già corretto nel frattempo (era "da fare" nel giro precedente, ora migrato upstream)

`RISCHI_ADEMPIMENTI/svalutazioni_m.sql:47`, `flessibilita_m.sql:51,54`, `GESTIONE_CREDITI/perdite_minime_abb.sql:43`, `PRODOTTO/carta.sql:73-74,86`, `PRODOTTO_M/carta_m.sql:70-71,83`, `CARTE/carte_limitazioni_operativita.sql:12`, `PRODOTTO/pratica.sql:149`, `PRODOTTO_M/pratica_m.sql:154`, `CARTE/carte_utilizzi.sql:94` (ex 143, CRVOC_CODICE_CAMP), `ONBOARDING/wfl_fase.sql:12`, `wfl_sottofase.sql:13`, `wfl_istanza.sql:14`, `wfl_attivita.sql:17` — tutti ora usano `custom_is_null`/`custom_is_not_null`; `ONBOARDING/doc_istruttoria.sql:19-26` ora `COALESCE(NULLIF(SEDO.OXDOTSEDO_OPE_BLOCCATA, ' '), ...)`; `ASSICURAZIONI/provvigioni_assicurative.sql:7` ora `{{ custom_is_null('A.BAPV_SERVIZIO') }}` (workaround TRIM rimosso).

## Già corretto (residuo dal giro precedente)

| Macro area | Tabella | Righe | Nota |
|---|---|---|---|
| ANAGR_CONTROPARTE | `legame_ditte_individuali.sql` | 24-25 | Usa già `{{ custom_is_null('P.CD_PARTITA_IVA') }}` e `{{ custom_is_not_null('F.CD_PARTITA_IVA') }}` |

## Esclusi / non applicabili

- `ONBOARDING/wfl_attivita.sql` (16-24): non contiene più un check `IS NULL` — è un `CASE` per valore esplicito (`WHEN ' ' THEN ...`, `WHEN '' THEN ...`), già gestito ad hoc.
- `RISCHI_ADEMPIMENTI/moratorie_m.sql` (56, 68), OXPSRIO_ORIGINE_RICHIESTA: NULL da `LEFT JOIN` senza match, non da placeholder OCS — condizione `IS NOT NULL` corretta così com'è.
- `L3/basilea_core/dm_controlli_basilea_m.sql` (righe 28,47,50,57,60), letture da `L1_O_BAS.IFBLFSCRCO_TEST`/`IFBLFSCRCA_TEST` via `env_var()` hardcoded: provenienza non classificabile con certezza, da verificare prima di applicare la macro.
- `ANTIFRODE/gestione_truffe.sql` (53, 56), letture da `L0.OXTRFTRU_TEST`/`OXTRFPTR_TEST`: stesso motivo, provenienza incerta.
- `PRODOTTO/pratica.sql:570` e `PRODOTTO_M/pratica_m.sql:590` (CACSCES_TOT_PERDITA): tipo colonna probabilmente numerico, da verificare prima di applicare la macro.
- `CARTE/carte_utilizzi.sql:116-117,165-166` (CROSV_EMETTITORE_A, CROSV_RIGA, SPCLSTAQ_RIGA): check di esistenza riga da `LEFT JOIN`, non placeholder OCS.
- `CARTE/carte_utilizzi.sql:273` (CEMEM_CAU_COMMISSIO42) in condizione `ON` di una `LEFT JOIN`: basso rischio pratico, da rivalutare solo se emergono anomalie.
- SWORD (14 modelli, XML `master_data`), SCORE_BANCHE_DATI (11 modelli, XML `cde`): sorgenti NO-OCS, nessun intervento richiesto.

## Parte B — placeholder NUMBER OCS (0 invece di NULL), gap di documentazione

`sources/guida-sviluppo.md` sez. 5.5 tratta **solo** il placeholder VARCHAR `' '`; il problema analogo su NUMBER (OCS invia `0` invece di NULL) non è menzionato in nessuna sezione della guida. Casi sospetti con indizio concreto (campo gemello nello stesso file già trattato con `NULLIF(x,0)`, o usato per dedurre presenza/assenza dato):

- `CARTE/carte_utilizzi.sql:148` — `CRVOC_CONTR_DEALER IS NOT NULL` per derivare `FL_CONTRIBUTI_PROMO`; campi gemelli per significato nello stesso modello (`CRVOA_CONVENZIONATO`/`SUB_AGENTE`/`AGENTE`, righe 20-22/59-66) usano correttamente `NULLIF(campo,0)`.
- `CARTE/carte_utilizzi.sql:109` — `CRVOA_NUMERO_ASSEGNO IS NOT NULL` per derivare `FL_ASSEGNO`; da verificare tipo colonna in L1.

Nessun caso trovato di campo NUMBER OCS usato come denominatore di una divisione senza `NULLIF(...,0)`. Vedi [[inconsistenze]] voce 12.

## Collegamenti

- [[l2-anagr-controparte]], [[l2-rischi-adempimenti]], [[l2-gestione-crediti]], [[l2-prodotto]], [[l2-prodotto-m]], [[l2-carte]], [[l2-onboarding]]
- [[cfg-l1-schema-e-cluster-sto]]
- [[storicizzazione-l1-cluster-a-b-c]] — sezione "Normalizzazione varchar vuoti OCS in L1": i modelli L1 OCS/AIN normalizzano già (`IFF(RTRIM(campo)='', ' ', RTRIM(campo))`) ogni stringa vuota a placeholder `' '` canonico; è logica L1 reale, ma va in direzione opposta a questa pagina (produce/canonicalizza il placeholder, non lo converte in NULL)
- [[inconsistenze]]
