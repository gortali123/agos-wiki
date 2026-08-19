-- INCASSI_BOLLETTINI | Storicizzazione S4 (insert_overwrite) | SA: PAGAMENTI E CONTABILITA
-- Multiprocedura: P1 (BACCPDET, cluster A1 -> FL_DELETED) UNION ALL P2 (CRCCPDET)
-- WARN: la procedura P3 e' presente nel data model ma priva di qualsiasi mappatura (nessuna TAB/COL/RT): non generata.
-- WARN: il cluster di CRCCPDET (P2) non e' documentato nel catalogo (unica sorgente censita: BACCPDET:A1);
--       il filtro FL_DELETED non e' stato applicato al ramo P2.

-- ============================ P1: BACCPDET ============================
SELECT
    det.BOLD_CIRCUITO AS CD_CIRCUITO,
    det.BOLD_NUM_CCP AS CD_CCP,
    det.BOLD_CENTRO AS CD_CUAS,
    {{ ole_to_date('det.BOLD_DATA_ALLIBRAMENTO') }} AS DT_ALLIBRAMENTO,
    det.BOLD_TIPO_RECORD AS TP_RECORD,
    det.BOLD_PROGRESSIVO AS PR_BOLLETTINO,
    CASE WHEN det.BOLD_ESATTO = 'S' THEN 'E' -- Esatto (Premarcato)
         WHEN det.BOLD_ESATTO = 'N' THEN 'B' -- Errato (In bianco)
         ELSE ' ' END AS TP_BOLLETTINO,
    det.BOLD_CODICE_BP AS CD_BOLLETTINO,
    det.BOLD_PROVENIENZA AS TP_PROCEDURA,
    det.BOLD_PRATICA_EFF AS CD_PRATICA,
    det.BOLD_OPERATORE_ALLIN AS CD_UTENZA_ALLIN,
    det.BOLD_RATA AS NM_RATA,
    det.BOLD_CONTO_POSTALE AS CD_CONTO_CORRENTE,
    det.BOLD_PROGR_SEL AS CD_PROGR_SELEZIONE,
    {{ custom_to_date('det.BOLD_DATA_REGISTRAZ') }} AS DT_REGISTRAZIONE,
    {{ ole_to_date('det.BOLD_DATA_ACCETTAZIONE') }} AS DT_OPERAZIONE_BOLLETTINO,
    {{ custom_to_date('tes.BOLT_DATA_ACQUISIZ') }} AS DT_ELABORAZ_NASTRO,
    {{ custom_to_decimal('det.BOLD_IMPORTO', 11, 2) }} AS EU_IMPORTO
FROM {{ ref('baccpdet') }} det
LEFT JOIN {{ ref('baccptes') }} tes
    ON det.BOLD_CIRCUITO = tes.BOLT_CIRCUITO
    AND det.BOLD_NUM_CCP = tes.BOLT_NUM_CCP
    AND det.BOLD_CENTRO = tes.BOLT_CENTRO
    AND det.BOLD_DATA_ALLIBRAMENTO = tes.BOLT_DATA_ALLIBRAMENTO
WHERE det.FL_DELETED = 'N'

UNION ALL

-- ============================ P2: CRCCPDET ============================
SELECT
    cp.CRBOLD_CIRCUITO AS CD_CIRCUITO,
    cp.CRBOLD_NUM_CCP AS CD_CCP,
    cp.CRBOLD_CENTRO AS CD_CUAS,
    {{ ole_to_date('cp.CRBOLD_DATA_ALLIBRAMENTO') }} AS DT_ALLIBRAMENTO,
    cp.CRBOLD_TIPO_RECORD AS TP_RECORD,
    cp.CRBOLD_PROGRESSIVO AS PR_BOLLETTINO,
    cp.CRBOLD_ESATTO AS TP_BOLLETTINO,
    NULL AS CD_BOLLETTINO,
    cp.CRBOLD_PROVENIENZA AS TP_PROCEDURA,
    bp.CAINBPDT_CONTRATTO AS CD_PRATICA,
    cp.CRBOLD_OPERATORE_ALLIN AS CD_UTENZA_ALLIN,
    NULL AS NM_RATA,
    crtes.CRBOLT_CONTO AS CD_CONTO_CORRENTE,
    cp.CRBOLD_PROGR_SEL AS CD_PROGR_SELEZIONE,
    {{ ole_to_date('COALESCE(mov1.CRMOC_DATA_REGISTRAZIONE, mov2.CRMOC_DATA_REGISTRAZIONE)') }} AS DT_REGISTRAZIONE,
    {{ ole_to_date('cp.CRBOLD_DATA_ACCETTAZIONE') }} AS DT_OPERAZIONE_BOLLETTINO,
    {{ custom_to_date('cp.CRBOLD_DATA_ACQUISIZ') }} AS DT_ELABORAZ_NASTRO,
    {{ custom_to_decimal('cp.CRBOLD_IMPORTO', 11, 2) }} AS EU_IMPORTO
FROM {{ ref('crccpdet') }} cp
LEFT JOIN {{ ref('crccptes') }} crtes
    ON cp.CRBOLD_CIRCUITO = crtes.CRBOLT_CIRCUITO
    AND cp.CRBOLD_NUM_CCP = crtes.CRBOLT_NUM_CCP
    AND cp.CRBOLD_CENTRO = crtes.CRBOLT_CENTRO
    AND cp.CRBOLD_DATA_ALLIBRAMENTO = crtes.CRBOLT_DATA_ALLIBRAMENTO
    AND cp.CRBOLD_TIPO_RECORD = crtes.CRBOLT_TIPO_RECORD
    AND cp.CRBOLD_PROGRESSIVO = crtes.CRBOLT_PROGRESSIVO
LEFT JOIN {{ ref('cainfbpdt') }} bp
    ON CAST(cp.CRBOLD_DATI_UTENTE AS CHAR(15)) = bp.CAINBPDT_QUINTO_CAMPO
LEFT JOIN {{ ref('crmov') }} mov1
    ON mov1.CRMOC_EVENTO = cp.CRBOLD_EVENTO
LEFT JOIN {{ ref('oxinfbpnd') }} bpnd
    ON bpnd.OXINBPND_PROG_BP = cp.CRBOLD_PROG_BP
LEFT JOIN {{ ref('crmov') }} mov2
    ON mov2.CRMOC_EVENTO = bpnd.OXINBPND_EVENTO
