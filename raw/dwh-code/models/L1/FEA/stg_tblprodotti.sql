select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idProdotto AS NUMBER(11,0)) AS idprodotto,
  TRY_CAST(codiceProd AS VARCHAR(10)) AS codiceprod,
  TRY_CAST(codConvenzione AS VARCHAR(25)) AS codconvenzione,
  TRY_CAST(codiceRamo AS VARCHAR(2)) AS codiceramo,
  TRY_CAST(dsProdotto AS VARCHAR(250)) AS dsprodotto,
  TRY_CAST(idCompagnia AS NUMBER(11,0)) AS idcompagnia,
  TRY_CAST(idRamo AS NUMBER(11,0)) AS idramo,
  TRY_CAST(suffix AS VARCHAR(20)) AS suffix,
  TRY_CAST(suffix_2 AS VARCHAR(20)) AS suffix_2,
  TRY_CAST(sigla_num AS VARCHAR(30)) AS sigla_num,
  TRY_CAST(righe_prevbene AS NUMBER(6,0)) AS righe_prevbene,
  TRY_CAST(famiglia_abilitazione AS VARCHAR(1)) AS famiglia_abilitazione,
  TRY_CAST(disdetta_mesi AS NUMBER(6,0)) AS disdetta_mesi,
  TRY_CAST(giorni_comporto AS NUMBER(6,0)) AS giorni_comporto,
  TRY_CAST(codice_ramo_compagnia AS VARCHAR(7)) AS codice_ramo_compagnia,
  TRY_CAST(key_lock AS VARCHAR(100)) AS key_lock,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblprodotti') }}
