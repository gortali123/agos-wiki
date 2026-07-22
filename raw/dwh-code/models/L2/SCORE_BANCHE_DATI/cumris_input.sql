-- =============================================================================
-- L2 SCORING - CUMRIS_INPUT
-- Sorgente: landing CDE (payload XML StrategyOneRequest, ProcessCode = 'CUMRIS')
-- Storicizzazione: S2 (incremental / append)
-- Grana: un record per Rapporto -> PK (CD_INQUIRYCODE, CD_CONTROPARTE, CD_RAPPORTO)
-- Struttura payload:
--   StrategyOneRequest
--   |-- Header (InquiryCode, ProcessCode)
--   `-- Body/Richiesta (RequestRichiestaType)
--       |-- Variables                       -> campi livello richiesta
--       `-- Categories/Applicant [ripetuto] (RequestApplicantType)
--           |-- Variables                   -> campi livello soggetto (controparte)
--           `-- Categories/Rapporto [ripetuto] (RequestRapportoType)
--               `-- Variables               -> campi livello rapporto
-- NOTE / ASSUNZIONI (vedi riepilogo in chat):
--  * ASSUNZIONE: landing = ref('cde'); VALIDARE nome reale del modello dbt.
--  * ASSUNZIONE: filtro ProcessCode = 'CUMRIS' (dal PERIMETRO del Catalogo Entita').
--    Lo xsd dichiara ProcessCode fixed="CUMRISX": allineare al valore reale in produzione.
--  * ASSUNZIONE: campi EU_ castati a NUMBER(16,2) SENZA divisione per 100, perche' lo
--    xsd li dichiara xs:decimal(totalDigits=16) (valore gia' con separatore decimale).
--    Se in produzione il payload codifica gli importi in centesimi interi, aggiungere / 100.
--  * Su richiesta utente: campo tecnico finale = TS_RIFERIMENTO (al posto di LASTMODIFIEDDATA),
--    usato anche come colonna di change-tracking del blocco incrementale S2.
-- =============================================================================

WITH src AS (

    SELECT
        VALUE AS xml_doc,
        TS_RIFERIMENTO
    FROM {{ ref('cde') }}          -- ASSUNZIONE: modello landing = ref('cde'); VALIDARE nome reale
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneRequest'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'CUMRIS'

    {% if is_incremental() %}
        AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

-- Nodi intermedi riusati (livello richiesta), scesi dentro il root StrategyOneRequest
nodes AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Categories') AS n_req_cat
    FROM src

),

-- FLATTEN degli Applicant (livello soggetto/controparte)
applicants AS (

    SELECT
        n.TS_RIFERIMENTO,
        n.n_header,
        n.n_req_var,
        XMLGET(A.value, 'Variables')  AS n_app_var,
        XMLGET(A.value, 'Categories') AS n_app_cat
    FROM nodes n,
    {{ flatten_xml('n.n_req_cat', 'Applicant', 'A') }}

),

-- FLATTEN dei Rapporto dentro ogni Applicant (grana finale)
rapporti AS (

    SELECT
        a.TS_RIFERIMENTO,
        a.n_header,
        a.n_req_var,
        a.n_app_var,
        XMLGET(R.value, 'Variables') AS n_rap_var
    FROM applicants a,
    {{ flatten_xml('a.n_app_cat', 'Rapporto', 'R') }}

),

-- Estrazione: tutti i valori in VARCHAR (solo get_xml_path, nessuna conversione qui)
extract_raw AS (

    SELECT
        TS_RIFERIMENTO,
        -- PK
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }}                    AS CD_INQUIRYCODE,
        {{ get_xml_path('n_app_var', 'CD_CONTROPARTE', 'VARCHAR') }}                AS CD_CONTROPARTE,
        {{ get_xml_path('n_rap_var', 'CD_RAPPORTO', 'VARCHAR') }}                   AS CD_RAPPORTO,
        -- livello richiesta
        {{ get_xml_path('n_req_var', 'USER_CODE', 'VARCHAR') }}                     AS CD_USER_CODE,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }}                AS DT_RICHIESTA_RAW,
        {{ get_xml_path('n_req_var', 'CD_PRATICA', 'VARCHAR') }}                    AS CD_PRATICA,
        {{ get_xml_path('n_req_var', 'CD_PRATICA_MATCH', 'VARCHAR') }}              AS CD_PRATICA_MATCH,
        {{ get_xml_path('n_req_var', 'CODICE_PROCEDURA', 'VARCHAR') }}              AS CD_PROCEDURA,
        -- livello soggetto (Applicant)
        {{ get_xml_path('n_app_var', 'TP_PARTECIPAZIONE', 'VARCHAR') }}             AS TP_PARTECIPAZIONE,
        -- livello rapporto
        {{ get_xml_path('n_rap_var', 'CD_BAN_DATI', 'VARCHAR') }}                   AS CD_BAN_DATI,
        {{ get_xml_path('n_rap_var', 'NM_PROGRES', 'VARCHAR') }}                    AS NM_PROGRES_RAW,
        {{ get_xml_path('n_rap_var', 'CD_PRATICA_DET', 'VARCHAR') }}                AS CD_PRATICA_DET,
        {{ get_xml_path('n_rap_var', 'CODICE_ENTE_FINANZIATORE', 'VARCHAR') }}      AS CD_ENTE_FINANZIATORE,
        {{ get_xml_path('n_rap_var', 'TP_PARTECIPAZIONE_DET', 'VARCHAR') }}         AS TP_PARTECIPAZIONE_DET,
        {{ get_xml_path('n_rap_var', 'TIPO_OPERAZIONE', 'VARCHAR') }}               AS TP_OPERAZIONE,
        {{ get_xml_path('n_rap_var', 'SOTTOTIPO_OPERAZIONE', 'VARCHAR') }}          AS CD_SOTTOTIPO_OPERAZIONE,
        {{ get_xml_path('n_rap_var', 'CD_RICHIESTA_EXPE', 'VARCHAR') }}             AS CD_RICHIESTA_EXPE,
        {{ get_xml_path('n_rap_var', 'IN_CRIF_ALTRO_AGOS', 'VARCHAR') }}            AS FL_CRIF_ALTRO_AGOS,
        {{ get_xml_path('n_rap_var', 'IN_EXPE_ALTRO_AGOS', 'VARCHAR') }}            AS FL_EXPE_ALTRO_AGOS,
        {{ get_xml_path('n_rap_var', 'FASE_OPERAZIONE', 'VARCHAR') }}               AS CD_FASE_OPERAZIONE,
        {{ get_xml_path('n_rap_var', 'DT_INIZIO_OPERAZ', 'VARCHAR') }}              AS DT_INIZIO_OPERAZ_RAW,
        {{ get_xml_path('n_rap_var', 'DATA_RICHIESTA_FINANZIAMENTO', 'VARCHAR') }}  AS DT_RICHIESTA_FINANZIAMENTO_RAW,
        {{ get_xml_path('n_rap_var', 'DT_FINE_OPERAZ', 'VARCHAR') }}                AS DT_FINE_OPERAZ_RAW,
        {{ get_xml_path('n_rap_var', 'DT_ULT_AGGIOR', 'VARCHAR') }}                 AS DT_ULT_AGGIOR_RAW,
        {{ get_xml_path('n_rap_var', 'IMPORTO_RATA_MENSILE', 'VARCHAR') }}          AS EU_IMPORTO_RATA_MENSILE_RAW,
        {{ get_xml_path('n_rap_var', 'NUMERO_RATE', 'VARCHAR') }}                   AS NM_NUMERO_RATE_RAW,
        {{ get_xml_path('n_rap_var', 'IMPORTO_RATE_RESIDUE', 'VARCHAR') }}          AS EU_IMPORTO_RATE_RESIDUE_RAW,
        {{ get_xml_path('n_rap_var', 'IMPORTO_CAPITALE_RICHIESTO', 'VARCHAR') }}    AS EU_IMPORTO_CAPITALE_RICHIESTO_RAW,
        {{ get_xml_path('n_rap_var', 'IMPORTO_RATE_SCADUTE', 'VARCHAR') }}          AS EU_IMPORTO_RATE_SCADUTE_RAW,
        {{ get_xml_path('n_rap_var', 'NUMERO_RATE_SCADUTE', 'VARCHAR') }}           AS NM_NUMERO_RATE_SCADUTE_RAW,
        {{ get_xml_path('n_rap_var', 'NUMERO_RATE_RESIDUE', 'VARCHAR') }}           AS NM_NUMERO_RATE_RESIDUE_RAW,
        {{ get_xml_path('n_rap_var', 'PERIODICITA_RATE', 'VARCHAR') }}              AS CD_PERIODICITA_RATE,
        {{ get_xml_path('n_rap_var', 'IMPORTO_FIDO', 'VARCHAR') }}                  AS EU_IMPORTO_FIDO_RAW,
        {{ get_xml_path('n_rap_var', 'EU_AEU_RATA', 'VARCHAR') }}                   AS EU_AEU_RATA_RAW,
        {{ get_xml_path('n_rap_var', 'EU_RISC_RIL', 'VARCHAR') }}                   AS EU_RISC_RIL_RAW,
        {{ get_xml_path('n_rap_var', 'EU_RISC_ATT', 'VARCHAR') }}                   AS EU_RISC_ATT_RAW,
        {{ get_xml_path('n_rap_var', 'IN_ELIMINA_X_RSD', 'VARCHAR') }}              AS FL_ELIMINA_X_RSD,
        {{ get_xml_path('n_rap_var', 'IN_ELIMINA_ALTRO2', 'VARCHAR') }}             AS FL_ELIMINA_ALTRO2,
        {{ get_xml_path('n_rap_var', 'TP_TRAT_RATA_ATRIB', 'VARCHAR') }}            AS TP_TRAT_RATA_ATRIB,
        {{ get_xml_path('n_rap_var', 'CD_BAN_DATI_ORIGINALE', 'VARCHAR') }}         AS CD_BAN_DATI_ORIGINALE,
        {{ get_xml_path('n_rap_var', 'TX_IDENTIF_DET', 'VARCHAR') }}                AS CD_TX_IDENTIF_DET
    FROM rapporti

),

