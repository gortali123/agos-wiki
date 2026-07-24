select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(IsDeleted AS BOOLEAN) AS isdeleted,
  TRY_CAST(Case_Id AS VARCHAR) AS case_id,
  TRY_CAST(Case_CaseNumber AS VARCHAR(255)) AS case_casenumber,
  TRY_CAST(CreatedDate AS TIMESTAMP_NTZ) AS CreatedDate,
  TRY_CAST(Field AS VARCHAR) AS field,
  TRY_CAST(DataType AS VARCHAR) AS datatype,
  TRY_CAST(OldValue AS VARCHAR(255)) AS oldvalue,
  TRY_CAST(NewValue AS VARCHAR(255)) AS newvalue,
  TRY_CAST(CreatedById AS VARCHAR) AS createdbyid
from {{ source('source_l0','casehistory') }}
