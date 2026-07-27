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
    {{ custom_to_date('det.BOLD_DATA_ALLIBRAMENTO') }} AS DT_ALLIBRAMENTO,
    NULL AS TP_RECORD, -- WARN: TP_RECORD (PK) non ha sorgente in P1/BACCPDET
    det.BOLD_PROGRESSIVO AS PR_BOLLETTINO,
    CASE WHEN det.BOLD_ESATTO = 'S' THEN 'E' -- Esatto (Premarcato)
         WHEN det.BOLD_ESATTO = 'N' THEN 'B' -- Errato (In bianco)
         ELSE NULL END AS TP_BOLLETTINO,
    NULL AS CD_BOLLETTINO, -- WARN: nessuna sorgente nel data model
    det.BOLD_PROVENIENZA AS TP_PROCEDURA,
    det.BOLD_PRATICA_EFF AS CD_PRATICA,
    det.BOLD_OPERATORE_ALLIN AS CD_UTENZA_ALLIN,
    -- WARN: NM_RATA e' mappato due volte in P1 (BOLD_RATA e BOLD_RATA_PAGATA); uso la prima occorrenza (BOLD_RATA)
    det.BOLD_RATA AS NM_RATA,
    det.BOLD_CONTO_POSTALE AS CD_CONTO_CORRENTE,
    det.BOLD_PROGR_SEL AS CD_PROGR_SELEZIONE,
    {{ custom_to_date('det.BOLD_DATA_REGISTRAZ') }} AS DT_REGISTRAZIONE,
    {{ custom_to_date('det.BOLD_DATA_ACCETTAZIONE') }} AS DT_OPERAZIONE_BOLLETTINO,
    -- RT: aggancio a BACCPTES per la data di acquisizione nastro
    {{ custom_to_date('tes.BOLT_DATA_ACQUISIZ') }} AS DT_ELABORAZ_NASTRO,
    {{ custom_to_decimal('det.BOLD_IMPORTO', 11, 2) }} AS EU_IMPORTO,
    det.BOLD_CONTABILIZZATO AS FL_CONTABILIZZATO,
    det.BOLD_TIPO_DOC AS TP_DOCUMENTO,
    det.BOLD_PROVINCIA AS CD_PROVINCIA,
    det.BOLD_UFFICIO AS CD_UFFICIO,
    det.BOLD_SPORTELLO AS CD_SPORTELLO,
    det.BOLD_PROGR_MARC AS CD_PROGR_MARC,
    det.BOLD_TIPO_OPERAZIONE AS TP_OPERAZIONE,
    det.BOLD_MODIFICATO AS FL_MODIFICATO,
    {{ custom_to_date('det.BOLD_DATA_ALLINEAMENTO') }} AS DT_ALLINEAMENTO_SCARTI,
    det.BOLD_PROGRES_ACQUISIZ AS PR_ACQUISIZIONE,
    {{ custom_to_date('det.BOLD_DATA_ACQUISIZ') }} AS DT_ACQUISIZIONE,
    det.BOLD_NUMERATORE AS PR_NUMERAZ_BP,
    det.BOLD_PRIORITA AS CD_PRIORITA_CONTAB,
    det.BOLD_EVENTO AS CD_EVENTO,
    det.BOLD_COD_ERRORE AS CD_ERRORE_SCARTO
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
    {{ custom_to_date('cp.CRBOLD_DATA_ALLIBRAMENTO') }} AS DT_ALLIBRAMENTO,
    cp.CRBOLD_TIPO_RECORD AS TP_RECORD,
    cp.CRBOLD_PROGRESSIVO AS PR_BOLLETTINO,
    cp.CRBOLD_ESATTO AS TP_BOLLETTINO,
    NULL AS CD_BOLLETTINO, -- WARN: nessuna sorgente nel data model
    cp.CRBOLD_PROVENIENZA AS TP_PROCEDURA,
    -- RT: aggancio a CAINFBPDT per recuperare il contratto -- FIX: alias 'cp' normalizzato per CRCCPDET
    bp.CAINBPDT_CONTRATTO AS CD_PRATICA,
    cp.CRBOLD_OPERATORE_ALLIN AS CD_UTENZA_ALLIN,
    NULL AS NM_RATA, -- RT del data model: 'SELECT NULL'
    NULL AS CD_CONTO_CORRENTE, -- WARN: sorgente CRCCPTES.CRBOLT_CONTO senza chiave di aggancio nel data model: join non ricostruibile
    cp.CRBOLD_PROGR_SEL AS CD_PROGR_SELEZIONE,
    -- RT: COALESCE su CRMOV (percorso diretto via EVENTO, fallback via OXINFBPND) -- FIX: alias 'det' del data model normalizzato in 'cp'
    {{ custom_to_date('COALESCE(mov1.CRMOC_DATA_REGISTRAZIONE, mov2.CRMOC_DATA_REGISTRAZIONE)') }} AS DT_REGISTRAZIONE,
    {{ custom_to_date('cp.CRBOLD_DATA_ACCETTAZIONE') }} AS DT_OPERAZIONE_BOLLETTINO,
    {{ custom_to_date('cp.CRBOLD_DATA_ACQUISIZ') }} AS DT_ELABORAZ_NASTRO,
    {{ custom_to_decimal('cp.CRBOLD_IMPORTO', 11, 2) }} AS EU_IMPORTO,
    NULL AS FL_CONTABILIZZATO,
    NULL AS TP_DOCUMENTO,
    NULL AS CD_PROVINCIA,
    NULL AS CD_UFFICIO,
    NULL AS CD_SPORTELLO,
    NULL AS CD_PROGR_MARC,
    NULL AS TP_OPERAZIONE,
    NULL AS FL_MODIFICATO,
    NULL AS DT_ALLINEAMENTO_SCARTI,
    NULL AS PR_ACQUISIZIONE,
    NULL AS DT_ACQUISIZIONE,
    NULL AS PR_NUMERAZ_BP,
    NULL AS CD_PRIORITA_CONTAB,
    NULL AS CD_EVENTO,
    NULL AS CD_ERRORE_SCARTO
FROM {{ ref('crccpdet') }} cp
LEFT JOIN {{ ref('cainfbpdt') }} bp
    ON CAST(cp.CRBOLD_DATI_UTENTE AS CHAR(15)) = bp.CAINBPDT_QUINTO_CAMPO
LEFT JOIN {{ ref('crmov') }} mov1
    ON mov1.CRMOC_EVENTO = cp.CRBOLD_EVENTO
LEFT JOIN {{ ref('oxinfbpnd') }} bpnd
    ON bpnd.OXINBPND_PROG_BP = cp.CRBOLD_PROG_BP
LEFT JOIN {{ ref('crmov') }} mov2
    ON mov2.CRMOC_EVENTO = bpnd.OXINBPND_EVENTO
