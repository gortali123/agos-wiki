-- WARN: FL_ABIL_IVASS - tipo CHAR(BASE) non standard nel data model; usato VARCHAR(1).

WITH catena AS (
    SELECT
        L.INTLIN_TIPO_INTERM,
        L.INTLIN_INTERM,
        -- livelli bassi: valorizzati solo se il nodo e' di quel tipo
        ve.IVE_CODICE                                          AS CD_VENDITORE_CATENA,
        pv.IPV_CODICE                                          AS CD_PUNTO_VENDITA_CATENA,
        COALESCE(cv0.ICV_CODICE, cv1.ICV_CODICE)               AS CD_CONVENZIONATO_CATENA,
        -- subagente: nodo SA, oppure CV/PV/VE il cui convenzionato pende da un subagente
        COALESCE(sa0.ISA_CODICE, sa1.ISA_CODICE)               AS CD_SUBAGENTE_CATENA,
        -- agente: risolto per qualunque nodo (diretto / via SA / via convenzionato / via subagente)
        ag1.IAG_CODICE                                         AS CD_AGENTE_CATENA,
        -- rete vendita: nodo RV, altrimenti la rete dell'agente risolto
        COALESCE(rv0.IRV_CODICE, ag1.IAG_RETE_VENDITA)         AS CD_RETE_VENDITA_CATENA
    FROM {{ ref('ccintlin') }} L
    -- ---- nodo "diretto" (una LEFT per tipo, gate nella ON) ----
    LEFT JOIN {{ ref('ccanaive') }} ve  ON  ve.IVE_CODICE  = L.INTLIN_INTERM
    LEFT JOIN {{ ref('ccanaipv') }} pv  ON  pv.IPV_CODICE  = L.INTLIN_INTERM
    LEFT JOIN {{ ref('ccanaicv') }} cv0 ON cv0.ICV_CODICE = L.INTLIN_INTERM
    LEFT JOIN {{ ref('ccanaisa') }} sa0 ON sa0.ISA_CODICE = L.INTLIN_INTERM
    LEFT JOIN {{ ref('ccanaiag') }} ag0 ON ag0.IAG_CODICE = L.INTLIN_INTERM
    LEFT JOIN {{ ref('ccanairv') }} rv0 ON rv0.IRV_CODICE = L.INTLIN_INTERM
    -- ---- risalita (le ON usano solo COALESCE, nessun CASE) ----
    LEFT JOIN {{ ref('ccanaipv') }} pv1 ON pv1.IPV_CODICE = ve.IVE_CONVENZIONATO
    -- convenzionato sopra un PV o un VE
    LEFT JOIN {{ ref('ccanaicv') }} cv1 ON cv1.ICV_CODICE = COALESCE(pv.IPV_CONVENZIONATO, ve.IVE_CONVENZIONATO)
    -- subagente eventuale sopra il convenzionato (ICV_AGENTE = "agente o subagente")
    LEFT JOIN {{ ref('ccanaisa') }} sa1 ON sa1.ISA_CODICE = COALESCE(cv0.ICV_AGENTE, cv1.ICV_AGENTE)
    -- agente risolto: diretto / dal subagente / dal subagente sopra il convenz. / dal convenzionato
    LEFT JOIN {{ ref('ccanaiag') }} ag1 ON ag1.IAG_CODICE = COALESCE(ag0.IAG_CODICE,
                                                                     sa0.ISA_AGENTE,
                                                                      sa1.ISA_AGENTE,
                                                                      cv0.ICV_AGENTE,
                                                                      cv1.ICV_AGENTE,
                                                                      pv.IPV_AGENTE,
                                                                      ve.IVE_AGENTE)
    WHERE L.FL_DELETED = 'N'
),

