-- INCASSI_TESTATA_M | Storicizzazione S3 (append, snapshot mensile) | SA: PAGAMENTI E CONTABILITA
-- Sorgente principale: OXINFREPT (cluster A2 -> FL_DELETED)
-- Storno: self-join su OXINREPT_EV_INC_ST (che punta all'EVENTO dello storno)
SELECT
    t.OXINREPT_EVENTO AS CD_EVENTO_INCASSO,
    {{ last_day_past_month() }} AS DT_OSSERVAZIONE, --TODO campo della tabella mensile
    t.OXINREPT_PROCEDURA AS TP_PROCEDURA,
    t.OXINREPT_PRATICA AS CD_PRATICA,
    {{ custom_to_date('t.OXINREPT_DATA_REGISTRAZIONE') }} AS DT_REGISTRAZIONE,
    {{ custom_to_date('t.OXINREPT_DATA_VALUTA') }} AS DT_VALUTA,
    t.OXINREPT_MM_AAAA_RENDICNT AS NM_MESE_ANNO_RENDICONTAZIONE,
    {{ custom_to_decimal('t.OXINREPT_IMPORTO', 13, 2) }} AS EU_INCASSO,
    -- TODO quando ci sarà il campo OXINREPT_EV_INC_ST CASE WHEN orig.OXINREPT_EVENTO IS NOT NULL THEN 'S' ELSE 'N' END AS FL_STORNO,
    -- TODO quando ci sarà il campo OXINREPT_EV_INC_ST CAST(orig.OXINREPT_EVENTO AS NUMBER(11)) AS CD_EVENTO_INCASSO_STORNATO,
    -- TODO quando ci sarà il campo OXINREPT_EV_INC_ST CASE WHEN COALESCE(t.OXINREPT_EV_INC_ST, 0) <> 0 THEN 'S' ELSE 'N' END AS FL_STORNATO,
    -- TODO quando ci sarà il campo OXINREPT_EV_INC_ST { custom_to_date('st.OXINREPT_DATA_REGISTRAZIONE') } AS DT_STORNATO,
    CAST(NULL AS VARCHAR(1)) AS FL_STORNO,
    CAST(NULL AS NUMBER(11)) AS CD_EVENTO_INCASSO_STORNATO,
    CAST(NULL AS VARCHAR(1)) AS FL_STORNATO,
    CAST(NULL AS DATE) AS DT_STORNATO,
    t.OXINREPT_ORIGINE AS CD_ORIGINE,
    t.OXINREPT_FORMA_PAGAMENTO AS TP_FORMA_PAGAMENTO,
    t.OXINREPT_DES_FORMA AS DS_FORMA_PAGAMENTO,
    t.OXINREPT_TIPO_MOV AS TP_MOVIMENTO,
    t.OXINREPT_CAUSALE AS CD_CAUSALE,
    t.OXINREPT_FILE_DETTAGLIO AS CD_FILE_DETTAGLIO,
    t.OXINREPT_FUNZIONE AS CD_FUNZIONE,
    t.OXINREPT_OPERAZIONE AS CD_OPERAZIONE,
    t.OXINREPT_SEZIONALE AS FL_SEZIONALE
FROM {{ ref('oxinfrept') }} t --TODO tabella Mensile
-- TODO quando ci sarà il campo OXINREPT_EV_INC_ST
-- -- storno di t (t.EV_INC_ST -> st.EVENTO): fornisce la data DT_STORNATO
-- LEFT JOIN {{ ref('oxinfrept') }} st --TODO tabella Mensile
--     ON  st.OXINREPT_EVENTO = t.OXINREPT_EV_INC_ST
--     AND COALESCE(t.OXINREPT_EV_INC_ST, 0) <> 0
--     AND st.FL_DELETED = 'N'
-- -- incasso originale stornato da t (orig.EV_INC_ST -> t.EVENTO): fornisce CD_EVENTO_INCASSO_STORNATO
-- LEFT JOIN {{ ref('oxinfrept') }} orig --TODO tabella Mensile
--     ON  orig.OXINREPT_EV_INC_ST = t.OXINREPT_EVENTO
--     AND COALESCE(orig.OXINREPT_EV_INC_ST, 0) <> 0
--     AND orig.FL_DELETED = 'N'
WHERE t.FL_DELETED = 'N'

{% if is_incremental() %}
    AND DT_OSSERVAZIONE = {{ get_dt_osservazione() }}
{% endif %}