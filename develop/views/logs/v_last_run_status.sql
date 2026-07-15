create or replace view AGOS_DEV_16000.LOGS.V_LAST_RUN_STATUS(
    DS_SCHEMA,
    DS_TABELLA,
    TS_ULTIMO_RUN,
    MODEL_STATUS,
    TEST_STATUS,
    FAILURES
) as

with models_last_run as (
    select *
    from AGOS_DEV_16000.LOGS.V_EVENT_LOG
    where upper(ds_execution_type) = 'MODEL'
    qualify row_number() over (
        partition by ds_tabella
        order by ts_started_at desc
    ) = 1
)

, test_last_run as (
    select *
    from AGOS_DEV_16000.LOGS.V_EVENT_LOG
    where upper(ds_execution_type) = 'TEST'
    qualify row_number() over (
        partition by ds_tabella, ds_test_name
        order by ts_started_at desc
    ) = 1
)

, test_agg as (
    select
        ds_tabella,
        max(ds_schema) as ds_schema,
        max(ts_started_at) as ts_ultimo_test,
        case
            when count(case when upper(ds_status) = 'FAIL' then 1 end) > 0 then 'fail'
            when count(case when upper(ds_status) = 'WARN' then 1 end) > 0 then 'warn'
            else 'pass'
        end as ds_status_test,
        sum(nm_failures) as nm_failures
    from test_last_run
    group by ds_tabella
)

select
    coalesce(mlr.ds_schema, ta.ds_schema) as ds_schema,
    coalesce(mlr.ds_tabella, ta.ds_tabella) as ds_tabella,
    coalesce(mlr.ts_started_at, ta.ts_ultimo_test) as ts_ultimo_run,
    mlr.ds_status as model_status,
    ta.ds_status_test as test_status,
    coalesce(ta.nm_failures, 0) as failures
from models_last_run mlr
full outer join test_agg ta
    on upper(mlr.ds_tabella) = upper(ta.ds_tabella);
