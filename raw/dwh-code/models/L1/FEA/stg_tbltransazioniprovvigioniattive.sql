select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idTransazioneProvvigioneAttiva AS NUMBER(11,0)) AS idtransazioneprovvigioneattiva,
  TRY_CAST(idTransazione AS NUMBER(11,0)) AS idtransazione,
  TRY_CAST(idNodo AS NUMBER(11,0)) AS idnodo,
  TRY_CAST(idProdottoVersione AS NUMBER(11,0)) AS idprodottoversione,
  TRY_CAST(idEstrattoContoAttivo AS NUMBER(11,0)) AS idestrattocontoattivo,
  TRY_CAST(data_valuta AS DATE) AS data_valuta,
  TRY_CAST(tipo_provvigione AS VARCHAR(10)) AS tipo_provvigione,
  TRY_CAST(percentuale_provvigione AS NUMBER(38,10)) AS percentuale_provvigione,
  TRY_CAST(premio_imponibile AS NUMBER(38,10)) AS premio_imponibile,
  TRY_CAST(importo_provvigione AS NUMBER(38,10)) AS importo_provvigione,
  TRY_CAST(tipo_transazione AS NUMBER(11,0)) AS tipo_transazione,
  TRY_CAST(data_creazione AS DATE) AS data_creazione,
  TRY_CAST(data_modifica AS DATE) AS data_modifica
from {{ source('source_l0','tbltransazioniprovvigioniattive') }}
