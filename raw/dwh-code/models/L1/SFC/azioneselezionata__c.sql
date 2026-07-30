select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(CatalogoAzioni__r_Id AS VARCHAR) AS catalogoazioni__r_id,
  TRY_CAST(CatalogoAzioni__r_Name AS VARCHAR) AS catalogoazioni__r_name,
  TRY_CAST(CreatedById AS VARCHAR) AS createdbyid,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR) AS createdby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(CreatedDate)::TIMESTAMP_NTZ AS CreatedDate,
  TRY_CAST(Descrizione__c AS VARCHAR(255)) AS descrizione__c,
  TRY_CAST(Iniziativa__r_Id AS VARCHAR) AS iniziativa__r_id,
  TRY_CAST(Iniziativa__r_IDIniziativa__c AS VARCHAR) AS iniziativa__r_idiniziativa__c,
  TRY_CAST(LastModifiedById AS VARCHAR) AS lastmodifiedbyid,
  TRY_CAST(LastModifiedBy_FederationIdentifier AS VARCHAR) AS lastmodifiedby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(LastModifiedDate)::TIMESTAMP_NTZ AS LastModifiedDate,
  TRY_CAST(Name AS VARCHAR(255)) AS name,
  TRY_CAST(Rete__c AS VARCHAR(255)) AS rete__c
from {{ source('source_l0','azioneselezionata__c') }}
