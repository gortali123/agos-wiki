select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CD_SOC_CONTB_SAP AS VARCHAR(4)) AS cd_soc_contb_sap,
  TRY_CAST(TP_PROD_SAP AS VARCHAR(3)) AS tp_prod_sap,
  TRY_CAST(CD_OPERAZIONE_SAP AS VARCHAR(13)) AS cd_operazione_sap,
  TRY_TO_DATE(DT_OSSERVAZIONE, 'DD/MM/YYYY') AS dt_osservazione,
  TRY_CAST(REPLACE(REPLACE(EU_INIZIALE_FIN, '.', ''), ',', '.') AS NUMBER(20,2)) AS eu_iniziale_fin,
  TRY_CAST(REPLACE(REPLACE(EU_NOMINALE, '.', ''), ',', '.') AS NUMBER(20,2)) AS eu_nominale,
  TRY_TO_DATE(DT_INIZ_VALI, 'DD/MM/YYYY') AS dt_iniz_vali,
  TRY_TO_DATE(DT_FINE_VALI, 'DD/MM/YYYY') AS dt_fine_vali
from {{ source('source_l0','fin_att') }}



