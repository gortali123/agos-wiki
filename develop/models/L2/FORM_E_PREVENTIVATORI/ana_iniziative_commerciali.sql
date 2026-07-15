SELECT
    T.TABICO_INIZIATIVA_COMM AS CD_INIZIATIVA,
    T.TABICO_DESCRIZIONE AS DS_INIZIATIVA,
    {{ custom_to_date('T.TABICO_DATA_INIZIO') }} AS DT_INIZIO_VALIDITA,
    {{ custom_to_date('T.TABICO_DATA_FINE') }} AS DT_FINE_VALIDITA,
    T.TABICO_SIGLA_SOCIETA AS SIGLA_SOCIETA,
    T.TABICO_COD_FILIALE_DEFAULT AS CD_FILIALE_DEFAULT,
    T.TABICO_CAMPAGNA_INDIVIDUALE AS CD_CAMPAGNA_INDIVIDUALE,
    T.TABICO_FLAG_ABIL_CARTE AS FL_ABIL_CARTE,
    T.TABICO_FLAG_ABIL_CONSUMO AS FL_ABIL_CONSUMO,
    T.TABICO_FLAG_NASCOSTO AS FL_NASCOSTO,
    T.TABICO_SOGGETTO_TERZO AS CD_SOGGETTO_TERZO,
    T.TABICO_RIUTILIZZO_SU_CLI AS FL_RIUTILIZZO_SU_CLI,
    T.TABICO_LETTERA_DBT_CL AS FL_LETTERA_DBT_CL,
    T.TABICO_LETTERA_DBT_CO AS FL_LETTERA_DBT_CO,
    T.TABICO_LETTERA_DBT_GA AS FL_LETTERA_DBT_GA,
    T.TABICO_EMIS_FATT_CONTRIB AS FL_EMIS_FATT_CONTRIB,
    NULL AS FL_INIZIATIVA_ONLINE, -- WARN: data model indica sorgente "TIG + CCTABICO" su CD_INIZIATIVA = TABICO_INIZIATIVA_COMM ma nessuna regola/colonna che determini il flag stesso
    NULL AS TP_CATEGORIA_INZIATIVA, -- WARN: data model indica solo la sorgente "TIG", nessuna colonna ne' RT
    NULL AS TP_MACROCATEGORIA_INIZIATIVA -- WARN: data model indica solo la sorgente "TIG", nessuna colonna ne' RT
FROM {{ ref('cctabico') }} T
-- WARN: nel data model TAB/COL erano shiftate di una colonna (TAB = descrizione 'FMP - Funzionalita multiprocedure', COL = nome tabella 'CCTABICO'); usata REGOLA FUNZIONALE come vero nome colonna sorgente (es. TABICO_INIZIATIVA_COMM), coerente su tutte le righe del foglio
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/TS_INIZIO_VALIDITA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
