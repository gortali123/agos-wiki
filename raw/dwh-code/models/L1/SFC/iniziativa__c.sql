select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_TO_DATE(DataInizio__c, 'YYYY-MM-DD HH24:MI:SS') AS datainizio__c,
  TRY_TO_DATE(DataFine__c, 'YYYY-MM-DD HH24:MI:SS') AS datafine__c,
  TRY_CAST(Descrizione__c AS VARCHAR) AS descrizione__c,
  TRY_CAST(IDIniziativa__c AS VARCHAR(255)) AS idiniziativa__c,
  TRY_CAST(Stato__c AS VARCHAR(255)) AS stato__c,
  TRY_CAST(Name AS VARCHAR(255)) AS name,
  TRY_CAST(CreatedById AS VARCHAR) AS createdbyid,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR) AS createdby_federationidentifier,
  TRY_CAST(OwnerId AS VARCHAR) AS ownerid,
  TRY_CAST(IsDeleted AS BOOLEAN) AS isdeleted,
  TRY_CAST(CreatedDate AS TIMESTAMP_NTZ) AS createddate,
  TRY_CAST(Rete__c AS VARCHAR) AS rete__c,
  TRY_CAST(LastModifiedById AS VARCHAR) AS lastmodifiedbyid,
  TRY_CAST(LastModifiedDate AS TIMESTAMP_NTZ) AS lastmodifieddate
from {{ source('source_l0','iniziativa__c') }}
