-- =============================================================================
-- MODELLO   : DM_ACC_CA_PERIM
-- PROCESSO  : Campioni Accettazione | LAYER: L3 - DataMart
-- SCOPO     : Perimetro/contenitore condiviso per tutti i modelli "carte"
--             (matrix_inat, matrix_utlz_m, mod_ripagamento, campioni,
--             tab_blocchi) - centralizza sia il filtro pratiche CA sia tutti
--             i campi "base" (letti direttamente da PRATICA_M/CARTA_M/CREMEP)
--             gia' usati nei perimetri locali di ciascun modello figlio.
-- PK        : CD_PRATICA
-- =============================================================================

SELECT
    A.CD_PRATICA,
    A.TP_PROCEDURA,
    A.DT_CARICAMENTO,
    A.CD_CLIENTE,
    A.CD_STATO,
    A.DT_RITIRATA,
    A.CD_MACRO_PRODOTTO_4,
    C.CEMPR_PREPAGATE AS FL_PREPAGATA,
    A.DT_CHIUSURA_EFFETTIVA,
    A.DT_ESITO,
    A.FL_PERDITA_CESSIONE,
    A.DT_OSSERVAZIONE,
    A.DT_DBT,
    A.DT_CESSIONE,
    A.DT_PASSAGGIO_PERDITA,
    A.TS_COMUNICAZIONE_ESITO_DEF,
    A.DT_PRIMA_SCADENZA,
    A.DT_PRIMA_SCADENZA_IST,
    A.DT_DECORRENZA,
    B.DT_PRIMO_UTILIZZO,
    A.CD_MACRO_PRODOTTO_1,
    A.CD_MACRO_PRODOTTO_2,
    A.CD_MACRO_PRODOTTO_3,
    A.CD_MERCATO_1,
    A.CD_MERCATO_2,
    A.CD_MERCATO_3,
    A.CD_MERCATO_4,

    -- ---------- prodotto / canale ----------
    A.CD_PRODOTTO,
    A.CD_TIPO_PRODOTTO,
   -- A.CD_DESTINAZIONE_BENE,
    A.CD_CANALE_ACQUISIZIONE,
    A.FL_WEB_CANALE_ACQ,
    --A.EU_PREZZO_BENE

FROM {{ ref('pratica_m') }} AS A
LEFT JOIN {{ ref('carta_m') }} AS B
    ON A.CD_PRATICA = B.CD_PRATICA
    AND A.DT_OSSERVAZIONE= B.DT_OSSERVAZIONE
LEFT JOIN AGOS_DEV_16000.L1_O_CAR.CREMEP AS C
    ON B.CD_EMETTITORE = C.CEMPR_EMETTITORE
    AND B.CD_PRODOTTO = C.CEMPR_PRODOTTO

WHERE A.TP_PROCEDURA = 'CA'
    --AND A.CD_MACRO_PRODOTTO_4 IN ('REV_B2B', 'REV_B2C')
    AND A.DT_CARICAMENTO >= '2011-01-01'
    AND A.DT_CARICAMENTO < LAST_DAY(DATEADD(MONTH, -1, CURRENT_DATE)) 
    --  AND A.CD_STATO IN ('60', '55', '40')  bloccata, utilizzata, attivata 

    AND TRY_TO_NUMBER(A.CD_STATO) >= 30
    AND (A.CD_ATTRIBUTO IS NULL OR A.CD_ATTRIBUTO NOT IN ('RT', 'RF'))
    -- AND C.CEMPR_PREPAGATE = 'N'  -- vedi nota 1 in testa: commentato, da' zero in questo ambiente
QUALIFY ROW_NUMBER() OVER (PARTITION BY A.CD_PRATICA ORDER BY 1) = 1