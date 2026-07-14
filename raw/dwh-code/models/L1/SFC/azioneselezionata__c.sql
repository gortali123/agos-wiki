select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(CatalogoAzioni__r_Name AS VARCHAR(255)) AS catalogoazioni__r_name,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR(255)) AS createdby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(CreatedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CreatedDate,
  TRY_CAST(Descrizione__c AS VARCHAR(300)) AS descrizione__c, --era 255
  TRY_CAST(Iniziativa__r_IDIniziativa__c AS VARCHAR(255)) AS iniziativa__r_idiniziativa__c,
  TRY_CAST(LastModifiedBy_FederationIdentifier AS VARCHAR(255)) AS lastmodifiedby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(LastModifiedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS LastModifiedDate,
  TRY_CAST(Name AS VARCHAR(255)) AS name,
  TRY_CAST(Rete__c AS VARCHAR(255)) AS rete__c
from {{ source('source_l0','azioneselezionata__c') }}
