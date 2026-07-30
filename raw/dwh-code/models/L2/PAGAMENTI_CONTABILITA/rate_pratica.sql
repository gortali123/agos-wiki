-- Entita' L2: RATE_M
-- Storicizzazione: S3 (incremental / append, snapshot mensile) -- scelta confermata dall'utente
--   (il catalogo indica S2, ma DT_OSSERVAZIONE in PK e' il marker di S3)
-- Main: OXCTFPAFD (cluster A2 -> filtro FL_DELETED)

SELECT
    r.OXCTPAFD_PROCEDURA AS TP_PROCEDURA,
    r.OXCTPAFD_NUM_PRATICA AS CD_PRATICA,
    -- NB: cast a NUMBER(5) come da data model (la sorgente su Snowflake risulta NUMBER(1))
    CAST(r.OXCTPAFD_PROGRESSIVO AS NUMBER(5)) AS NM_PROG_PIANO,
    CAST(r.OXCTPAFD_PERIODO AS NUMBER(5)) AS NM_PROG_RATA,
    -- WARN: DT_OSSERVAZIONE (campo tecnico S3) non ha colonna sorgente nel data model.
    --        Valorizzato con get_dt_osservazione(), stessa espressione usata dal pre-hook delete_month() -> idempotenza garantita.
    {{ get_dt_osservazione() }} AS DT_OSSERVAZIONE,
    r.OXCTPAFD_NUMERO_RATA AS NM_RATA,
    r.OXCTPAFD_NUM_RATA_ORIG AS NM_RATA_ORIG,
    r.OXCTPAFD_TIPO_RATA AS TP_RATA,
    {{ custom_to_date('r.OXCTPAFD_DATA_SCADENZA') }} AS DT_SCAD,
    {{ custom_to_decimal('r.OXCTPAFD_IMPORTO', 13, 2) }} AS EU_IMPORTO_RATA,
    {{ custom_to_decimal('r.OXCTPAFD_QTA_CAPITALE', 13, 2) }} AS EU_CAPITALE,
    {{ custom_to_decimal('r.OXCTPAFD_QTA_INTERESSI', 13, 2) }} AS EU_INTERESSI,
    {{ custom_to_decimal('r.OXCTPAFD_CAP_RESIDUO', 13, 2) }} AS EU_CAPITALE_RESIDUO,
    {{ custom_to_date('r.OXCTPAFD_DATA_SCAD_PAG') }} AS DT_SCAD_NEW,
    {{ custom_to_date('r.OXCTPAFD_DT_ACCODAMENTO') }} AS DT_ACCODAMENTO,
    r.OXCTPAFD_TP_ACCODAMENTO AS TP_ACCODAMENTO,
    -- RT: CASE WHEN OXCTPAFD_DATA_SCAD_PAG IS NOT NULL THEN 'S' ELSE 'N' END
    CAST(CASE WHEN r.OXCTPAFD_DATA_SCAD_PAG IS NOT NULL THEN 'S' ELSE 'N' END AS VARCHAR(1)) AS FL_ACCODAMENTO
FROM {{ ref('oxctfpafd') }} r
WHERE r.FL_DELETED = 'N'
-- NB S3: nessun filtro incrementale su DT_OSSERVAZIONE (qui e' calcolato, non e' una colonna sorgente).
--        L'idempotenza mensile e' garantita dal pre_hook delete_month() nello YML:
--        ad ogni run cancella lo snapshot del mese e ri-appende tutte le righe correnti.
