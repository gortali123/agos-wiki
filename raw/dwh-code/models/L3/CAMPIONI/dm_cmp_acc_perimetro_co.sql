-- =============================================================================
-- MODELLO   : DM_CMP_ACC_PERIMETRO_CO
-- PROCESSO  : Campioni Accettazione | LAYER: L3 - DataMart
-- SCOPO     : Perimetro condiviso per i modelli "consumo" (CO) - analogo a
--             dm_cmp_acc_perimetro_carte per le carte. Versione base, campi da
--             espandere in seguito.
-- PK        : CD_PRATICA
-- =============================================================================
-- ATTENZIONE:
-- 1. Filtro CD_MACRO_PRODOTTO_4 commentato (fedele alla query fornita) - non
--    applicabile a CONSUMO (era specifico per carte revolving REV_B2B/REV_B2C).
-- 2. CD_STATO: la lista ('30','50','51','55','97','96') del DM e' sostituita da
--    TRY_TO_NUMBER(CD_STATO) >= 30 + esclusione CD_ATTRIBUTO in ('RT','RF').
--    Piu' larga della lista: passano anche stati > 55 (es. 60, 80). I modelli
--    figli che filtrano ancora per lista vedono quindi meno righe del perimetro.
-- 3. FL_PREPAGATA rimossa: veniva da CREMEP via CARTA_M nel perimetro carte, ed
--    e' un attributo specifico delle carte revolving. Su CONSUMO il join B e'
--    a CONSUMO_M, non a CARTA_M, quindi l'alias C non esisteva piu'.
-- 4. Join A -> B (CONSUMO_M) su solo CD_PRATICA: rischio noto di
--    moltiplicazione righe, mitigato dal QUALIFY finale su CD_PRATICA.
-- =============================================================================

SELECT
    A.CD_PRATICA,
    A.TP_PROCEDURA,
    A.DT_CARICAMENTO,
    A.CD_CLIENTE,
    A.CD_STATO,
    A.DT_RITIRATA,
    A.DT_PASSAGGIO_PERDITA,
    A.CD_MACRO_PRODOTTO_4,
    A.DT_CHIUSURA_EFFETTIVA,
    A.DT_PRIMA_SCADENZA,
    A.DT_OSSERVAZIONE,
    A.DT_CESSIONE,
    A.DT_STORNATA,
    A.CD_PRODOTTO,
    A.CD_TIPO_PRODOTTO,
    B.CD_DESTINAZIONE_BENE,
    A.CD_CANALE_ACQUISIZIONE,
    A.FL_WEB_CANALE_ACQ,
    B.EU_PREZZO_BENE,
    A.CD_MERCATO_1,
    A.CD_MERCATO_2,
    A.CD_MERCATO_3,
    A.CD_MERCATO_4,
    A.CD_MACRO_PRODOTTO_1,
    A.CD_MACRO_PRODOTTO_2,
    A.CD_MACRO_PRODOTTO_3,
    A.DT_DBT,
    A.DT_ESTINZIONE_ANTICIPATA  --A.DT_ESTINZIONE

FROM {{ ref('pratica_m') }} AS A
LEFT JOIN {{ ref('consumo_m') }} AS B
    ON A.CD_PRATICA = B.CD_PRATICA

WHERE A.TP_PROCEDURA = 'CO'
    --AND A.CD_MACRO_PRODOTTO_4 IN ('REV_B2B', 'REV_B2C')
    AND A.DT_CARICAMENTO >= DATE '2011-01-01'
    AND A.DT_CARICAMENTO < LAST_DAY(DATEADD(MONTH, -1, CURRENT_DATE))
    -- AND A.CD_STATO IN ('30', '50', '51', '55', '97', '96')  -- accettate, respinte, ritirate, rifiutate
    AND TRY_TO_NUMBER(A.CD_STATO) >= 30
    AND (A.CD_ATTRIBUTO IS NULL OR A.CD_ATTRIBUTO NOT IN ('RT', 'RF'))
QUALIFY ROW_NUMBER() OVER (PARTITION BY A.CD_PRATICA ORDER BY 1) = 1