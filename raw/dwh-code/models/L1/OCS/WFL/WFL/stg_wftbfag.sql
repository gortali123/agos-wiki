select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(WFTBAG_AGENDA) = '', ' ', RTRIM(WFTBAG_AGENDA)) AS VARCHAR(10)) AS wftbag_agenda,
  TRY_CAST(IFF(RTRIM(WFTBAG_DESCRIZIONE) = '', ' ', RTRIM(WFTBAG_DESCRIZIONE)) AS VARCHAR(30)) AS wftbag_descrizione,
  TRY_CAST(WFTBAG_GG_ORDINAMENTO AS NUMBER(5,0)) AS wftbag_gg_ordinamento,
  TRY_CAST(IFF(RTRIM(WFTBAG_FMP) = '', ' ', RTRIM(WFTBAG_FMP)) AS VARCHAR(1)) AS wftbag_fmp,
  TRY_CAST(IFF(RTRIM(WFTBAG_CNV) = '', ' ', RTRIM(WFTBAG_CNV)) AS VARCHAR(1)) AS wftbag_cnv,
  TRY_CAST(IFF(RTRIM(WFTBAG_CRM) = '', ' ', RTRIM(WFTBAG_CRM)) AS VARCHAR(1)) AS wftbag_crm,
  TRY_CAST(IFF(RTRIM(WFTBAG_RMK) = '', ' ', RTRIM(WFTBAG_RMK)) AS VARCHAR(1)) AS wftbag_rmk,
  TRY_CAST(IFF(RTRIM(WFTBAG_ESCL_RICERCA) = '', ' ', RTRIM(WFTBAG_ESCL_RICERCA)) AS VARCHAR(1)) AS wftbag_escl_ricerca,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','wftbfag') }}
