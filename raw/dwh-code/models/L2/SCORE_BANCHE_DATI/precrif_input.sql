-- Modello L2 SCORING.PRECRIF_INPUT
-- Sorgente: landing XML CDE (StrategyOneRequest), ProcessCode = 'PRECRIF'.
-- Storicizzazione: S2 (incremental / append). Grana per soggetto: PK = (CD_INQUIRYCODE, CD_RUOLO).
--   -> i campi a livello pratica (Richiesta/Variables) e Header sono comuni a tutti gli
--      applicant del documento; i campi a livello soggetto vengono dal FLATTEN degli Applicant.
-- ASSUNZIONE landing: modello dbt = ref('cde'), colonna VALUE gia' variant (nessun PARSE_XML).
-- ASSUNZIONE ProcessCode filtro = 'PRECRIF' (da Regola Tecnica Perimetro del Catalogo Entita').
--   Lo xsd dichiara invece Header/ProcessCode fixed="PRECRIFX": verificare su payload reale
--   quale valore compaia davvero, altrimenti il modello puo' risultare vuoto.
-- NOTA S2: il data model non espone TS_INSERIMENTO ne' LASTMODIFIEDDATA per questa entita'
--   e la landing CDE non ha LASTMODIFIEDDATA. TS_INSERIMENTO -> CURRENT_TIMESTAMP() (WARN).
--   Il blocco incrementale S2 standard filtra su LASTMODIFIEDDATA, qui assente: riconciliare
--   la strategia incrementale con code-generator-l2 / referente prima della produzione.

WITH src AS (

    SELECT
        TS_RIFERIMENTO,
        VALUE AS xml_doc
    FROM {{ ref('cde') }}          -- ASSUNZIONE: modello landing = ref('cde'); VALIDARE nome reale
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneRequest'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'PRECRIF'
    {% if is_incremental() %}
      AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

-- Nodi intermedi riusati: si scende prima nel root StrategyOneRequest, poi Body/Richiesta.
nodes AS (

    SELECT
    TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

-- Livello pratica (Header + Richiesta/Variables): un record per documento, VARCHAR grezzo.
req_raw AS (

    SELECT
        TS_RIFERIMENTO AS TS_INSERIMENTO,
        n_categories,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }}                     AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }}                     AS CD_PROCESSCODE,
        {{ get_xml_path('n_req_var', 'CODICE_INTERROGAZIONE', 'VARCHAR') }}          AS CD_INTERROGAZIONE_RAW,
        {{ get_xml_path('n_req_var', 'USER_CODE', 'VARCHAR') }}                      AS CD_USER_CODE,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }}                 AS DT_RICHIESTA_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_PROCEDURA', 'VARCHAR') }}               AS CD_PROCEDURA,
        {{ get_xml_path('n_req_var', 'CODICE_PRATICA', 'VARCHAR') }}                 AS CD_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'PRESCREENING_ESITO_CODICE', 'VARCHAR') }}      AS CD_PRESCREENING_ESITO,
        {{ get_xml_path('n_req_var', 'PRATICHE_IN_VOLO', 'VARCHAR') }}               AS CD_PRATICHE_IN_VOLO,
        {{ get_xml_path('n_req_var', 'NM_RATE_1PERIODO', 'VARCHAR') }}               AS NM_RATE_1PERIODO_RAW,
        {{ get_xml_path('n_req_var', 'NM_RATE_2PERIODO', 'VARCHAR') }}               AS NM_RATE_2PERIODO_RAW,
        {{ get_xml_path('n_req_var', 'IMPORTO_RATA_1PERIODO', 'VARCHAR') }}          AS EU_IMPORTO_RATA_1PERIODO_RAW,
        {{ get_xml_path('n_req_var', 'IMPORTO_RATA_2PERIODO', 'VARCHAR') }}          AS EU_IMPORTO_RATA_2PERIODO_RAW,
        {{ get_xml_path('n_req_var', 'MODALITA_PAGAMENTO', 'VARCHAR') }}             AS CD_MODALITA_PAGAMENTO,
        {{ get_xml_path('n_req_var', 'TABELLA_FINANZIARIA', 'VARCHAR') }}            AS CD_TABELLA_FINANZIARIA,
        {{ get_xml_path('n_req_var', 'PREZZO_BENE', 'VARCHAR') }}                    AS EU_PREZZO_BENE_RAW,
        {{ get_xml_path('n_req_var', 'IMPORTO_FINANZIATO', 'VARCHAR') }}             AS EU_IMPORTO_FINANZIATO_RAW,
        {{ get_xml_path('n_req_var', 'ANTICIPO', 'VARCHAR') }}                       AS EU_ANTICIPO_RAW,
        -- FIX: data model 'DT_DECORRENZA_1ACQUISTO' -> tag xsd reale 'DT_DECORREZA_1ACQUISTO' (typo nello xsd)
        {{ get_xml_path('n_req_var', 'DT_DECORRENZA_1ACQUISTO', 'VARCHAR') }}         AS DT_DECORRENZA_1ACQUISTO_RAW,
        {{ get_xml_path('n_req_var', 'EMETTITORE', 'VARCHAR') }}                     AS CD_EMETTITORE,
        {{ get_xml_path('n_req_var', 'TIPO_VENDITA_CONGIUNTA', 'VARCHAR') }}         AS FL_TIPO_VENDITA_CONGIUNTA,
        {{ get_xml_path('n_req_var', 'TIPO_PRODOTTO', 'VARCHAR') }}                  AS CD_PRODOTTO,
        {{ get_xml_path('n_req_var', 'PRODOTTO', 'VARCHAR') }}                       AS TP_PRODOTTO,
        {{ get_xml_path('n_req_var', 'DESTINAZIONE_FINANZIAMENTO', 'VARCHAR') }}     AS TP_DESTINAZIONE_FINANZIAMENTO,
        {{ get_xml_path('n_req_var', 'DATA_GIA_CORRENTISTA', 'VARCHAR') }}           AS DT_GIA_CORRENTISTA_RAW,
        {{ get_xml_path('n_req_var', 'CANALE', 'VARCHAR') }}                         AS CD_CANALE,
        {{ get_xml_path('n_req_var', 'CANALE_WEB', 'VARCHAR') }}                     AS FL_CANALE_WEB,
        {{ get_xml_path('n_req_var', 'DATA_CARICAMENTO', 'VARCHAR') }}               AS DT_CARICAMENTO_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_AREA', 'VARCHAR') }}                    AS CD_AREA,
        {{ get_xml_path('n_req_var', 'CODICE_DISTRETTO', 'VARCHAR') }}               AS CD_DISTRETTO,
        {{ get_xml_path('n_req_var', 'CODICE_FILIALE', 'VARCHAR') }}                 AS CD_FILIALE,
        {{ get_xml_path('n_req_var', 'RETE_VENDITA', 'VARCHAR') }}                   AS DS_RETE_VENDITA,
        {{ get_xml_path('n_req_var', 'MacroArea_Rete_Vendita', 'VARCHAR') }}         AS DS_MACROAREA_RETE_VENDITA,
        {{ get_xml_path('n_req_var', 'Stato_Rete_Vendita', 'VARCHAR') }}             AS TP_STATO_RETE_VENDITA,
        {{ get_xml_path('n_req_var', 'Attributo_Rete_Vendita', 'VARCHAR') }}         AS CD_ATTRIBUTO_RETE_VENDITA,
        {{ get_xml_path('n_req_var', 'Tipologia_Rete_Vendita', 'VARCHAR') }}         AS TP_RETE_VENDITA,
        {{ get_xml_path('n_req_var', 'AGENTE', 'VARCHAR') }}                         AS CD_AGENTE,
        {{ get_xml_path('n_req_var', 'MacroArea_Agente', 'VARCHAR') }}               AS DS_MACROAREA_AGENTE,
        {{ get_xml_path('n_req_var', 'Stato_Agente', 'VARCHAR') }}                   AS TP_STATO_AGENTE,
        {{ get_xml_path('n_req_var', 'Attributo_Agente', 'VARCHAR') }}               AS CD_ATTRIBUTO_AGENTE,
        {{ get_xml_path('n_req_var', 'Tipologia_Agente', 'VARCHAR') }}               AS TP_AGENTE,
        {{ get_xml_path('n_req_var', 'SUBAGENTE', 'VARCHAR') }}                      AS CD_SUBAGENTE,
        {{ get_xml_path('n_req_var', 'MacroArea_Subagente', 'VARCHAR') }}            AS DS_MACROAREA_SUBAGENTE,
        {{ get_xml_path('n_req_var', 'Stato_Subagente', 'VARCHAR') }}                AS TP_STATO_SUBAGENTE,
        {{ get_xml_path('n_req_var', 'Attributo_Subagente', 'VARCHAR') }}            AS CD_ATTRIBUTO_SUBAGENTE,
        {{ get_xml_path('n_req_var', 'Tipologia_Subagente', 'VARCHAR') }}            AS TP_SUBAGENTE,
        {{ get_xml_path('n_req_var', 'CONVENZIONATO', 'VARCHAR') }}                  AS CD_CONVENZIONATO,
        {{ get_xml_path('n_req_var', 'MacroArea_Convenzionato', 'VARCHAR') }}        AS DS_MACROAREA_CONVENZIONATO,
        {{ get_xml_path('n_req_var', 'Stato_Convenzionato', 'VARCHAR') }}            AS TP_STATO_CONVENZIONATO,
        {{ get_xml_path('n_req_var', 'Attributo_Convenzionato', 'VARCHAR') }}        AS CD_ATTRIBUTO_CONVENZIONATO,
        {{ get_xml_path('n_req_var', 'Tipologia_Convenzionato', 'VARCHAR') }}        AS TP_CONVENZIONATO,
        -- WARN: PUNTO_VENDITA (5 campi) assenti in questo xsd (nessun tag *Punto_vendita*): NULL
        {{ get_xml_path('n_req_var', 'VENDITORE', 'VARCHAR') }}                      AS CD_VENDITORE,
        {{ get_xml_path('n_req_var', 'MacroArea_Venditore', 'VARCHAR') }}            AS DS_MACROAREA_VENDITORE,
        {{ get_xml_path('n_req_var', 'Stato_Venditore', 'VARCHAR') }}               AS CD_STATO_VENDITORE,
        {{ get_xml_path('n_req_var', 'Attributo_Venditore', 'VARCHAR') }}            AS CD_ATTRIBUTO_VENDITORE,
        {{ get_xml_path('n_req_var', 'Tipologia_Venditore', 'VARCHAR') }}            AS TP_VENDITORE,
        {{ get_xml_path('n_req_var', 'CODICE_INTERMEDIARIO', 'VARCHAR') }}           AS CD_INTERMEDIARIO,
        {{ get_xml_path('n_req_var', 'TIPO_INTERMEDIARIO', 'VARCHAR') }}             AS TP_INTERMEDIARIO,
        {{ get_xml_path('n_req_var', 'STATO_INTERMEDIARIO', 'VARCHAR') }}            AS CD_STATO_INTERMEDIARIO,
        {{ get_xml_path('n_req_var', 'ATTRIBUTO_INTERMEDIARIO', 'VARCHAR') }}        AS CD_ATTRIBUTO_INTERMEDIARIO,
        {{ get_xml_path('n_req_var', 'TIPOLOGIA_INTERMEDIARIO', 'VARCHAR') }}        AS DS_TIPOLOGIA_INTERMEDIARIO
    FROM nodes

),

