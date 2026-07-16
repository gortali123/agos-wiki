{% macro call_proc_report_fondi_masterscale() %}

    {%- set last_month = (modules.datetime.date.today().replace(day=1, month=3) - modules.datetime.timedelta(days=1)).strftime('%Y%m') -%} -- togliere il replace che forza il 1/03/2026

    {{ log("Creazione report per il mese: " ~ last_month, info=True) }}

    {% set query %}
        -- YYYYMM
        CALL {{ env_var('DBT_DATABASE') }}.L3_BASILEA.PR_GENERATE_REPORT_FONDI_MASTERSCALE('{{last_month}}')

    {% endset %}

    {% do run_query(query) %}

    -- dbt run-operation call_proc_report_fondi_masterscale'

{% endmacro %}

