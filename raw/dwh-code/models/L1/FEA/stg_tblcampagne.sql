select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idCampagna AS NUMBER(11,0)) AS idcampagna,
  TRY_CAST(codCampagna AS VARCHAR(45)) AS codcampagna,
  TRY_CAST(dsBreve AS VARCHAR(100)) AS dsbreve,
  TRY_CAST(dsLunga AS VARCHAR(255)) AS dslunga,
  TRY_CAST(dataInizio AS DATE) AS datainizio,
  TRY_CAST(dataFine AS DATE) AS datafine,
  TRY_CAST(abilitato AS NUMBER(1,0)) AS abilitato,
  TRY_CAST(eliminato AS NUMBER(1,0)) AS eliminato,
  TRY_CAST(idNodoCreazione AS NUMBER(11,0)) AS idnodocreazione,
  TRY_CAST(idUserCreazione AS NUMBER(11,0)) AS idusercreazione,
  TRY_CAST(idNodoModifica AS NUMBER(11,0)) AS idnodomodifica,
  TRY_CAST(idUserModifica AS NUMBER(11,0)) AS idusermodifica,
  TRY_CAST(codCampagnaCompagnia AS VARCHAR(45)) AS codcampagnacompagnia,
  TRY_CAST(imported AS NUMBER(1,0)) AS imported,
  TRY_CAST(referenceCampagna AS VARCHAR(45)) AS referencecampagna,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblcampagne') }}
