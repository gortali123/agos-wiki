---
title: Data Quality Framework (proposta, config-driven)
type: concept
tags: [layer/L2, layer/L3, dbt, data-quality, proposta]
updated: 2026-08-20
---

Proposta (non ancora implementata, solo design) per gestire i test di data quality su L2/L3 in modo dichiarativo, tramite una tabella di configurazione Snowflake, restando dentro il meccanismo nativo dei test dbt — nessuna tabella di risultati custom, nessun runner parallelo.

## Requisiti stabiliti con l'utente (2026-08-20)

1. I test devono girare **sempre tramite dbt** (`dbt build` quando il test deve girare a ogni run dopo il modello, `dbt test` quando gira a cadenza separata/più rada).
2. I risultati **non** vanno in una tabella dedicata: devono confluire nella stessa event table dei test dbt "classici" (vedi [[cancellazioni-fl-deleted]]/log_run_results già in uso nel progetto — meccanismo esistente, non toccato da questa proposta). Non interessano gli `store_failures`, solo l'esito pass/fail.
3. I test devono essere **custom** (non solo i tipi standard tipo `not_null`/`unique` di dbt/dbt_utils).
4. Ogni riga di configurazione può avere una **severity** propria (`warn`/`error`), mappata sul `config.severity` nativo di dbt.

## Idea chiave (corretta il 2026-08-25 dopo test reale — vedi sotto)

L'idea iniziale era: generare dinamicamente i blocchi `tests:`/`data_tests:` per colonna dentro lo `schema.yml`, con un `{% for %}` Jinja a livello di documento che itera sulle righe di config. **Non funziona**: dbt fa un primo parse YAML del file *grezzo* (senza Jinja) per capirne la struttura, e solo *dopo*, dentro valori già validi (es. `description: "{{ doc(...) }}"`), applica il rendering Jinja. Un `{% set %}`/`{% for %}` a livello di documento, fuori da un valore YAML, rompe subito quel primo parse — verificato con un `dbt build` reale, errore `while scanning for the next token found character that cannot start any token` sulla riga con `{% set %}`.

La generazione dinamica va quindi spostata **dentro il corpo di un generic test** (che è codice Jinja compilato normalmente, non soggetto al vincolo del primo parse grezzo), non nella struttura dello `schema.yml`. Lo `schema.yml` resta completamente statico: un solo riferimento al test, dichiarato una volta a livello di modello. Aggiungere/rimuovere un check si fa solo in `TECH.CFG_DQ_TEST_CONFIG`, mai più toccando lo yml. I test generati restano nodi dbt normali → finiscono in `run_results.json` come qualsiasi altro test, quindi il meccanismo di logging verso l'event table esistente li intercetta senza modifiche.

## Schema di configurazione

Nome tabella/colonne corretto il 2026-08-25 per seguire la convenzione reale delle tabelle tecniche `TECH.CFG_*` (vedi `raw/dwh-code/macros/generate_models/generate_yaml.sql`, che legge da `TECH.CFG_L1_SCHEMA`/`CFG_L1_CLUSTER_STO`/`CFG_L1_DATAMASK`/`CFG_L0_L1_MODULO_LOOKUP`): schema `TECH`, tabella `CFG_` + maiuscolo, colonne con prefisso per tipo (`DS_` stringa, `FL_` flag Y/N, `GN_` per VARIANT — come `gn_failure_info` in `try_cast.sql`).

```sql
CREATE TABLE TECH.CFG_DQ_TEST_CONFIG (
    DS_MODELLO     VARCHAR,     -- nome modello dbt, es. 'L2_ANAGR_CONTROPARTE'
    DS_COLONNA     VARCHAR,     -- null per test a livello tabella
    DS_TEST_TYPE   VARCHAR,     -- nome del generic test custom, es. 'dq_not_null', 'dq_custom_sql'
    GN_PARAMS      VARIANT,     -- parametri specifici del test type, in json
    DS_SEVERITY    VARCHAR,     -- 'warn' | 'error' (letterale dbt config.severity)
    FL_ACTIVE      VARCHAR(1) DEFAULT 'Y'  -- Y/N, non booleano (coerente con FL_DELETED e gli altri FL_ del progetto)
);
```

## Generic test config-driven, dichiarato per colonna

Un solo generic test, `dq_config_driven(model, column_name)`, in `tests/generic/` (convenzione reale del repo — vedi `raw/dwh-code/tests/generic/try_cast.sql`, `primary_key.sql`). Dichiarato **sotto ogni colonna** che deve avere un check (una riga `data_tests:` per colonna, come un test dbt normale) — non a livello di modello: `column_name` arriva automaticamente da dbt (stesso meccanismo di `not_null`/`unique`), non va passato a mano. Keyword `data_tests:`, non `tests:` (deprecata) — il repo vendorizzato usa sistematicamente `data_tests:` (vedi `raw/dwh-code/models/L0/ADOBE/*.yml`).

