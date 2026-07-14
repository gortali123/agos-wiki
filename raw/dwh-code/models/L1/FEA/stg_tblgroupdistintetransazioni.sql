select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idGroupDistintaTrans AS NUMBER(11,0)) AS idgroupdistintatrans,
  TRY_CAST(idStatoGroupDistintaTrans AS NUMBER(11,0)) AS idstatogroupdistintatrans,
  TRY_CAST(dataInvioGroupDistintaTrans AS TIMESTAMP_NTZ) AS datainviogroupdistintatrans,
  TRY_CAST(numeroDistinteTrans AS NUMBER(11,0)) AS numerodistintetrans,
  TRY_CAST(totaleDistinteTrans AS NUMBER(38,10)) AS totaledistintetrans,
  TRY_CAST(headerGroupDistintaTrans AS VARCHAR(250)) AS headergroupdistintatrans,
  TRY_CAST(file_GroupDistintaTrans AS VARCHAR(250)) AS file_groupdistintatrans,
  TRY_CAST(file_ricevutaGroupDistintaTrans AS VARCHAR(250)) AS file_ricevutagroupdistintatrans,
  TRY_CAST(data_ricevutaGroupDistintaTrans AS TIMESTAMP_NTZ) AS data_ricevutagroupdistintatrans,
  TRY_CAST(idUsers_carRicevutaGroupDistintaTrans AS VARCHAR(45)) AS idusers_carricevutagroupdistintatrans,
  TRY_CAST(tipoOperazione AS NUMBER(11,0)) AS tipooperazione,
  TRY_CAST(idParametriPagamento AS NUMBER(11,0)) AS idparametripagamento,
  TRY_CAST(data_creazione AS DATE) AS data_creazione,
  TRY_CAST(data_modifica AS DATE) AS data_modifica
from {{ source('source_l0','tblgroupdistintetransazioni') }}