-- Conversione: tipizzazione dai VARCHAR (TRY_CAST / TRY_TO_DATE sul nome colonna *_RAW)
conv AS (

    SELECT
        TS_RIFERIMENTO,
        CD_INQUIRYCODE,
        CD_CONTROPARTE,
        CD_RAPPORTO,
        CD_USER_CODE,
        TRY_TO_DATE(DT_RICHIESTA_RAW)                          AS DT_RICHIESTA,
        CD_PRATICA,
        CD_PRATICA_MATCH,
        CD_PROCEDURA,
        TP_PARTECIPAZIONE,
        CD_BAN_DATI,
        TRY_CAST(NM_PROGRES_RAW AS NUMBER(16,0))               AS NM_PROGRES,
        CD_PRATICA_DET,
        CD_ENTE_FINANZIATORE,
        TP_PARTECIPAZIONE_DET,
        TP_OPERAZIONE,
        CD_SOTTOTIPO_OPERAZIONE,
        CD_RICHIESTA_EXPE,
        FL_CRIF_ALTRO_AGOS,
        FL_EXPE_ALTRO_AGOS,
        CD_FASE_OPERAZIONE,
        TRY_TO_DATE(DT_INIZIO_OPERAZ_RAW)                      AS DT_INIZIO_OPERAZ,
        TRY_TO_DATE(DT_RICHIESTA_FINANZIAMENTO_RAW)            AS DT_RICHIESTA_FINANZIAMENTO,
        TRY_TO_DATE(DT_FINE_OPERAZ_RAW)                        AS DT_FINE_OPERAZ,
        TRY_TO_DATE(DT_ULT_AGGIOR_RAW)                         AS DT_ULT_AGGIOR,
        TRY_CAST(EU_IMPORTO_RATA_MENSILE_RAW AS NUMBER(16,2))  AS EU_IMPORTO_RATA_MENSILE,
        TRY_CAST(NM_NUMERO_RATE_RAW AS NUMBER(16,0))           AS NM_NUMERO_RATE,
        TRY_CAST(EU_IMPORTO_RATE_RESIDUE_RAW AS NUMBER(16,2))  AS EU_IMPORTO_RATE_RESIDUE,
        TRY_CAST(EU_IMPORTO_CAPITALE_RICHIESTO_RAW AS NUMBER(16,2)) AS EU_IMPORTO_CAPITALE_RICHIESTO,
        TRY_CAST(EU_IMPORTO_RATE_SCADUTE_RAW AS NUMBER(16,2))  AS EU_IMPORTO_RATE_SCADUTE,
        TRY_CAST(NM_NUMERO_RATE_SCADUTE_RAW AS NUMBER(16,0))   AS NM_NUMERO_RATE_SCADUTE,
        TRY_CAST(NM_NUMERO_RATE_RESIDUE_RAW AS NUMBER(16,0))   AS NM_NUMERO_RATE_RESIDUE,
        CD_PERIODICITA_RATE,
        TRY_CAST(EU_IMPORTO_FIDO_RAW AS NUMBER(16,2))          AS EU_IMPORTO_FIDO,
        TRY_CAST(EU_AEU_RATA_RAW AS NUMBER(16,2))              AS EU_AEU_RATA,
        TRY_CAST(EU_RISC_RIL_RAW AS NUMBER(16,2))              AS EU_RISC_RIL,
        TRY_CAST(EU_RISC_ATT_RAW AS NUMBER(16,2))              AS EU_RISC_ATT,
        FL_ELIMINA_X_RSD,
        FL_ELIMINA_ALTRO2,
        TP_TRAT_RATA_ATRIB,
        CD_BAN_DATI_ORIGINALE,
        CD_TX_IDENTIF_DET
    FROM extract_raw

)

