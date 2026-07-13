{% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', 'adb_arc') | first %}

with cast_results as (
  select
    object_construct(
      'DATASURVEY', iff(
        DATASURVEY is not null
        and TRY_TO_DATE(DATASURVEY, 'YYYYMMDD') is null,
        cast(DATASURVEY as varchar),
        null
      ),
      'IDSURVEY', iff(
        IDSURVEY is not null
        and TRY_CAST(IDSURVEY as VARCHAR(50)) is null,
        cast(IDSURVEY as varchar),
        null
      ),
      'CODICECONTROPARTE', iff(
        CODICECONTROPARTE is not null
        and TRY_CAST(CODICECONTROPARTE as VARCHAR(20)) is null,
        cast(CODICECONTROPARTE as varchar),
        null
      ),
      'CAMPIAGGIUNTIVI', iff(
        CAMPIAGGIUNTIVI is not null
        and TRY_CAST(CAMPIAGGIUNTIVI as VARCHAR(255)) is null,
        cast(CAMPIAGGIUNTIVI as varchar),
        null
      ),
      'COMMENTONPS', iff(
        COMMENTONPS is not null
        and TRY_CAST(COMMENTONPS as VARCHAR(500)) is null,
        cast(COMMENTONPS as varchar),
        null
      ),
      'NPS', iff(
        NPS is not null
        and TRY_CAST(NPS as VARCHAR(2)) is null,
        cast(NPS as varchar),
        null
      ),
      'CES', iff(
        CES is not null
        and TRY_CAST(CES as VARCHAR(50)) is null,
        cast(CES as varchar),
        null
      )
    ) as failure_info
  from {{ source('source_l0', 'adb_arc') }}
)

select
  '{{ run_started_at }}' as ts_started_at,
  'try_cast' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  'adb_arc' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from cast_results
where array_size(object_keys(failure_info)) > 0
