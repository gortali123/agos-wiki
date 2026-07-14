select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(Account_ExternalKey__c AS VARCHAR(255)) AS account_externalkey__c,
  TRY_CAST(Name AS VARCHAR(255)) AS name,
  TRY_CAST(Iniziativa__r_IDIniziativa__c AS VARCHAR(255)) AS iniziativa__r_idiniziativa__c,
  TRY_CAST(Stato__c AS VARCHAR(255)) AS stato__c,
  TRY_CAST(StatoIniziativa__c AS VARCHAR(255)) AS statoiniziativa__c,
  TRY_TO_DATE(ScadenzaIniziativa__c, 'DD/MM/YYYY') AS scadenzainiziativa__c,
  TRY_CAST(EsitoDealer__c AS VARCHAR(255)) AS esitodealer__c,
  TRY_CAST(MyRecordIniziativa__c AS VARCHAR(255)) AS myrecordiniziativa__c,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR(255)) AS createdby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(CreatedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CreatedDate,
  TRY_CAST(LastModifiedBy_FederationIdentifier AS VARCHAR(255)) AS lastmodifiedby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(LastModifiedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS LastModifiedDate,
  TRY_CAST(NomeInziativa__c AS VARCHAR(255)) AS nomeinziativa__c,
  TRY_CAST(Rete__c AS VARCHAR(255)) AS rete__c
from {{ source('source_l0','membroiniziativa__c') }}
