select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  --COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_coalesce_modif_creaz, --da togliere questa riga e sostituire con quella superiore quando ci saranno i due campi: data_modifica e data_creazione
  TRY_CAST(idNodoUsers AS NUMBER(11,0)) AS idnodousers,
  TRY_CAST(idUsers AS NUMBER(11,0)) AS idusers,
  TRY_CAST(idNodo AS NUMBER(11,0)) AS idnodo,
  TRY_CAST(tipoNodoUser AS NUMBER(6,0)) AS tiponodouser,
  TRY_CAST(bloccato AS NUMBER(6,0)) AS bloccato,
  TRY_CAST(data_blocco AS TIMESTAMP_NTZ) AS data_blocco
from {{ source('source_l0','tblnodiusers') }}