base AS (
    SELECT
        -- PK
        COALESCE(L.INTLIN_INTERM, A.INT_CODICE) AS CD_INTERMEDIARIO,
        COALESCE(L.INTLIN_TIPO_INTERM, A.INT_TIPO_ANA) AS TP_INTERMEDIARIO, 
        COALESCE(L.INTLIN_PROCEDURA, 'NA') AS TP_PROCEDURA, 
        -- Campi temporali di storicizzazione
        {{ custom_to_timestamp_ntz('L.INTLIN_DATA', 'L.INTLIN_ORA') }} AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita(
            'L.INTLIN_INTERM, L.INTLIN_TIPO_INTERM, L.INTLIN_PROCEDURA',
            custom_to_timestamp_ntz('L.INTLIN_DATA', 'L.INTLIN_ORA')
        ) }} AS TS_FINE_VALIDITA,
        -- Campi business
        -- toglie spazi bianchi e concatena (aggiungendo uno spazio nel mezzo)
        TRIM(AN.AL_RAG_SOCIALE_1)||' '||TRIM(AN.AL_RAG_SOCIALE_2) AS DS_RAGIONE_SOCIALE, 
        AN.AL_CODICE_FISCALE AS CD_CODICE_FISCALE,
        AN.AL_PARTITA_IVA AS CD_PARTITA_IVA,
        AN.AL_TIPO_ANAGRAFICA AS TP_ANAGRAFICA,
        AN.AL_FORMA_GIURIDICA AS CD_FORMA_GIURIDICA,
        COALESCE(L.INTLIN_STATO, A.INT_STATO) AS CD_STATO,
        COALESCE(L.INTLIN_ATTRIBUTO, A.INT_ATTRIBUTO) AS CD_ATTRIBUTO,
        IFF(COALESCE(L.INTLIN_STATO, A.INT_STATO) = 'AT', 'S', 'N') AS FL_ATTIVO,
        -- usato invece del case when qui sotto
        --CASE WHEN COALESCE(L.INTLIN_STATO, A.INT_STATO) = 'AT' THEN 'S' ELSE 'N' END AS FL_ATTIVO,
        {{ custom_to_date('L.INTLIN_DATA_ULT_STATO_FL') }} AS DT_ULTIMO_STATO,
        AN.AL_CAUSALE_ANNULLO AS CD_CAUSALE_ANNULLO,
        {{ custom_to_date('AN.AL_DATA_ANNULLO') }} AS DT_ANNULLO,
        COALESCE(L.INTLIN_FILIALE, A.INT_FILIALE) AS CD_FILIALE,
        COALESCE(L.INTLIN_MACROAREA, A.INT_MACROAREA) AS CD_MACROAREA,
        COALESCE(L.INTLIN_TIPOLOGIA, A.INT_TIPOLOGIA) AS CD_TIPOLOGIA,
        COALESCE(L.INTLIN_MEDIATORE, A.INT_MEDIATORE) AS FL_MEDIATORE,
        COALESCE(L.INTLIN_ABIL_IVASS, A.INT_ABIL_IVASS) AS FL_ABIL_IVASS,
        COALESCE(L.INTLIN_COD_ISC_OAM, A.INT_COD_ISC_OAM) AS CD_COD_ISC_OAM,
        COALESCE(L.INTLIN_FATT_RIC, A.INT_FATT_RIC) AS FL_FATT_RICEVUTA,
        -- Campi catena intermediazione dalla CTE catena
        CAT.CD_RETE_VENDITA_CATENA,
        --TRY_TO_NUMBER(CAT.CD_RETE_VENDITA_CATENA) AS CD_RETE_VENDITA_CATENA,
        CAT.CD_AGENTE_CATENA,
        --TRY_TO_NUMBER(CAT.CD_AGENTE_CATENA) AS CD_AGENTE_CATENA,
        CAT.CD_SUBAGENTE_CATENA,
        --TRY_TO_NUMBER(CAT.CD_SUBAGENTE_CATENA) AS CD_SUBAGENTE_CATENA,
        CAT.CD_CONVENZIONATO_CATENA,
        CAT.CD_PUNTO_VENDITA_CATENA,
        CAT.CD_VENDITORE_CATENA,
        -- LASTMODIFIEDDATA sempre ultimo, dalla sorgente principale
        L.LASTMODIFIEDDATA AS LASTMODIFIEDDATA,
        ROW_NUMBER() OVER (
            PARTITION BY L.INTLIN_INTERM, L.INTLIN_TIPO_INTERM, L.INTLIN_PROCEDURA, L.INTLIN_DATA, L.INTLIN_ORA
            ORDER BY L.ROWID
        )::NUMBER(38, 0) AS PR_PK
    FROM {{ ref('ccintlin') }} L
    LEFT JOIN {{ ref('ccanainin') }} A
        ON L.INTLIN_INTERM = A.INT_CODICE
        AND L.INTLIN_TIPO_INTERM = A.INT_TIPO_ANA
    LEFT JOIN {{ ref('ccanalog') }} AN
        ON AN.AL_CODICE = L.INTLIN_INTERM
        AND AN.FL_DELETED = 'N'
    LEFT JOIN catena CAT
        ON CAT.INTLIN_TIPO_INTERM = L.INTLIN_TIPO_INTERM
        AND CAT.INTLIN_INTERM = L.INTLIN_INTERM
        --ON CAT.INTLIN_INTERM = L.INTLIN_INTERM
    WHERE L.FL_DELETED = 'N'
),

