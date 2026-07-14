select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idProdVersFattore AS NUMBER(11,0)) AS idprodversfattore,
  TRY_CAST(idProdottoVersione AS NUMBER(11,0)) AS idprodottoversione,
  TRY_CAST(idFattore AS NUMBER(11,0)) AS idfattore,
  TRY_CAST(idTipoFattore AS NUMBER(11,0)) AS idtipofattore,
  TRY_CAST(valoreFattore AS VARCHAR(255)) AS valorefattore,
  TRY_CAST(eliminato AS NUMBER(1,0)) AS eliminato,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblprodversfattori') }}
