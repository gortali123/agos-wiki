select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(VIN17 AS VARCHAR(30)) AS vin17,
  TRY_CAST(CO2_VALUE AS NUMBER(10,0)) AS co2_value,
  TRY_CAST(BRAND_TEXT AS VARCHAR(50)) AS brand_text,
  TRY_CAST(MODEL_TEXT AS VARCHAR(50)) AS model_text,
  TRY_CAST(VEHICLE_SEGMENT AS VARCHAR(50)) AS vehicle_segment,
  TRY_CAST(BODYSTYLE AS VARCHAR(50)) AS bodystyle,
  TRY_CAST(FUELTYPE AS VARCHAR(30)) AS fueltype,
  TRY_CAST(EU_VEHICLE_CLASS AS VARCHAR(10)) AS eu_vehicle_class,
  TRY_CAST(REGS AS NUMBER(10,0)) AS regs,
  TRY_CAST(REG_MONTH AS NUMBER(10,0)) AS reg_month,
  TRY_CAST(INFO_TECH AS VARCHAR(1000)) AS info_tech
from {{ source('source_l0','telaio_per_agos') }}
