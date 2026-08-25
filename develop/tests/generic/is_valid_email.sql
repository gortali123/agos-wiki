{% test is_valid_email(model, column_name) %}

select
  '{{ run_started_at }}' as ts_started_at,
  'is_valid_email' as ds_nome_test,
  '{{ model.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  object_construct('{{ column_name }}', {{ column_name }}::varchar) as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from {{ model }}
where {{ custom_is_not_null(column_name) }}
  and not regexp_like({{ column_name }}, '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$')

{% endtest %}
