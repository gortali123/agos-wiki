---
title: "Bug: delete_l2 fallisce al primo run/full-refresh di un'entità"
type: query
tags: [layer/L2, cancellazioni, bug, macro]
updated: 2026-07-09
---

# Domanda

`raw/dwh-code/macros/logic_delete/delete_l2.sql` non funziona se è il primo run di un'entità. Perché, e cosa si rompe esattamente?

# Diagnosi

Confermato leggendo il codice (verificato 2026-07-09):

```sql
{% macro delete_l2(source_name, tgt_keys, src_keys) %}
{%- set source_table = ref(source_name) -%}
DELETE FROM {{ this }} tgt
WHERE EXISTS (
  SELECT 1
  FROM {{ source_table }} src
  WHERE src.FL_DELETED = 'Y'
    AND src.TS_DELETED > (
      SELECT COALESCE(MAX(LASTMODIFIEDDATA), '1900-01-01'::TIMESTAMP_NTZ)
      FROM {{ this }}
    )
  ...
)
{% endmacro %}
```

Nessun guard `{% if is_incremental() %}` nella macro, né nei chiamanti — verificato su tutti i modelli che la usano come `pre_hook` (`variazioni_anagrafiche.yml`, `variazioni_anagrafiche_day.yml`, `indirizzi_postalizzazione.yml`, `carte_autorizzativo.yml`, `carte_utilizzi.yml`, `wfl_*.yml` in ONBOARDING, `*_m.yml` in RISCHI_ADEMPIMENTI, `legame_ditte_individuali.yml`, `segnalazioni_anagrafiche.yml`): nessuno la condiziona, la chiamano sempre come pre-hook incondizionato.

`pre_hook` su un modello `materialized: incremental` viene eseguito **prima** della SQL principale del modello, quindi anche prima che dbt crei la tabella target quando questa non esiste ancora — cioè al primo run dell'entità (o dopo un `--full-refresh`, che droppa e ricrea la tabella). In quel momento `{{ this }}` è un nome di relazione che non esiste ancora su Snowflake:

- `DELETE FROM {{ this }} tgt` fallisce a runtime con "object does not exist" (o equivalente) — la tabella non è mai stata creata;
- anche la subquery `SELECT COALESCE(MAX(LASTMODIFIEDDATA), ...) FROM {{ this }}` avrebbe lo stesso problema, indipendentemente dal `DELETE` esterno.

Il modello quindi fallisce a costruirsi la prima volta (o dopo full-refresh) per qualunque entità che usi questo pre-hook — non un edge case raro, ma il primo run di ogni nuova tabella S1/S2 che segue questo pattern.

# Causa

La macro assume implicitamente `is_incremental() == true`, cioè che la tabella target esista già, ma non lo verifica. Non è un problema del pattern di cancellazione in sé (fisicamente ha senso solo su un target già popolato) — è la mancanza del guard che lo rende un'operazione sempre eseguita anche quando non ha senso eseguirla.

# Fix proposto

Aggiungere il guard `{% if is_incremental() %}` dentro la macro stessa (non nei singoli `pre_hook` dei modelli, per non dover ripetere il fix su ~15 file):

```sql
{% macro delete_l2(source_name, tgt_keys, src_keys) %}
{%- set source_table = ref(source_name) -%}
{%- if is_incremental() %}
DELETE FROM {{ this }} tgt
WHERE EXISTS (
  ...
)
{%- endif %}
{% endmacro %}
```

Coerente con il pattern già usato altrove nel repo (`is_incremental_S1`, e i vari `{% if is_incremental() %}` nei modelli SCD2 proposti in [[ottimizzazione-variazioni-anagrafiche-scd2]], [[ottimizzazione-indirizzi-postalizzazione-scd2]], [[ottimizzazione-variazioni-anagrafiche-day-scd2]]) — `is_incremental()` è già la funzione dbt standard per "il target esiste e non è un full-refresh", esattamente la condizione mancante qui.

Macro completa corretta: [[delete_l2_fix.sql|queries/delete_l2_fix.sql]] — unica modifica rispetto all'originale, il guard attorno al `DELETE`; firma e logica di confronto chiavi invariate, nessun cambio lato chiamante (i ~15 `pre_hook` che la usano restano identici).

# Impatto se non corretto

Ogni modello S1/S2 che usa `delete_l2` come pre-hook fallisce al primo `dbt run` (tabella non ancora esistente) e a ogni `dbt run --full-refresh` successivo. Va verificato se in pratica questo sia già stato mitigato "a mano" nel repo live (es. primo run senza il pre-hook, poi aggiunto dopo) — non verificabile dallo snapshot `raw/dwh-code/`, da confermare con l'utente/team.

# Stato

Bug identificato leggendo il codice nello snapshot locale (2026-07-09), non ancora verificato contro un run reale né discusso con il team che gestisce `dwh-x-dbt`. Fix pronto in [[delete_l2_fix.sql|queries/delete_l2_fix.sql]] (non applicato nel repo live, fuori scope della wiki che non modifica `raw/`) — da portare in `dwh-x-dbt` e testare su un'entità nuova al primo run.
