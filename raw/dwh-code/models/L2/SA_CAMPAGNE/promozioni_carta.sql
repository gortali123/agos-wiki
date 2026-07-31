-- WARN: STORICIZZAZIONE - il Catalogo Entità riporta "S2 - ... Storicizzazione da confermare"
--       per questa entità, non S4. Generato con S4 come richiesto esplicitamente dall'utente.
-- WARN: TABELLA MAIN - SGMPFTPA è stata identificata come tabella MAIN. SGMPFPRO viene quindi
--       collegata tramite LEFT JOIN, mantenendo tutti i record presenti in SGMPFTPA.
-- WARN: CAMPI DUPLICATI - TP_PROCEDURA e CD_PRATICA sono presenti nel foglio anche come campi
--       NON-PK sorgente SGMPFPRO (SGMPPRO_PROCEDURA, SGMPPRO_PRATICA): stesso nome campo di
--       una PK, non riportabili nel SELECT senza collisione. Non inclusi come colonne separate.
-- WARN: CLUSTER SORGENTI non specificato in Catalogo per SGMPFPRO/SGMPFTPA: filtro FL_DELETED
--       non applicato, pre-hook delete_l2 non generato. Verificare cluster degli archivi L1.

SELECT
    TPA.SGMPFTPA_PRATICA AS CD_PRATICA,
    TPA.SGMPFTPA_PROCEDURA AS TP_PROCEDURA,
    PRO.SGMPPRO_EVENTO AS ID_EVENTO_PROMOZIONE,
    TPA.SGMPTPA_PROMOZIONE AS CD_PROMOZIONE,
    TPA.SGMPTPA_COD_AZIONE AS CD_AZIONE,
    PRO.SGMPPRO_TIPO_AZIONE AS TP_AZIONE,
    PRO.SGMPPRO_STATO_AZIONE AS CD_STATO_AZIONE

--FROM { re('sgmpftpa') }} TPA
LEFT JOIN {{ ref('sgmpfpro') }} PRO
    ON TPA.SGMPTPA_PROCEDURA = PRO.SGMPPRO_PROCEDURA
    AND TPA.SGMPTPA_PROMOZIONE = PRO.SGMPPRO_PROMOZIONE
    AND TPA.SGMPTPA_COD_AZIONE = PRO.SGMPPRO_COD_AZIONE