SELECT
    CD_INQUIRYCODE,
    CD_CONTROPARTE,
    CD_RAPPORTO,
    TS_RIFERIMENTO AS TS_INSERIMENTO,
    CD_USER_CODE,
    DT_RICHIESTA,
    CD_PRATICA,
    CD_PRATICA_MATCH,
    CD_PROCEDURA,
    TP_PARTECIPAZIONE,
    CD_BAN_DATI,
    NM_PROGRES,
    CD_PRATICA_DET,
    CD_ENTE_FINANZIATORE,
    TP_PARTECIPAZIONE_DET,
    TP_OPERAZIONE,
    CD_SOTTOTIPO_OPERAZIONE,
    CD_RICHIESTA_EXPE,
    FL_CRIF_ALTRO_AGOS,
    FL_EXPE_ALTRO_AGOS,
    CD_FASE_OPERAZIONE,
    DT_INIZIO_OPERAZ,
    DT_RICHIESTA_FINANZIAMENTO,
    DT_FINE_OPERAZ,
    DT_ULT_AGGIOR,
    EU_IMPORTO_RATA_MENSILE,
    NM_NUMERO_RATE,
    EU_IMPORTO_RATE_RESIDUE,
    EU_IMPORTO_CAPITALE_RICHIESTO,
    EU_IMPORTO_RATE_SCADUTE,
    NM_NUMERO_RATE_SCADUTE,
    NM_NUMERO_RATE_RESIDUE,
    CD_PERIODICITA_RATE,
    EU_IMPORTO_FIDO,
    EU_AEU_RATA,
    EU_RISC_RIL,
    EU_RISC_ATT,
    FL_ELIMINA_X_RSD,
    FL_ELIMINA_ALTRO2,
    TP_TRAT_RATA_ATRIB,
    CD_BAN_DATI_ORIGINALE,
    CD_TX_IDENTIF_DET
FROM conv
