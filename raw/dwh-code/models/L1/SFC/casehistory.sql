select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(IsDeleted AS BOOLEAN) AS isdeleted,
  TRY_CAST(Case_ExternalKey__c AS VARCHAR(255)) AS case_externalkey__c,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR(255)) AS createdby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(CreatedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CreatedDate,
  TRY_CAST(Field AS VARCHAR(255)) AS field,
  TRY_CAST(DataType AS VARCHAR(255)) AS datatype,
  TRY_CAST(OldValue AS VARCHAR(255)) AS oldvalue,
  TRY_CAST(NewValue AS VARCHAR(255)) AS newvalue
from {{ source('source_l0','casehistory') }}
