select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idEsito7DaysCallCenter AS NUMBER(11,0)) AS idesito7dayscallcenter,
  TRY_CAST(idProdottoVersione AS NUMBER(11,0)) AS idprodottoversione,
  TRY_CAST(idPreventivo AS NUMBER(11,0)) AS idpreventivo,
  TRY_CAST(tipologia AS VARCHAR) AS tipologia,
  TRY_CAST(id_anagrafica AS VARCHAR) AS id_anagrafica,
  TRY_CAST(id_esito AS VARCHAR) AS id_esito,
  TRY_CAST(data_ora_fine_chiamata AS VARCHAR) AS data_ora_fine_chiamata,
  TRY_CAST(campagna AS VARCHAR) AS campagna,
  TRY_CAST(motivo_no AS VARCHAR) AS motivo_no,
  TRY_CAST(data_esito AS VARCHAR) AS data_esito,
  TRY_CAST(contatto_utile AS VARCHAR) AS contatto_utile,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblesiti7dayscallcenter') }}