-- Livello soggetto: FLATTEN degli Applicant sotto Categories; ogni riga = un soggetto.
app_flat AS (

    SELECT
        r.CD_INQUIRYCODE,
        r.TS_INSERIMENTO,
        XMLGET(F.value, 'Variables') AS n_app_var
    FROM req_raw r,
    {{ flatten_xml('r.n_categories', 'Applicant', 'F') }}

),

app_raw AS (

    SELECT
        CD_INQUIRYCODE,
        TS_INSERIMENTO,
        {{ get_xml_path('n_app_var', 'RUOLO', 'VARCHAR') }}                                  AS CD_RUOLO,
        {{ get_xml_path('n_app_var', 'LAST_EURISC_INC_CLI_CBSCORE', 'VARCHAR') }}            AS NM_LAST_EURISC_INC_CLI_CBSCORE,
        {{ get_xml_path('n_app_var', 'LAST_EURISC_INC_CLI_NOHIT', 'VARCHAR') }}              AS FL_LAST_EURISC_INC_CLI_NOHIT,
        {{ get_xml_path('n_app_var', 'LAST_EURISC_INC_CLI_DATA_CARICAMENTO', 'VARCHAR') }}   AS DT_LAST_EURISC_INC_CLI_DATA_CARICAMENTO_RAW,
        {{ get_xml_path('n_app_var', 'LAST_EURISC_INC_CLI_DATA_ELABORAZIONE', 'VARCHAR') }}  AS DT_LAST_EURISC_INC_CLI_DATA_ELABORAZIONE_RAW,
        {{ get_xml_path('n_app_var', 'LAST_EURISC_INC_CLI_CODICE_PRATICA', 'VARCHAR') }}     AS CD_LAST_EURISC_INC_CLI_CODICE_PRATICA,
        {{ get_xml_path('n_app_var', 'LAST_EURISC_INC_CLI_PROCEDURA', 'VARCHAR') }}          AS CD_LAST_EURISC_INC_CLI_PROCEDURA,
        {{ get_xml_path('n_app_var', 'CODICE_ANAGRAFICA', 'VARCHAR') }}                      AS CD_ANAGRAFICA_RAW,
        {{ get_xml_path('n_app_var', 'FLAG_DIPENDENTE', 'VARCHAR') }}                        AS FL_DIPENDENTE,
        {{ get_xml_path('n_app_var', 'FORMA_GIURIDICA', 'VARCHAR') }}                        AS CD_FORMA_GIURIDICA,
        {{ get_xml_path('n_app_var', 'DATA_NASCITA', 'VARCHAR') }}                           AS DT_NASCITA_RAW,
        {{ get_xml_path('n_app_var', 'DT_INIZIO_OCCUPAZIONE', 'VARCHAR') }}                  AS DT_INIZIO_OCCUPAZIONE,
        {{ get_xml_path('n_app_var', 'DURATA_CONTRATTO_LAVORO', 'VARCHAR') }}                AS NM_DURATA_CONTRATTO_LAVORO,
        {{ get_xml_path('n_app_var', 'PARTITA_IVA', 'VARCHAR') }}                            AS CD_PARTITA_IVA_RAW,
        {{ get_xml_path('n_app_var', 'CD_TIPO_CLIENTE', 'VARCHAR') }}                        AS TP_CLIENTE,
        {{ get_xml_path('n_app_var', 'STATO_CIVILE', 'VARCHAR') }}                           AS CD_STATO_CIVILE,
        {{ get_xml_path('n_app_var', 'OCCUPAZIONE', 'VARCHAR') }}                            AS CD_OCCUPAZIONE,
        {{ get_xml_path('n_app_var', 'TIPO_CONTRATTO_LAVORO', 'VARCHAR') }}                  AS CD_TIPO_CONTRATTO_LAVORO,
        {{ get_xml_path('n_app_var', 'TIPO_ATTIVITA', 'VARCHAR') }}                          AS CD_TIPO_ATTIVITA,
        {{ get_xml_path('n_app_var', 'TIPO_ABITAZIONE', 'VARCHAR') }}                        AS CD_TIPO_ABITAZIONE,
        {{ get_xml_path('n_app_var', 'CTCPOS_STATO', 'VARCHAR') }}                           AS CD_CTCPOS_STATO,
        {{ get_xml_path('n_app_var', 'CTCPOS_Hit_Nohit', 'VARCHAR') }}                       AS FL_CTCPOS_HIT_NOHIT,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_COMPLETO_DT', 'VARCHAR') }}               AS DT_CTCPOS_SCORE_COMPLETO_DT,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_COMPLETO_FASCIA', 'VARCHAR') }}           AS CD_CTCPOS_SCORE_COMPLETO_FASCIA,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_COMPLETO', 'VARCHAR') }}                  AS NM_CTCPOS_SCORE_COMPLETO,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_COMPORTAMENTALE_DT', 'VARCHAR') }}        AS DT_CTCPOS_SCORE_COMPORTAMENTALE_DT,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_COMPORTAMENTALE_FASCIA', 'VARCHAR') }}    AS CD_CTCPOS_SCORE_COMPORTAMENTALE_FASCIA,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_COMPORTAMENTALE', 'VARCHAR') }}           AS NM_CTCPOS_SCORE_COMPORTAMENTALE,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_SOCIODEMO_DT', 'VARCHAR') }}              AS DT_CTCPOS_SCORE_SOCIODEMO_DT,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_SOCIODEMO_FASCIA', 'VARCHAR') }}          AS CD_CTCPOS_SCORE_SOCIODEMO_FASCIA,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_SOCIODEMO', 'VARCHAR') }}                 AS NM_CTCPOS_SCORE_SOCIODEMO,
        {{ get_xml_path('n_app_var', 'CTCPOS_SCORE_SEGMENTO', 'VARCHAR') }}                  AS CD_CTCPOS_SCORE_SEGMENTO
    FROM app_flat

)

