SELECT
    T.<pk_col> AS <CD_PK>,
    T.<col1> AS <CAMPO1>,
    T.<col2> AS <CAMPO2>
FROM {{ ref('<L1_table>') }} T
