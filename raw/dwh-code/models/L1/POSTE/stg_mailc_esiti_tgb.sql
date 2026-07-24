select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(ID_POSTALIZZAZIONE AS NUMBER(8,0)) AS id_postalizzazione,
  TRY_CAST(ID_SAP AS NUMBER(8,0)) AS id_sap,
  TRY_TO_DATE(DT_ACCETTAZIONE, 'DDMMYYYY') AS dt_accettazione,
  TRY_CAST(DS_CENTRO_ACCETTANTE AS VARCHAR(100)) AS ds_centro_accettante,
  TRY_TO_DATE(DT_PROSSIM_TENTATIVO_CONSEGNA, 'DDMMYYYY') AS dt_prossim_tentativo_consegna,
  TRY_CAST(CAP AS VARCHAR(8)) AS cap,
  TRY_CAST(DS_LOCALITA AS VARCHAR(100)) AS ds_localita,
  TRY_CAST(_2DCOMM AS VARCHAR(100)) AS _2dcomm,
  TRY_CAST(CD_ESITO AS VARCHAR(10)) AS cd_esito,
  TRY_CAST(DS_CAUSALE AS VARCHAR(50)) AS ds_causale,
  TRY_CAST(ANOMALIA AS VARCHAR(255)) AS anomalia
from {{ source('source_l0','mailc_esiti_tgb') }}
