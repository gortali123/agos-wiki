{% macro logic_delete_merge() %}
  {% set deleted_table = this.identifier ~ '_deleted' %}

  UPDATE {{ this }} AS base
  SET base.fl_deleted = 'Y',
      base.ts_deleted = del.lastmodifieddata::TIMESTAMP_NTZ --{#'{{ run_started_at }}'::TIMESTAMP_NTZ#}
  FROM {{ source('source_l0', deleted_table) }} AS del
  WHERE base.rowid = del.rowid;

{% endmacro %}
