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
  {%- for i in range(tgt_keys | length) %}
  {%- set tgt_col = tgt_keys[i] %}
  {%- set src_col = src_keys[i] %}
    {%- if tgt_col.startswith('DT_') %}
    AND tgt.{{ tgt_col }} = {{ custom_to_date('src.' ~ src_col) }}
    {%- elif tgt_col.startswith('TS_') %}
    AND tgt.{{ tgt_col }} = {{ custom_to_timestamp_ntz('src.' ~ src_col) }}
    {%- else %}
    AND tgt.{{ tgt_col }} = src.{{ src_col }}
    {%- endif %}
  {%- endfor %}
)
{% endmacro %}