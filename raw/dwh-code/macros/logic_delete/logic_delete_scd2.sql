{% macro logic_delete_scd2() %}
  {% set deleted_table = this.identifier ~ '_deleted' %}

BEGIN;

UPDATE {{ this }} AS base
SET base.fl_deleted = 'Y'
FROM {{ source('source_l0', deleted_table) }} AS del
WHERE base.rowid = del.rowid;

UPDATE {{ this }} AS base
SET base.ts_fine_validita = src.lastmodifieddata::TIMESTAMP_NTZ,
    base.ts_deleted = src.lastmodifieddata::TIMESTAMP_NTZ
FROM (
    SELECT t.rowid, t.ts_fine_validita, del.lastmodifieddata
    FROM {{ this }} t
    INNER JOIN (
        SELECT rowid, MAX(ts_fine_validita) AS max_dt
        FROM {{ this }}
        GROUP BY rowid
    ) mx ON t.rowid = mx.rowid AND t.ts_fine_validita = mx.max_dt
    INNER JOIN {{ source('source_l0', deleted_table) }} del ON t.rowid = del.rowid
) src
WHERE base.rowid = src.rowid
  AND base.ts_fine_validita = src.ts_fine_validita;

COMMIT;

{% endmacro %}
