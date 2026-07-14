select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(Owner_FederationIdentifier AS VARCHAR(255)) AS owner_federationidentifier,
  TRY_CAST(IsDeleted AS BOOLEAN) AS isdeleted,
  TRY_CAST(Name AS VARCHAR(255)) AS name,
  TRY_TO_TIMESTAMP_TZ(CreatedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CreatedDate,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR(255)) AS createdby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(LastModifiedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS LastModifiedDate,
  TRY_CAST(LastModifiedBy_FederationIdentifier AS VARCHAR(255)) AS lastmodifiedby_federationidentifier,
  TRY_TO_DATE(DataInizio__c, 'DD/MM/YYYY') AS datainizio__c,
  TRY_TO_DATE(DataFine__c, 'DD/MM/YYYY') AS datafine__c,
  TRY_CAST(Descrizione__c AS VARCHAR(32768)) AS descrizione__c,
  TRY_CAST(IDIniziativa__c AS VARCHAR(255)) AS idiniziativa__c,
  TRY_CAST(Rete__c AS VARCHAR(255)) AS rete__c,
  TRY_CAST(Stato__c AS VARCHAR(255)) AS stato__c
from {{ source('source_l0','iniziativa__c') }}
