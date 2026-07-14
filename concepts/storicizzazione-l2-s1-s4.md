---
title: "Storicizzazione L2: pattern S1-S4"
type: concept
tags: [layer/L2, storicizzazione]
updated: 2026-07-14
---

I quattro pattern di storicizzazione L2 documentati in [[caricamento-layer-l2]] e [[guida-sviluppo]], verificati contro i modelli reali in `raw/dwh-code/models/L2/` (2026-07-14).

| Pattern | Materializzazione | Chiave tecnica | Uso tipico |
|---|---|---|---|
| **S1** (SCD2) | `incremental`, `merge` | `TS_INIZIO_VALIDITA`/`TS_FINE_VALIDITA` | storia versionata di un'entità (es. `VARIAZIONI_ANAGRAFICHE`, `INDIRIZZI_POSTALIZZAZIONE`, `WFL_ISTANZA`, `CARTE_UTILIZZI`) |
| **S2** (append giornaliero) | `incremental`, `append` | `TS_INSERIMENTO` | eventi/inserimenti puntuali (es. `LEGAME_PRATICA_CONTROPARTE`, `SEGNALAZIONI_ANAGRAFICHE`, `ANTIFRODE.*`, `GIORNI_SCADUTO`) |
| **S3** (append mensile) | `incremental`, `append` | `DT_OSSERVAZIONE`, pre_hook `delete_month()` | consolidati di fine mese (es. `PRATICA_M`, `SALDO_CONTABILE_M`) |
| **S4** (attualizzato) | `incremental`, `insert_overwrite` | — | stato corrente, full rebuild (es. `ANAGRAFICA_CONTROPARTE`, `PRATICA`, `CESSIONI`, tutte le `SWORD.*`) |

Regola d'ordine colonne (da [[caricamento-layer-l2]]): campi di storicizzazione subito dopo la PK funzionale, `LASTMODIFIEDDATA` sempre in coda.

## Due implementazioni di S1 coesistenti nel codice

Verificato che il pattern S1 è implementato in due modi differenti nella stessa area di codice:

1. **Bespoke/hand-rolled** (es. `variazioni_anagrafiche.sql`, `indirizzi_postalizzazione.sql`): CTE esplicite per dedup via hash (`{{ hash_cols([...]) }}` + `QUALIFY ... IS DISTINCT FROM LAG(...)`) e calcolo manuale di `TS_FINE_VALIDITA` via `{{ ts_fine_validita(...) }}`.
2. **Basata su macro condivisa** (es. `wfl_istanza.sql`, ONBOARDING): usa direttamente `{{ is_incremental_S1('CD_ISTANZA') }}` + `{{ ts_fine_validita(...) }}` senza CTE di dedup-hash esplicite (la macro `is_incremental_S1` fa QUALIFY/collasso duplicati internamente, ma con logica leggermente diversa da quella hand-rolled — non è confermato che producano risultati identici in tutti i casi).

Non è chiaro se questa doppia implementazione sia intenzionale (macro introdotta più tardi, modelli vecchi non migrati) o un problema di consistenza — segnalato in [[inconsistenze-doc-vs-codice]].

## query_tag: copertura incompleta

Il `query_tag` (`'{"app": "DBT", "schema": "L2_<AREA>", "entita": "<NOME>"}'`) è dichiarato **obbligatorio** in [[guida-sviluppo]] (checklist pre-rilascio), ma nel codice reale:

- **Assente del tutto** in ANAGR_CONTROPARTE, ANTIFRODE, ASSICURAZIONI, GESTIONE_CREDITI, ONBOARDING, PRODOTTO, PRODOTTO_M, SWORD (circa metà del progetto, inclusa l'area più documentata).
- **Presente ma con `schema` errato**: tutti i 6 modelli di CARTE dichiarano `schema: "L2_PRODOTTO"` invece di `L2_CARTE`; i 2 modelli di PROVVIGIONI_RAPPEL dichiarano `schema: "L2_MAIN"` (né `L2_PROVVIGIONI_RAPPEL` né un'area xlsx nota) **e sono commentati con `#`** (quindi disattivi).
- **Presente e coerente**: RISCHI_ADEMPIMENTI e SALDI (schema = nome cartella, corretto).
- Un caso di `entita` non allineata al nome modello: `indice_rischio_m.yml` ha `entita: "INDICE_RISCHIO"` (manca `_M`).

Dettaglio completo in [[inconsistenze-doc-vs-codice]].

## Gestione cancellazioni: due approcci non equivalenti

- **`pre_hook: delete_l2(...)`**: DELETE fisica reale in `{{ this }}` per le chiavi con `FL_DELETED='Y'` più recenti del max `LASTMODIFIEDDATA` in target (approccio prescritto da [[guida-sviluppo]]).
- **Solo filtro `WHERE FL_DELETED = 'N'`** nel SELECT del modello, senza alcun DELETE fisico sulle righe già caricate in precedenza e ora cancellate (visto in `ANTIFRODE.archivio_tessere` e altri modelli senza `delete_l2`).

Questi due approcci **non sono equivalenti**: il secondo lascia righe stale nel target quando una chiave viene cancellata dopo essere già stata caricata. Vedi [[cancellazioni-fl-deleted]] e [[inconsistenze-doc-vs-codice]].

## Collegamenti

- [[caricamento-layer-l2]], [[guida-sviluppo]]
- [[progressivo-pk-e-progressivo-controparte]]
- [[cancellazioni-fl-deleted]]
- [[macro-catalogo-dbt]]
- [[inconsistenze-doc-vs-codice]]
