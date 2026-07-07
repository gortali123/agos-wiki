{% macro is_incremental_S1(partition_by, ts_inizio='TS_INIZIO_VALIDITA', ts_fine='TS_FINE_VALIDITA', lastmodified='LASTMODIFIEDDATA', hashed_cols='HASHED_COLS', order_extra='') %}
{% if is_incremental() %}
WHERE {{ lastmodified }} > (SELECT COALESCE(MAX({{ lastmodified }}),'1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
OR (
    {{ ts_fine }} > (SELECT COALESCE(MAX({{ ts_inizio }}),'1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    AND {{ ts_fine }} < TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
    )
{% endif %}
QUALIFY {{ hashed_cols }} IS DISTINCT FROM LAG({{ hashed_cols }}) OVER (
    PARTITION BY {{ partition_by }} ORDER BY {{ ts_inizio }}{% if order_extra %}, {{ order_extra }}{% endif %}
)
{% endmacro %}