```sql
{% test dq_config_driven(model, column_name) %}

{%- if not execute -%}
  select null as dq_failures where false
{%- else -%}

{%- set cfg_rows = dbt_utils.get_query_results_as_dict(
    "select ds_test_type, ds_severity from " ~ env_var('DBT_DATABASE') ~ ".tech.cfg_dq_test_config"
    ~ " where ds_modello = '" ~ model.identifier ~ "' and ds_colonna = '" ~ column_name ~ "' and fl_active = 'Y'"
) -%}

{%- if cfg_rows['DS_TEST_TYPE'] | length == 0 -%}
  select null as dq_failures where false
{%- else -%}

  {%- set test_type = cfg_rows['DS_TEST_TYPE'][0] -%}
  {%- set severity = cfg_rows['DS_SEVERITY'][0] -%}
  {{ config(severity = severity) }}

  {%- if test_type == 'is_valid_email' -%}
    {%- set condition = column_name ~ " is not null and not regexp_like(" ~ column_name ~ ", '^[^@\\\\s]+@[^@\\\\s]+\\\\.[^@\\\\s]+$')" -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("dq_config_driven: DS_TEST_TYPE non gestito: " ~ test_type) }}
  {%- endif -%}

  select * from {{ model }} where {{ condition }}

{%- endif -%}
{%- endif -%}

{% endtest %}
```

```yaml
models:
  - name: anagrafica_controparte
    columns:
      - name: DS_EMAIL
        data_type: VARCHAR(50)
        data_tests:
          - dq_config_driven
      # ... resto delle colonne, invariato — data_tests solo dove serve un check
```

Punti chiave del design (rivisto più volte con l'utente il 2026-08-25):

- **Nessuna generazione dinamica di struttura YAML.** Lo yml resta statico: aggiungere/togliere un check su una colonna richiede comunque una riga `data_tests: - dq_config_driven` in quella colonna (necessità strutturale — dbt deve sapere staticamente a quali nodi attaccare un test), ma **né il `test_type` né la `severity` sono scritti nello yml**: vivono solo in `TECH.CFG_DQ_TEST_CONFIG`, letti a runtime dal test.
- **Severity impostata dinamicamente**: `{{ config(severity = severity) }}` chiamato dentro il corpo del test, con `severity` letta da `DS_SEVERITY` in config — nessuna duplicazione warn/error tra yml e tabella. Cambiare la severity di un check si fa **solo** in config, senza toccare lo yml. Da verificare alla prima esecuzione reale: `config()` chiamato dinamicamente dentro un generic test (non un model `.sql`) dovrebbe funzionare perché i test sono interamente Jinja-renderizzati, ma non ancora confermato con un `dbt build` su questa versione.
- **`{% if not execute %}`**: evita che `get_query_results_as_dict` giri (fallendo) durante fasi di compile-only senza connessione attiva (es. `dbt parse`, generazione docs) — pattern già usato in `try_cast.sql` (`{% if execute %}`).
- **Dispatch per `DS_TEST_TYPE`** (non un `rule_expr` SQL libero in config): la tabella di config resta quella già definita sotto (`DS_MODELLO`/`DS_COLONNA`/`DS_TEST_TYPE`/`GN_PARAMS`/`DS_SEVERITY`/`FL_ACTIVE`), quindi aggiungere un nuovo `test_type` richiede comunque un ramo `{% if %}` in più nel macro — trade-off accettato per restare aderenti allo schema già scelto, a fronte di un rule-engine generico (SQL libero via placeholder `{{col}}`) discusso e scartato.

`dbt build` esegue questi test sempre dopo il modello; `dbt test` li rilancia isolatamente quando serve — nessun runner o hook aggiuntivo.

## Punto aperto / da verificare in fase di implementazione

`get_query_results_as_dict` gira a **compile time**: serve una connessione al warehouse attiva durante l'esecuzione del test (mitigato dal guard `{% if not execute %}` per le fasi compile-only). Se la config cambia, il nuovo test si applica dal prossimo `dbt build`/`dbt test` — non serve però più un ri-parse/ri-compile dello yml, perché la lettura della config avviene a runtime dentro il test stesso, non durante il parsing della struttura del modello.

## Pilota: check formato email su ANAGRAFICA_CONTROPARTE.DS_EMAIL (2026-08-25)

Primo test reale, in `develop/`, non ancora portato upstream. Iterato più volte con l'utente dopo un `dbt build` reale che ha fatto emergere il vincolo sopra:

- `develop/tests/generic/dq_config_driven.sql` — generic test unico, a livello di modello, come descritto sopra.
- `develop/models/L2/ANAGR_CONTROPARTE/anagrafica_controparte.yml` — copia completa dello schema.yml reale (tutte le colonne/data_type/constraints), completamente statica, con solo due `data_tests:` a livello di modello che richiamano `dq_config_driven` (warn/error).
- `develop/setup/dq_test_config.sql` — `CREATE TABLE TECH.CFG_DQ_TEST_CONFIG` (schema sotto, prefissi `DS_`/`FL_`/`GN_` coerenti col resto del progetto) + riga pilota: `('anagrafica_controparte', 'DS_EMAIL', 'is_valid_email', null, 'warn', 'Y')` — nota: `DS_MODELLO` valorizzato col nome del modello dbt (`anagrafica_controparte`), non con lo schema Snowflake (`L2_ANAGR_CONTROPARTE`, usato invece nel `query_tag`) — i due sono stati inizialmente confusi durante il pilota.

File obsoleti rimossi durante l'iterazione (primi tentativi con generazione per-colonna nello yml, poi scartati per il vincolo sopra): `develop/tests/generic/is_valid_email.sql`, `develop/macros/data_quality/dq_tests_block.sql`.

Non ancora rieseguito con `dbt build` dopo l'ultima revisione (il giro precedente aveva fallito, causa che ha portato alla riscrittura sopra) — da riverificare.

## Stato

Design confermato 2026-08-20; riprogettato il 2026-08-25 dopo un `dbt build` reale che ha invalidato l'approccio "yml generato dinamicamente" — nuovo approccio "test config-driven a livello di modello" verificato solo a livello di lettura, non ancora ri-eseguito con dbt dopo la riscrittura.