-- Conversione tipi (TRY_CAST/TRY_TO_DATE sui VARCHAR gia' estratti) + SELECT finale per soggetto.
SELECT
    r.CD_INQUIRYCODE                                        AS CD_INQUIRYCODE,
    a.CD_RUOLO                                              AS CD_RUOLO,
    r.TS_INSERIMENTO,
    r.CD_PROCESSCODE                                        AS CD_PROCESSCODE,
    TRY_CAST(r.CD_INTERROGAZIONE_RAW AS NUMBER(16,0))       AS CD_INTERROGAZIONE,
    r.CD_USER_CODE                                          AS CD_USER_CODE,
    TRY_TO_DATE(r.DT_RICHIESTA_RAW)                         AS DT_RICHIESTA,
    r.CD_PROCEDURA                                          AS CD_PROCEDURA,
    TRY_CAST(r.CD_PRATICA_RAW AS NUMBER(16,0))              AS CD_PRATICA,
    r.CD_PRESCREENING_ESITO                                 AS CD_PRESCREENING_ESITO,
    r.CD_PRATICHE_IN_VOLO                                   AS CD_PRATICHE_IN_VOLO,
    TRY_CAST(r.NM_RATE_1PERIODO_RAW AS NUMBER(16,0))        AS NM_RATE_1PERIODO,
    TRY_CAST(r.NM_RATE_2PERIODO_RAW AS NUMBER(16,0))        AS NM_RATE_2PERIODO,
    TRY_CAST(r.EU_IMPORTO_RATA_1PERIODO_RAW AS NUMBER(16,2)) AS EU_IMPORTO_RATA_1PERIODO,
    TRY_CAST(r.EU_IMPORTO_RATA_2PERIODO_RAW AS NUMBER(16,2)) AS EU_IMPORTO_RATA_2PERIODO,
    r.CD_MODALITA_PAGAMENTO                                 AS CD_MODALITA_PAGAMENTO,
    r.CD_TABELLA_FINANZIARIA                                AS CD_TABELLA_FINANZIARIA,
    TRY_CAST(r.EU_PREZZO_BENE_RAW AS NUMBER(16,2)) AS EU_PREZZO_BENE,
    TRY_CAST(r.EU_IMPORTO_FINANZIATO_RAW AS NUMBER(16,2)) AS EU_IMPORTO_FINANZIATO,
    TRY_CAST(r.EU_ANTICIPO_RAW AS NUMBER(16,2)) AS EU_ANTICIPO,
    TRY_TO_DATE(r.DT_DECORRENZA_1ACQUISTO_RAW)              AS DT_DECORRENZA_1ACQUISTO,
    r.CD_EMETTITORE                                         AS CD_EMETTITORE,
    r.FL_TIPO_VENDITA_CONGIUNTA                             AS FL_TIPO_VENDITA_CONGIUNTA,
    r.CD_PRODOTTO                                           AS CD_PRODOTTO,
    r.TP_PRODOTTO                                           AS TP_PRODOTTO,
    r.TP_DESTINAZIONE_FINANZIAMENTO                         AS TP_DESTINAZIONE_FINANZIAMENTO,
    TRY_TO_DATE(r.DT_GIA_CORRENTISTA_RAW)                   AS DT_GIA_CORRENTISTA,
    r.CD_CANALE                                             AS CD_CANALE,
    r.FL_CANALE_WEB                                         AS FL_CANALE_WEB,
    TRY_TO_DATE(r.DT_CARICAMENTO_RAW)                       AS DT_CARICAMENTO,
    r.CD_AREA                                               AS CD_AREA,
    r.CD_DISTRETTO                                          AS CD_DISTRETTO,
    r.CD_FILIALE                                            AS CD_FILIALE,
    r.DS_RETE_VENDITA                                       AS DS_RETE_VENDITA,
    r.DS_MACROAREA_RETE_VENDITA                             AS DS_MACROAREA_RETE_VENDITA,
    r.TP_STATO_RETE_VENDITA                                 AS TP_STATO_RETE_VENDITA,
    r.CD_ATTRIBUTO_RETE_VENDITA                             AS CD_ATTRIBUTO_RETE_VENDITA,
    r.TP_RETE_VENDITA                                       AS TP_RETE_VENDITA,
    r.CD_AGENTE                                             AS CD_AGENTE,
    r.DS_MACROAREA_AGENTE                                   AS DS_MACROAREA_AGENTE,
    r.TP_STATO_AGENTE                                       AS TP_STATO_AGENTE,
    r.CD_ATTRIBUTO_AGENTE                                   AS CD_ATTRIBUTO_AGENTE,
    r.TP_AGENTE                                             AS TP_AGENTE,
    r.CD_SUBAGENTE                                          AS CD_SUBAGENTE,
    r.DS_MACROAREA_SUBAGENTE                                AS DS_MACROAREA_SUBAGENTE,
    r.TP_STATO_SUBAGENTE                                    AS TP_STATO_SUBAGENTE,
    r.CD_ATTRIBUTO_SUBAGENTE                                AS CD_ATTRIBUTO_SUBAGENTE,
    r.TP_SUBAGENTE                                          AS TP_SUBAGENTE,
    r.CD_CONVENZIONATO                                      AS CD_CONVENZIONATO,
    r.DS_MACROAREA_CONVENZIONATO                            AS DS_MACROAREA_CONVENZIONATO,
    r.TP_STATO_CONVENZIONATO                                AS TP_STATO_CONVENZIONATO,
    r.CD_ATTRIBUTO_CONVENZIONATO                            AS CD_ATTRIBUTO_CONVENZIONATO,
    r.TP_CONVENZIONATO                                      AS TP_CONVENZIONATO,
    NULL                                                    AS CD_PUNTO_VENDITA,              -- WARN: tag assente nello xsd
    NULL                                                    AS DS_MACROAREA_PUNTO_VENDITA,    -- WARN: tag assente nello xsd
    NULL                                                    AS TP_STATO_PUNTO_VENDITA,        -- WARN: tag assente nello xsd
    NULL                                                    AS CD_ATTRIBUTO_PUNTO_VENDITA,    -- WARN: tag assente nello xsd
    NULL                                                    AS TP_PUNTO_VENDITA,              -- WARN: tag assente nello xsd
    r.CD_VENDITORE                                          AS CD_VENDITORE,
    r.DS_MACROAREA_VENDITORE                                AS DS_MACROAREA_VENDITORE,
    r.CD_STATO_VENDITORE                                    AS CD_STATO_VENDITORE,
    r.CD_ATTRIBUTO_VENDITORE                                AS CD_ATTRIBUTO_VENDITORE,
    r.TP_VENDITORE                                          AS TP_VENDITORE,
    r.CD_INTERMEDIARIO                                      AS CD_INTERMEDIARIO,
    r.TP_INTERMEDIARIO                                      AS TP_INTERMEDIARIO,
    r.CD_STATO_INTERMEDIARIO                                AS CD_STATO_INTERMEDIARIO,
    r.CD_ATTRIBUTO_INTERMEDIARIO                            AS CD_ATTRIBUTO_INTERMEDIARIO,
    r.DS_TIPOLOGIA_INTERMEDIARIO                            AS DS_TIPOLOGIA_INTERMEDIARIO,
    a.NM_LAST_EURISC_INC_CLI_CBSCORE                        AS NM_LAST_EURISC_INC_CLI_CBSCORE,
    a.FL_LAST_EURISC_INC_CLI_NOHIT                          AS FL_LAST_EURISC_INC_CLI_NOHIT,
    TRY_TO_DATE(a.DT_LAST_EURISC_INC_CLI_DATA_CARICAMENTO_RAW)   AS DT_LAST_EURISC_INC_CLI_DATA_CARICAMENTO,
    TRY_TO_DATE(a.DT_LAST_EURISC_INC_CLI_DATA_ELABORAZIONE_RAW)  AS DT_LAST_EURISC_INC_CLI_DATA_ELABORAZIONE,
    a.CD_LAST_EURISC_INC_CLI_CODICE_PRATICA                 AS CD_LAST_EURISC_INC_CLI_CODICE_PRATICA,
    a.CD_LAST_EURISC_INC_CLI_PROCEDURA                      AS CD_LAST_EURISC_INC_CLI_PROCEDURA,
    TRY_CAST(a.CD_ANAGRAFICA_RAW AS NUMBER(16,0))           AS CD_ANAGRAFICA,
    a.FL_DIPENDENTE                                         AS FL_DIPENDENTE,
    a.CD_FORMA_GIURIDICA                                    AS CD_FORMA_GIURIDICA,
    TRY_TO_DATE(a.DT_NASCITA_RAW)                           AS DT_NASCITA,
    a.DT_INIZIO_OCCUPAZIONE                                 AS DT_INIZIO_OCCUPAZIONE,
    a.NM_DURATA_CONTRATTO_LAVORO                            AS NM_DURATA_CONTRATTO_LAVORO,
    TRY_CAST(a.CD_PARTITA_IVA_RAW AS NUMBER(16,0))          AS CD_PARTITA_IVA,
    a.TP_CLIENTE                                            AS TP_CLIENTE,
    a.CD_STATO_CIVILE                                       AS CD_STATO_CIVILE,
    a.CD_OCCUPAZIONE                                        AS CD_OCCUPAZIONE,
    a.CD_TIPO_CONTRATTO_LAVORO                              AS CD_TIPO_CONTRATTO_LAVORO,
    a.CD_TIPO_ATTIVITA                                      AS CD_TIPO_ATTIVITA,
    a.CD_TIPO_ABITAZIONE                                    AS CD_TIPO_ABITAZIONE,
    a.CD_CTCPOS_STATO                                       AS CD_CTCPOS_STATO,
    a.FL_CTCPOS_HIT_NOHIT                                   AS FL_CTCPOS_HIT_NOHIT,
    a.DT_CTCPOS_SCORE_COMPLETO_DT                           AS DT_CTCPOS_SCORE_COMPLETO_DT,
    a.CD_CTCPOS_SCORE_COMPLETO_FASCIA                       AS CD_CTCPOS_SCORE_COMPLETO_FASCIA,
    a.NM_CTCPOS_SCORE_COMPLETO                              AS NM_CTCPOS_SCORE_COMPLETO,
    a.DT_CTCPOS_SCORE_COMPORTAMENTALE_DT                    AS DT_CTCPOS_SCORE_COMPORTAMENTALE_DT,
    a.CD_CTCPOS_SCORE_COMPORTAMENTALE_FASCIA               AS CD_CTCPOS_SCORE_COMPORTAMENTALE_FASCIA,
    a.NM_CTCPOS_SCORE_COMPORTAMENTALE                       AS NM_CTCPOS_SCORE_COMPORTAMENTALE,
    a.DT_CTCPOS_SCORE_SOCIODEMO_DT                          AS DT_CTCPOS_SCORE_SOCIODEMO_DT,
    a.CD_CTCPOS_SCORE_SOCIODEMO_FASCIA                      AS CD_CTCPOS_SCORE_SOCIODEMO_FASCIA,
    a.NM_CTCPOS_SCORE_SOCIODEMO                             AS NM_CTCPOS_SCORE_SOCIODEMO,
    a.CD_CTCPOS_SCORE_SEGMENTO                              AS CD_CTCPOS_SCORE_SEGMENTO
FROM req_raw r
LEFT JOIN app_raw a
    ON r.CD_INQUIRYCODE = a.CD_INQUIRYCODE