dedup AS (
    SELECT
        CD_INTERMEDIARIO,
        TP_INTERMEDIARIO,
        TP_PROCEDURA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        PR_PK,
        DS_RAGIONE_SOCIALE,
        CD_CODICE_FISCALE,
        CD_PARTITA_IVA,
        TP_ANAGRAFICA,
        CD_FORMA_GIURIDICA,
        CD_STATO,
        CD_ATTRIBUTO,
        FL_ATTIVO,
        DT_ULTIMO_STATO,
        CD_CAUSALE_ANNULLO,
        DT_ANNULLO,
        CD_FILIALE,
        CD_MACROAREA,
        CD_TIPOLOGIA,
        FL_MEDIATORE,
        FL_ABIL_IVASS,
        CD_COD_ISC_OAM,
        FL_FATT_RICEVUTA,
        CD_RETE_VENDITA_CATENA,
        CD_AGENTE_CATENA,
        CD_SUBAGENTE_CATENA,
        CD_CONVENZIONATO_CATENA,
        CD_PUNTO_VENDITA_CATENA,
        CD_VENDITORE_CATENA,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_INTERMEDIARIO', 'TP_INTERMEDIARIO', 'TP_PROCEDURA', 'DS_RAGIONE_SOCIALE', 'CD_CODICE_FISCALE', 'CD_PARTITA_IVA',
            'TP_ANAGRAFICA', 'CD_FORMA_GIURIDICA', 'CD_STATO', 'CD_ATTRIBUTO', 'FL_ATTIVO', 'DT_ULTIMO_STATO', 'CD_CAUSALE_ANNULLO',
            'DT_ANNULLO', 'CD_FILIALE', 'CD_MACROAREA', 'CD_TIPOLOGIA', 'FL_MEDIATORE', 'FL_ABIL_IVASS', 'CD_COD_ISC_OAM',
            'FL_FATT_RICEVUTA', 'CD_RETE_VENDITA_CATENA', 'CD_AGENTE_CATENA', 'CD_SUBAGENTE_CATENA',
            'CD_CONVENZIONATO_CATENA', 'CD_PUNTO_VENDITA_CATENA', 'CD_VENDITORE_CATENA']) }} AS HASHED_COLS
    FROM base {{ is_incremental_S1('CD_INTERMEDIARIO, TP_INTERMEDIARIO, TP_PROCEDURA', order_extra='PR_PK') }}
),

DEDUP_FV AS (
    SELECT
        CD_INTERMEDIARIO,
        TP_INTERMEDIARIO,
        TP_PROCEDURA,
        TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_INTERMEDIARIO, TP_INTERMEDIARIO, TP_PROCEDURA', 'TS_INIZIO_VALIDITA') }} AS TS_FV_NEXT,
        PR_PK,
        DS_RAGIONE_SOCIALE,
        CD_CODICE_FISCALE,
        CD_PARTITA_IVA,
        TP_ANAGRAFICA,
        CD_FORMA_GIURIDICA,
        CD_STATO,
        CD_ATTRIBUTO,
        FL_ATTIVO,
        DT_ULTIMO_STATO,
        CD_CAUSALE_ANNULLO,
        DT_ANNULLO,
        CD_FILIALE,
        CD_MACROAREA,
        CD_TIPOLOGIA,
        FL_MEDIATORE,
        FL_ABIL_IVASS,
        CD_COD_ISC_OAM,
        FL_FATT_RICEVUTA,
        CD_RETE_VENDITA_CATENA,
        CD_AGENTE_CATENA,
        CD_SUBAGENTE_CATENA,
        CD_CONVENZIONATO_CATENA,
        CD_PUNTO_VENDITA_CATENA,
        CD_VENDITORE_CATENA,
        LASTMODIFIEDDATA
    FROM dedup 
)

SELECT
    H.CD_INTERMEDIARIO,
    H.TP_INTERMEDIARIO,
    H.TP_PROCEDURA,
    H.TS_INIZIO_VALIDITA,
    MAX(H.TS_FV_NEXT) OVER (
        PARTITION BY H.CD_INTERMEDIARIO, H.TP_INTERMEDIARIO, H.TP_PROCEDURA, H.TS_INIZIO_VALIDITA
    ) AS TS_FINE_VALIDITA,
    H.PR_PK,
    H.DS_RAGIONE_SOCIALE,
    H.CD_CODICE_FISCALE,
    H.CD_PARTITA_IVA,
    H.TP_ANAGRAFICA,
    H.CD_FORMA_GIURIDICA,
    H.CD_STATO,
    H.CD_ATTRIBUTO,
    H.FL_ATTIVO,
    H.DT_ULTIMO_STATO,
    H.CD_CAUSALE_ANNULLO,
    H.DT_ANNULLO,
    H.CD_FILIALE,
    H.CD_MACROAREA,
    H.CD_TIPOLOGIA,
    H.FL_MEDIATORE,
    H.FL_ABIL_IVASS,
    H.CD_COD_ISC_OAM,
    H.FL_FATT_RICEVUTA,
    H.CD_RETE_VENDITA_CATENA,
    H.CD_AGENTE_CATENA,
    H.CD_SUBAGENTE_CATENA,
    H.CD_CONVENZIONATO_CATENA,
    H.CD_PUNTO_VENDITA_CATENA,
    H.CD_VENDITORE_CATENA,
    H.LASTMODIFIEDDATA
FROM DEDUP_FV AS H 

