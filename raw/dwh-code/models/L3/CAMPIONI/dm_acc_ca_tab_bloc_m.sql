-- =============================================================================
-- MODELLO   : DM_CA_TAB_BLOCCHI
-- PROCESSO  : Campioni Accettazione | LAYER: L3 - DataMart
-- PK        : CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE
-- =============================================================================
-- ATTENZIONE - ASSUNZIONI FATTE (nessuna regola tecnica esplicita nel foglio
-- per nessuno di questi campi, solo descrizione + sorgente):
-- 1. CD_CLEINTE: la spec indica sorgente CARTA_M, ma quella tabella non ha
--    CD_CLIENTE (verificato col DDL reale) - uso PRATICA_M.CD_CLIENTE.
-- 2. DT_CHIUSURA_ALTRA_CARTA / DT_PERDITA_ALTRA_CARTA: la descrizione dice
--    "altre carte del cliente in analisi" - self-join su PRATICA_M (stesso
--    CD_CLIENTE, CD_PRATICA diverso da quello corrente). Uso MAX() per
--    prendere la chiusura/perdita piu' recente tra le altre carte - non
--    specificato se debba essere MAX, MIN, o altro criterio.
-- 3. CD_BLOCCO_PRIMARIO: "concatenazione dei blocchi primari nei 12 mesi
--    precedenti al caricamento dello score" - uso LISTAGG su CARTE_BLOCCHI,
--    finestra di 12 mesi rispetto a DT_CARICAMENTO (assunto essere "data di
--    caricamento dello score").
-- 4. TP_BLOCCO: sorgente dichiarata "BLOCCHI_CARTE" (tabella mai vista/
--    verificata) - uso CARTE_BLOCCHI (verificata, ha davvero TP_BLOCCO),
--    sospetto refuso nel foglio, stesso pattern di errori gia' visto altrove.
-- =============================================================================

WITH

-- Perimetro letto direttamente da dm_acc_ca_perim (attiva=40/utilizzata=55) -
-- tutti i campi necessari sono gia' presenti li' (incluso DT_OSSERVAZIONE).
perimetro AS (
    SELECT
        CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE, CD_CLIENTE,
        DT_CHIUSURA_EFFETTIVA, DT_CESSIONE, DT_PASSAGGIO_PERDITA, DT_CARICAMENTO
   FROM {{ ref('dm_cmp_acc_perimetro_ca') }} P
    WHERE
       P.CD_STATO IN ('40', '55')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
),


-- Altre carte dello stesso cliente (self-join, escludendo la pratica corrente)
altre_carte AS (
    SELECT
        P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE,
        MAX(ALTRA.DT_CHIUSURA_EFFETTIVA) AS DT_CHIUSURA_ALTRA_CARTA,
        MAX(ALTRA.DT_PASSAGGIO_PERDITA) AS DT_PERDITA_ALTRA_CARTA
    FROM perimetro P
    LEFT JOIN {{ ref('pratica_m') }} ALTRA
        ON ALTRA.CD_CLIENTE = P.CD_CLIENTE
        AND ALTRA.TP_PROCEDURA = P.TP_PROCEDURA
        AND ALTRA.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
        AND ALTRA.CD_PRATICA <> P.CD_PRATICA
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
),

-- Blocchi primari concatenati negli ultimi 12 mesi rispetto a DT_CARICAMENTO
blocchi_12m AS (
    SELECT
        P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE,
        LISTAGG(DISTINCT CB.CD_BLOCCO_OCS, ',') AS CD_BLOCCO_PRIMARIO
    FROM perimetro P
    LEFT JOIN AGOS_DEV_16000.L2_PRODOTTO.CARTE_BLOCCHI CB
        ON CB.CD_PRATICA = P.CD_PRATICA
        AND CB.TP_PROCEDURA = P.TP_PROCEDURA
        AND CB.TS_INSERIMENTO >= ADD_MONTHS(P.DT_CARICAMENTO, -12)
        AND CB.TS_INSERIMENTO <= P.DT_CARICAMENTO
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
),

-- TP_BLOCCO: riga piu' recente da CARTE_BLOCCHI (vedi nota in testa sul
-- probabile refuso "BLOCCHI_CARTE" nella spec)
blocco_tipo AS (
    SELECT CD_PRATICA, TP_PROCEDURA, TP_BLOCCO
    FROM AGOS_DEV_16000.L2_PRODOTTO.CARTE_BLOCCHI
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, TP_PROCEDURA ORDER BY TS_INSERIMENTO DESC) = 1
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.DT_OSSERVAZIONE,
    P.CD_CLIENTE AS CD_CLEINTE,
    AC.DT_CHIUSURA_ALTRA_CARTA,
    AC.DT_PERDITA_ALTRA_CARTA,
    B12.CD_BLOCCO_PRIMARIO,
    P.DT_CHIUSURA_EFFETTIVA AS DT_CHIUSURA,
    P.DT_CESSIONE,
    BT.TP_BLOCCO

FROM perimetro P
LEFT JOIN altre_carte AC
    ON AC.CD_PRATICA = P.CD_PRATICA
    AND AC.TP_PROCEDURA = P.TP_PROCEDURA
    AND AC.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
LEFT JOIN blocchi_12m B12
    ON B12.CD_PRATICA = P.CD_PRATICA
    AND B12.TP_PROCEDURA = P.TP_PROCEDURA
    AND B12.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
LEFT JOIN blocco_tipo BT
    ON BT.CD_PRATICA = P.CD_PRATICA
    AND BT.TP_PROCEDURA = P.TP_PROCEDURA