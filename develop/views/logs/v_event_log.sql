create or replace view AGOS_DEV_16000.LOGS.V_EVENT_LOG(
    DS_EXECUTION_TYPE,
    TS_STARTED_AT,
    NM_EXECUTION_TIME,
    DS_SCHEMA,
    DS_TABELLA,
    DS_STATUS,
    DS_TEST_NAME,
    NM_FAILURES,
    DS_MESSAGE,
    CD_RUN_DBT,
    CD_QUERY_SF
) as
  SELECT
    f.value:execution_type::VARCHAR             AS ds_execution_type,
    COALESCE(NULLIF(f.value:ts_started_at,'')::TIMESTAMP_NTZ, TIMESTAMP::TIMESTAMP_NTZ) AS ts_started_at,
    f.value:nm_execution_time::FLOAT            AS nm_execution_time,
    f.value:ds_schema::VARCHAR                  AS ds_schema,
    f.value:ds_tabella::VARCHAR                 AS ds_tabella,
    f.value:ds_status::VARCHAR                  AS ds_status,
    f.value:ds_test_name::VARCHAR               AS ds_test_name,
    f.value:nm_failures::INT                    AS nm_failures,
    f.value:ds_message::VARCHAR                 AS ds_message,
    f.value:cd_run_dbt::VARCHAR                 AS cd_run_dbt,
    f.value:cd_query_sf::VARCHAR                AS cd_query_sf
  FROM AGOS_DEV_16000.LOGS.EVENT_LOG,
  LATERAL FLATTEN(TRY_PARSE_JSON(VALUE::VARCHAR)) f
  WHERE record_type = 'LOG'
    AND RESOURCE_ATTRIBUTES:"snow.executable.name"::VARCHAR ILIKE 'LOG_DBT%'
  ORDER BY ts_started_at DESC;
