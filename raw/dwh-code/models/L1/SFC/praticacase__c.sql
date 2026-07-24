select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(Case__r_Id AS VARCHAR) AS case__r_id,
  TRY_CAST(Case__r_CaseNumber AS VARCHAR(255)) AS case__r_casenumber,
  TRY_CAST(StatoPratica__c AS VARCHAR(255)) AS statopratica__c,
  TRY_CAST(Blocco__c AS VARCHAR(255)) AS blocco__c,
  TRY_CAST(SaldoTotale__c AS VARCHAR(255)) AS saldototale__c,
  TRY_CAST(Cliente__r_ExternalKey__c AS VARCHAR(255)) AS cliente__r_externalkey__c,
  TRY_CAST(Name AS VARCHAR(255)) AS name,
  TRY_CAST(CodiceDescrizionePratica__c AS VARCHAR(255)) AS codicedescrizionepratica__c,
  TRY_CAST(Pratica__r_ExternalKey__c AS VARCHAR(255)) AS pratica__r_externalkey__c,
  TRY_CAST(CreatedBy_FederationIdentifier AS VARCHAR(255)) AS createdby_federationidentifier,
  TRY_CAST(LastModifiedBy_FederationIdentifier AS VARCHAR(255)) AS lastmodifiedby_federationidentifier,
  TRY_TO_TIMESTAMP_TZ(CreatedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS CreatedDate,
  TRY_TO_TIMESTAMP_TZ(LastModifiedDate, 'YYYY-MM-DDTHH24:MI:SS.FF3TZHTZM')::TIMESTAMP_NTZ AS lastmodifieddate
from {{ source('source_l0','praticacase__c') }}
