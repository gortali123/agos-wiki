-- COSE DA FARE QUI:
-- 1. AGGIUSTARE LA REF A 4338_rESPONSABILI ACTIVE
-- 2. AGGIUSTARE NELLO YML LA PRE HOOK
-- 3. CONTROLLA SE è NECESSARIO METTERE PR_PK (SE 4338_responsabile_active HA ROWID COME PK)
WITH base AS (

    SELECT
        T."Codice Utente" AS CD_UTENZA,
        T."Tipologia (Dominio definito da OCS)" AS CD_TIPOLOGIA_UTENTE,
        T.CD_INTERMEDIARIO AS CD_INTERMEDIARIO,  
        {{ custom_to_timestamp_ntz('T.TS_INIZIO_VALIDITA') }} AS TS_INIZIO_VALIDITA, --problema qui (è un ts già? )
        -- TECNICAMENTE 4338_responsabili_active è una c quindi dovrebbe avere dei ts già :)
        {{ ts_fine_validita(
            "CD_UTENZA, CD_TIPOLOGIA_UTENTE, CD_INTERMEDIARIO",
            custom_to_timestamp_ntz('T.TS_INIZIO_VALIDITA')
        ) }} AS TS_FINE_VALIDITA, -- anche qui problema
        T.CD_RESPONSABILE_AD AS CD_RESPONSABILE_AD, --"Codice responsabile"
        -- manca livello di firma - da mettere?
        T.DS_UTENZA AS DS_UTENZA, --"Descrizione"
        T.DS_TELEFONO AS DS_TELEFONO, -- "Telefono"
        T.DS_EMAIL_UTENTE AS DS_EMAIL_UTENTE, --"Email (per Ivass obbligatorio)"
        T.CD_PROFILO_SICUREZZA AS CD_PROFILO_SICUREZZA, --"Profilo sicurezza"
        T.CD_OPERATORE_CONTABILE AS CD_OPERATORE_CONTABILE, --"Operatore contabile"
        T.CD_CANALI_ABBINATI AS CD_CANALI_ABBINATI, --"Canali abbinati (da definire se ci sia un numero massimo di canali)"
        T.FL_CAPO_CATENA AS FL_CAPO_CATENA, --"Capo Catena S/N"
        T.CD_OPERATORE AS CD_OPERATORE, --"Codice operatore"
        T.CD_RECUPERATORI AS CD_RECUPERATORI, --"Codici recuperatori"
        T.CD_FILIALE AS CD_FILIALE, --"Codici Filiali (entità OCS; da definire se ci sia un numero massimo di filiali)"
        T.CD_AREA AS CD_AREA, --"Codice Area (entità OCS)"
        T.CD_DISTRETTO AS CD_DISTRETTO, --"Codice Distretto (entità OCS)"
        BA.UTE_TUTTE_FILIALI AS FL_TUTTE_FILIALI,
        BA.UTE_RESPONSABILE AS FL_RESPONSABILE,
        BA.UTE_ABIL_SAS AS FL_ABIL_SAS,
        BA.UTE_PROFILO AS TP_PROFILO,
        BA.UTE_TIPO_ACCESSO AS TP_ACCESSO,
        BA.UTE_APPLICAZIONE AS CD_APPLICAZIONE,
        T.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
    --FROM { re('4338_responsabile_active') }} T
    LEFT JOIN {{ ref('bauserarc') }} BA
        ON T."Codice Utente" = BA.UTE_CODICE
    WHERE T.FL_DELETED = 'N'

),

dedup AS (

    SELECT
        CD_UTENZA,
        CD_TIPOLOGIA_UTENTE,
        CD_INTERMEDIARIO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_RESPONSABILE_AD,
        DS_UTENZA,
        DS_TELEFONO,
        DS_EMAIL_UTENTE,
        CD_PROFILO_SICUREZZA,
        CD_OPERATORE_CONTABILE,
        CD_CANALI_ABBINATI,
        FL_CAPO_CATENA,
        CD_OPERATORE,
        CD_RECUPERATORI,
        CD_FILIALE,
        CD_AREA,
        CD_DISTRETTO,
        FL_TUTTE_FILIALI,
        FL_RESPONSABILE,
        FL_ABIL_SAS,
        TP_PROFILO,
        TP_ACCESSO,
        CD_APPLICAZIONE,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_UTENZA', 'CD_TIPOLOGIA_UTENTE', 'CD_INTERMEDIARIO', 'CD_RESPONSABILE_AD', 'DS_UTENZA', 'DS_TELEFONO', 'DS_EMAIL_UTENTE', 'CD_PROFILO_SICUREZZA', 'CD_OPERATORE_CONTABILE', 'CD_CANALI_ABBINATI', 'FL_CAPO_CATENA', 'CD_OPERATORE', 'CD_RECUPERATORI', 'CD_FILIALE', 'CD_AREA', 'CD_DISTRETTO', 'FL_TUTTE_FILIALI', 'FL_RESPONSABILE', 'FL_ABIL_SAS', 'TP_PROFILO', 'TP_ACCESSO', 'CD_APPLICAZIONE']) }} AS HASHED_COLS
    FROM base
    {{ is_incremental_S1('CD_UTENZA, CD_TIPOLOGIA_UTENTE, CD_INTERMEDIARIO, TS_INIZIO_VALIDITA') }}

)

SELECT
    D.CD_UTENZA,
    D.CD_TIPOLOGIA_UTENTE,
    D.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('CD_UTENZA, CD_TIPOLOGIA_UTENTE, CD_INTERMEDIARIO', 'TS_INIZIO_VALIDITA') }} AS TS_FV_NEXT,
    --D.TS_FINE_VALIDITA,
    D.CD_INTERMEDIARIO,
    D.CD_RESPONSABILE_AD,
    D.DS_UTENZA,
    D.DS_TELEFONO,
    D.DS_EMAIL_UTENTE,
    D.CD_PROFILO_SICUREZZA,
    D.CD_OPERATORE_CONTABILE,
    D.CD_CANALI_ABBINATI,
    D.FL_CAPO_CATENA,
    D.CD_OPERATORE,
    D.CD_RECUPERATORI,
    D.CD_FILIALE,
    D.CD_AREA,
    D.CD_DISTRETTO,
    D.FL_TUTTE_FILIALI,
    D.FL_RESPONSABILE,
    D.FL_ABIL_SAS,
    D.TP_PROFILO,
    D.TP_ACCESSO,
    D.CD_APPLICAZIONE,
    D.LASTMODIFIEDDATA

FROM dedup D
