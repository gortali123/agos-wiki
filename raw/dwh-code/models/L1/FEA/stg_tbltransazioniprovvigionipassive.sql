select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idTransazioneProvvigionePassiva AS NUMBER(11,0)) AS idtransazioneprovvigionepassiva,
  TRY_CAST(idTransazione AS NUMBER(11,0)) AS idtransazione,
  TRY_CAST(idNodo AS NUMBER(11,0)) AS idnodo,
  TRY_CAST(idProdottoVersione AS NUMBER(11,0)) AS idprodottoversione,
  TRY_CAST(idEstrattoContoPassivo AS NUMBER(11,0)) AS idestrattocontopassivo,
  TRY_CAST(data_valuta AS DATE) AS data_valuta,
  TRY_CAST(tipo_provvigione AS VARCHAR(10)) AS tipo_provvigione,
  TRY_CAST(percentuale_provvigione AS NUMBER(38,10)) AS percentuale_provvigione,
  TRY_CAST(premio_imponibile AS NUMBER(38,10)) AS premio_imponibile,
  TRY_CAST(importo_provvigione AS NUMBER(38,10)) AS importo_provvigione,
  TRY_CAST(tipo_transazione AS NUMBER(11,0)) AS tipo_transazione,
  TRY_CAST(idScritturaContabile_01D AS NUMBER(11,0)) AS idscritturacontabile_01d,
  TRY_CAST(data_scrittura_contabile_01D AS DATE) AS data_scrittura_contabile_01d,
  TRY_CAST(idScritturaContabile_01A AS NUMBER(11,0)) AS idscritturacontabile_01a,
  TRY_CAST(data_scrittura_contabile_01A AS DATE) AS data_scrittura_contabile_01a,
  TRY_CAST(data_creazione AS DATE) AS data_creazione,
  TRY_CAST(data_modifica AS DATE) AS data_modifica
from {{ source('source_l0','tbltransazioniprovvigionipassive') }}
