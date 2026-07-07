SELECT
    T.<pk_col> AS <CD_PK>,
    {{ custom_to_date('T.<dt_osservazione_col>') }} AS DT_OSSERVAZIONE,
    T.<col1> AS <CAMPO1>,
    T.<col2> AS <CAMPO2>
FROM {{ ref('<L1_table>') }} T

{% if is_incremental() %}
WHERE DT_OSSERVAZIONE = {{ get_dt_osservazione() }}
{% endif %}
