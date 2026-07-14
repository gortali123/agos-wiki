select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idDistintaTransazione AS NUMBER(11,0)) AS iddistintatransazione,
  TRY_CAST(idStatoDistintaTransazione AS NUMBER(11,0)) AS idstatodistintatransazione,
  TRY_CAST(tipoPagamento AS VARCHAR(45)) AS tipopagamento,
  TRY_CAST(dataInvioDistinta AS TIMESTAMP_NTZ) AS datainviodistinta,
  TRY_CAST(numeroTransazioni AS NUMBER(38,10)) AS numerotransazioni,
  TRY_CAST(totaleTransazioni AS NUMBER(38,10)) AS totaletransazioni,
  TRY_CAST(esitoDistinta AS NUMBER(11,0)) AS esitodistinta,
  TRY_CAST(dataValuta AS DATE) AS datavaluta,
  TRY_CAST(headerDistinta AS VARCHAR(250)) AS headerdistinta,
  TRY_CAST(file_distintaTransazione AS VARCHAR(250)) AS file_distintatransazione,
  TRY_CAST(file_ricevutaDistintaTransazione AS VARCHAR(250)) AS file_ricevutadistintatransazione,
  TRY_CAST(data_ricevutaDistintaTransazione AS TIMESTAMP_NTZ) AS data_ricevutadistintatransazione,
  TRY_CAST(idUsers_caricamentoRicevutaDistintaTransazione AS VARCHAR(45)) AS idusers_caricamentoricevutadistintatransazione,
  TRY_CAST(idGroupDistintaTrans AS NUMBER(11,0)) AS idgroupdistintatrans,
  TRY_CAST(idParametriPagamento AS NUMBER(11,0)) AS idparametripagamento,
  TRY_CAST(data_creazione AS DATE) AS data_creazione,
  TRY_CAST(data_modifica AS DATE) AS data_modifica
from {{ source('source_l0','tbldistintetransazioni') }}
