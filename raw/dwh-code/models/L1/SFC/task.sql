select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(Owner_FederationIdentifier AS VARCHAR(255)) AS owner_federationidentifier,
  TRY_CAST(Description AS VARCHAR(3200)) AS description,
  TRY_CAST(What_Case_ExternalKey__c AS VARCHAR(255)) AS what_case_externalkey__c,
  TRY_CAST(What_Account_ExternalKey__c AS VARCHAR(255)) AS what_account_externalkey__c,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR(255)) AS createdby_federationidentifier,
  TRY_CAST(Subject AS VARCHAR(255)) AS subject,
  TRY_CAST(Priority AS VARCHAR(255)) AS priority,
  TRY_TO_TIMESTAMP_TZ(ActivityDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS ActivityDate,
  TRY_CAST(Status AS VARCHAR(255)) AS status,
  TRY_CAST(LastModifiedBy_FederationIdentifier AS VARCHAR(255)) AS lastmodifiedby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(CreatedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CreatedDate,
  TRY_TO_TIMESTAMP_TZ(LastModifiedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS LastModifiedDate,
  TRY_TO_TIMESTAMP_TZ(CompletedDateTime, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CompletedDateTime,
  TRY_CAST(RecordType_Name AS VARCHAR(255)) AS recordtype_name
from {{ source('source_l0','task') }}
