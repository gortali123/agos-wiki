select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(DOCID_MD AS VARCHAR(20)) AS docid_md,
  TRY_CAST(CODICEPRATICA AS VARCHAR(20)) AS codicepratica,
  TRY_CAST(NUMEROPAGINE AS NUMBER(5,0)) AS numeropagine,
  TRY_CAST(CANALEDOC AS VARCHAR(30)) AS canaledoc,
  TRY_TO_TIMESTAMP(DATARICEZIONE, 'DD/MM/YYYY HH24:MI') AS dataricezione, 
  TRY_TO_TIMESTAMP(DATACARICAMENTO, 'DD/MM/YYYY HH24:MI') AS datacaricamento, -- casting ad hoc per formati datatime specifici
  TRY_CAST(SLA_in_gg AS NUMBER(10)) AS sla_in_gg
from {{ source('source_l0','microdata_sla') }}
