WITH pratiche_assicurate_raw AS (

    SELECT PLSE_NUM_PRATICA AS CD_PRATICA
    FROM {{ ref('plpratserv') }}

    UNION ALL

    SELECT CASRSER_CARTA AS CD_PRATICA
    FROM {{ ref('casrfser') }}

)

, pratiche_assicurate AS (

    SELECT CD_PRATICA
    FROM pratiche_assicurate_raw
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CD_PRATICA
        ORDER BY CD_PRATICA
    ) = 1

)

, fl_assicurazione_raw AS (

    SELECT
        COO.PCCOCOO_ID_CONTATTO AS CD_CONTATTO,
        'S' AS FL_ASSICURAZIONE
    FROM {{ ref('pccofcoo') }} COO
    INNER JOIN pratiche_assicurate PA
        ON COO.PCCOCOO_PER_PRATICA = PA.CD_PRATICA

)

, fl_assicurazione AS (

    SELECT
        CD_CONTATTO,
        FL_ASSICURAZIONE
    FROM fl_assicurazione_raw
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY CD_CONTATTO
        ORDER BY CD_CONTATTO
    ) = 1

)

, fl_preventivo AS (

    -- WARN: RT usa la tabella 'PCCOFCOML', ma il data model dichiara TAB = '2442_PCCOFCOML' per questo campo; usata la tabella citata nella RT (fonte autoritativa)
    SELECT
        PCCOCOML_ID_CONTATTO AS CD_CONTATTO,
        'S' AS FL_PREVENTIVO
    FROM {{ ref('pccofcoml') }}
    WHERE PCCOCOML_ID_CONTATTO IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY PCCOCOML_ID_CONTATTO
        ORDER BY PCCOCOML_ID_CONTATTO
    ) = 1

)

SELECT
    D.PCCOCON_ID_CONTATTO AS CD_CONTATTO,
    T.PCCOCOO_PER_PRATICA AS CD_PRATICA,
    T.PCCOCOO_PROCEDURA AS TP_PROCEDURA,
    T.PCCOCOO_CAR_CLIENTE AS CD_CLIENTE,
    D.PCCOCON_STATO AS CD_STATO_PREV,
    D.PCCOCON_STATO AS DS_STATO_PREV, -- WARN: stessa colonna sorgente di CD_STATO_PREV, nessuna RT di decodifica presente nel data model
    {{ custom_to_date('D.PCCOCON_DATA_CARICAMENTO') }} AS DT_PREVENTIVO,
    D.PCCOCON_ATTRIBUTO AS CD_ATTRIBUTO,
    D.PCCOCON_ORIGINE_CONTATTO AS CD_ORIGINE_CONTATTO,
    D.PCCOCON_CANALE_ACQ AS CD_CANALE_ACQ,
    D.PCCOCON_SPORTELLO AS DS_SPORTELLO,
    D.PCCOCON_CAMPAGNA AS CD_CAMPAGNA,
    C.CRTCAM_DESCRIZIONE AS DS_CAMPAGNA,
    C.CRTCAM_TASSO_CLI AS TP_TASSO,
    FA.FL_ASSICURAZIONE,
    FP.FL_PREVENTIVO
FROM {{ ref('pccofcon') }} D
LEFT JOIN {{ ref('pccofcoo') }} T
    ON T.PCCOCOO_ID_CONTATTO = D.PCCOCON_ID_CONTATTO
-- WARN: la RT di DS_CAMPAGNA/TP_TASSO nel data model ha 2 incongruenze: (1) il join a PCCOFMODL usa D.PCATATTD_ID_CONTATTO, una colonna che non appartiene a PCCOFCON (alias D qui); la colonna CHIAVI della stessa riga usa invece 'FROM PCATFATTD D', suggerendo che la vera tabella main per questa RT fosse PCATFATTD, non PCCOFCON - mantenuto PCCOFCON come main dell'entita' (coerente con tutti gli altri campi), join a PCCOFMODL fatto su D.PCCOCON_ID_CONTATTO per analogia con gli altri join della stessa entita', ma va verificato con il team; (2) la sintassi del secondo JOIN (a CRTABCAM) nel data model manca di 'ON' e 'AND' tra le due condizioni - corretta qui come probabile refuso di sintassi
LEFT JOIN {{ ref('pccofmodl') }} MO
    ON MO.PCCOMODL_ID_CONTATTO = D.PCCOCON_ID_CONTATTO
LEFT JOIN {{ ref('crtabcam') }} C
    ON D.PCCOCON_CAMPAGNA = C.CRTCAM_CODICE
   AND T.PCCOCOO_PROCEDURA = C.CRTCAM_PROCEDURA
LEFT JOIN fl_assicurazione FA
    ON D.PCCOCON_ID_CONTATTO = FA.CD_CONTATTO
LEFT JOIN fl_preventivo FP
    ON D.PCCOCON_ID_CONTATTO = FP.CD_CONTATTO
-- WARN: storicizzazione non esplicita nel catalogo per questa entita' (nessun TS_INIZIO_VALIDITA/LASTMODIFIEDDATA/DT_OSSERVAZIONE nel data model); trattata come S4 (insert_overwrite, nessun filtro incrementale) per assenza di qualunque campo tecnico, da confermare col team
-- WARN: cluster FL_DELETED della sorgente PCCOFCON non noto (non verificabile in raw/dwh-code); nessun filtro FL_DELETED applicato
