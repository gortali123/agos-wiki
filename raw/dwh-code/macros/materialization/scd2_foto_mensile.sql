{#
  scd2_foto_mensile
  =================
  Storicizzazione SCD2 a "foto mensile" ancorata al FINE MESE di riferimento (merge).

    Il modello NON apre il WITH. Passa:
      - src_sql   : SQL della proiezione L2->L3, UNA RIGA PER VERSIONE (chiave, mese).
                    La 1a colonna deve essere il ts_col (es. DT_OSSERVAZIONE).
      - pre_ctes  : (opzionale) CTE di appoggio gia' terminate da virgola, es:
                    "prat_unpivot AS (...), altra_cte AS (...),"
      - key_cols  : chiave naturale.
      - ts_col    : colonna "as-of" della versione sorgente.
    La macro apre il WITH, introspeziona src_sql con run_query (SELECT ... WHERE 1=0,
    solo metadata) e ricava:
    (entrambe sovrascrivibili passando esplicitamente biz_cols / payload_cols).

  USO:
      {{ scd2_foto_mensile(
            src_sql  = src_sql,
            key_cols = key_cols,
            ts_col   = 'DT_OSSERVAZIONE',
            pre_ctes = pre_ctes        {# opzionale #}
      ) }}

  PREREQUISITI del modello:
    materialized = incremental, incremental_strategy = merge,
    unique_key = key_cols + [dt_inizio]

  SEMANTICA:
    * full-refresh   -> ricostruzione storica di TUTTE le finestre passate;
    * run incrementale -> passo in avanti sul solo mese chiuso piu' recente (merge).
    Confronto SEMPRE sul solo PAYLOAD via HASH. DT_FINE chiusa = DT_INIZIO successiva.
#}
{% macro scd2_foto_mensile(
    src_sql,
    key_cols,
    ts_col='TS_INIZIO_VALIDITA',
    pre_ctes=none,
    biz_cols=none,
    payload_cols=none,
    ref_month_end=none,
    dt_inizio='DT_INIZIO_VALIDITA',
    dt_fine='DT_FINE_VALIDITA',
    fine_validita_max="TO_DATE('9999-12-31')"
) %}

{%- if src_sql is none -%}
    {{ exceptions.raise_compiler_error("scd2_foto_mensile: src_sql e' obbligatorio.") }}
{%- endif -%}

{%- set src_ref = '_scd2_src' -%}

{#- ===== biz_cols ===== -#}
{%- if biz_cols is none -%}
    {%- set biz_cols = [] -%}
    {%- if execute -%}
        {%- set probe -%}
            WITH {% if pre_ctes %}{{ pre_ctes }}
            {% endif %}{{ src_ref }} AS (
                {{ src_sql }}
            )
            SELECT * FROM {{ src_ref }} WHERE 1 = 0
        {%- endset -%}
        {%- set results = run_query(probe) -%}
        {%- set excluded = [ts_col | upper, dt_inizio | upper, dt_fine | upper] -%}
        {%- set biz_cols = results.columns | map(attribute='name') | reject('in', excluded) | list -%}
    {%- endif -%}
{%- endif -%}

{%- if payload_cols is none -%}
    {%- set payload_cols = biz_cols | reject('in', key_cols) | list -%}
{%- endif -%}

{%- set rme = ref_month_end if ref_month_end is not none else last_day_past_month() -%}

WITH {% if pre_ctes %}{{ pre_ctes }}
{% endif %}{{ src_ref }} AS (
    {{ src_sql }}
),
params AS (
    SELECT {{ rme }} AS REF_MONTH_END   -- fine del mese di riferimento (mese chiuso)
)

{% if is_incremental() %}

-- ===== PASSO IN AVANTI: solo il mese chiuso piu' recente (merge sullo stato aperto in target) =====

, snap AS (   -- foto a fine mese rif.: ultima versione per chiave entro REF_MONTH_END
    SELECT
        P.REF_MONTH_END,
        SP.*,
        {{ _scd2_hash(payload_cols, 'SP') }} AS PAYLOAD_HASH
    FROM {{ src_ref }} AS SP
    CROSS JOIN params AS P
    WHERE SP.{{ ts_col }} < DATEADD('day', 1, P.REF_MONTH_END)   -- effettivo entro fine mese rif.
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY {{ _scd2_cols(key_cols, 'SP') }}
        ORDER BY SP.{{ ts_col }} DESC
    ) = 1
),

open_win AS (   -- finestre attualmente aperte in target
    SELECT
        {{ _scd2_cols(biz_cols, 'T') }},
        T.{{ dt_inizio }},
        {{ _scd2_hash(payload_cols, 'T') }} AS OPEN_HASH
    FROM {{ this }} AS T
    WHERE T.{{ dt_fine }} = {{ fine_validita_max }}
),

new_rows AS (   -- chiave nuova o payload cambiato -> nuova finestra aperta a fine mese rif.
    SELECT
        {{ _scd2_cols_as(biz_cols, 'S') }},
        S.REF_MONTH_END AS {{ dt_inizio }},
        {{ fine_validita_max }} AS {{ dt_fine }}
    FROM snap AS S
    LEFT JOIN open_win AS O
      ON {{ _scd2_join('O', 'S', key_cols) }}
    WHERE O.{{ dt_inizio }} IS NULL                                                   -- chiave nuova
       OR (O.OPEN_HASH <> S.PAYLOAD_HASH AND S.REF_MONTH_END >= O.{{ dt_inizio }})    -- cambiata
),

close_rows AS (   -- per le sole chiavi cambiate: chiusura della finestra aperta a fine mese rif.
    SELECT
        {{ _scd2_cols_as(biz_cols, 'O') }},
        O.{{ dt_inizio }} AS {{ dt_inizio }},
        S.REF_MONTH_END AS {{ dt_fine }}
    FROM open_win AS O
    JOIN snap AS S
      ON {{ _scd2_join('O', 'S', key_cols) }}
    WHERE O.OPEN_HASH <> S.PAYLOAD_HASH
      AND S.REF_MONTH_END > O.{{ dt_inizio }}
),

emitted AS (
    SELECT * FROM new_rows
    UNION ALL
    SELECT * FROM close_rows
)

{% else %}

-- ===== RICOSTRUZIONE STORICA (full-refresh): TUTTE le finestre passate =====

, ver_dedup AS (   -- per (chiave, mese) tiene l'ultima versione = foto di fine mese di quel mese
    SELECT
        SP.*,
        LAST_DAY(CAST(SP.{{ ts_col }} AS DATE)) AS VERSION_MONTH_END,
        {{ _scd2_hash(payload_cols, 'SP') }} AS PAYLOAD_HASH
    FROM {{ src_ref }} AS SP
    CROSS JOIN params AS P
    WHERE LAST_DAY(CAST(SP.{{ ts_col }} AS DATE)) <= P.REF_MONTH_END   -- effettivo entro mese rif.
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY {{ _scd2_cols(key_cols, 'SP') }}, LAST_DAY(CAST(SP.{{ ts_col }} AS DATE))
        ORDER BY SP.{{ ts_col }} DESC
    ) = 1
),

win_starts AS (   -- apre finestra SOLO dove il payload L3 cambia (o prima apparizione della chiave)
    SELECT *
    FROM ver_dedup
    QUALIFY PAYLOAD_HASH IS DISTINCT FROM LAG(PAYLOAD_HASH) OVER (
        PARTITION BY {{ _scd2_cols(key_cols) }}
        ORDER BY VERSION_MONTH_END
    )
),

emitted AS (   -- DT_FINE = inizio della finestra successiva (LEAD), 9999 se ultima
    SELECT
        {{ _scd2_cols_as(biz_cols, 'W') }},
        W.VERSION_MONTH_END AS {{ dt_inizio }},
        COALESCE(
            LEAD(W.VERSION_MONTH_END) OVER (
                PARTITION BY {{ _scd2_cols(key_cols, 'W') }}
                ORDER BY W.VERSION_MONTH_END
            ),
            {{ fine_validita_max }}
        ) AS {{ dt_fine }}
    FROM win_starts AS W
)

{% endif %}

SELECT
    {{ _scd2_cols(biz_cols) }},
    {{ dt_inizio }},
    {{ dt_fine }}
FROM emitted

{% endmacro %}


{#- ----------------------------------------------------------------------- -#}
{#-  Helper privati (riuso interno alla macro): rendering di liste colonne.  -#}
{#- ----------------------------------------------------------------------- -#}

{# csv di colonne con prefisso opzionale:  SP.A, SP.B   oppure   A, B #}
{% macro _scd2_cols(cols, prefix='') -%}
{%- set p = (prefix ~ '.') if prefix else '' -%}
{%- for c in cols -%}{{ p }}{{ c }}{{ ', ' if not loop.last else '' }}{%- endfor -%}
{%- endmacro %}

{# csv con alias esplicito:  S.A AS A, S.B AS B  (per allineare le UNION ALL) #}
{% macro _scd2_cols_as(cols, prefix) -%}
{%- for c in cols -%}{{ prefix }}.{{ c }} AS {{ c }}{{ ', ' if not loop.last else '' }}{%- endfor -%}
{%- endmacro %}

{# condizione di join sulle chiavi:  O.K = S.K AND ... #}
{% macro _scd2_join(a, b, cols) -%}
{%- for c in cols -%}{{ a }}.{{ c }} = {{ b }}.{{ c }}{{ ' AND ' if not loop.last else '' }}{%- endfor -%}
{%- endmacro %}

{# HASH del payload con prefisso opzionale #}
{% macro _scd2_hash(cols, prefix='') -%}
{%- set p = (prefix ~ '.') if prefix else '' -%}
HASH({%- for c in cols -%}{{ p }}{{ c }}{{ ', ' if not loop.last else '' }}{%- endfor -%})
{%- endmacro %}