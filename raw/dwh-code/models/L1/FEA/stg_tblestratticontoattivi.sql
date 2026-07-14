select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idEstrattoContoAttivo AS NUMBER(11,0)) AS idestrattocontoattivo,
  TRY_CAST(idNodo AS NUMBER(11,0)) AS idnodo,
  TRY_CAST(periodo_inizio AS DATE) AS periodo_inizio,
  TRY_CAST(periodo_fine AS DATE) AS periodo_fine,
  TRY_CAST(numero_transazioni AS NUMBER(6,0)) AS numero_transazioni,
  TRY_CAST(importo AS NUMBER(38,10)) AS importo,
  TRY_CAST(idScritturaContabile_01D AS NUMBER(11,0)) AS idscritturacontabile_01d,
  TRY_CAST(data_scrittura_contabile_01D AS DATE) AS data_scrittura_contabile_01d,
  TRY_CAST(idScritturaContabile_01A AS NUMBER(11,0)) AS idscritturacontabile_01a,
  TRY_CAST(data_scrittura_contabile_01A AS DATE) AS data_scrittura_contabile_01a,
  TRY_CAST(data_creazione AS DATE) AS data_creazione,
  TRY_CAST(data_modifica AS DATE) AS data_modifica
from {{ source('source_l0','tblestratticontoattivi') }}
