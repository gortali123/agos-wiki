SELECT
    A.numero_polizza AS CD_POLIZZA_ASSIC,
    A.idPreventivo AS CD_PREVENTIVO,
    A.idProdotto AS CD_PRODOTTO_VERSIONE,
    PV.codiceVersione AS CD_VERSIONE,
    PV.dsVersione AS DS_PRODOTTO_VERSIONE,
    PV.idClasse AS CD_CLASSE_POLIZZA,
    PR.idCompagnia AS CD_COMPAGNIA,
    PR.dsProdotto AS DS_COMPAGNIA,
    A.STATO_POL AS CD_STATO_POLIZZA,
    PS.dsStatoPol AS DS_STATO_POLIZZA,
    AN.AC_CODICE AS CD_CLIENTE,
    A.IDCAMPAGNA AS CD_CAMPAGNA,
    C.dsBreve AS DS_CAMPAGNA,
    {{ custom_to_date('A.dataEmissionePolizza') }} AS DT_ADESIONE,
    {{ custom_to_date('A.Data_cancellazione') }} AS DT_CHIUSURA,
    {{ custom_to_date('A.data_effetto') }} AS DT_EFFETTO,
    {{ custom_to_date('A.data_scadenza') }} AS DT_FINE_COPERTURA,
    {{ custom_to_date('A.data_recesso') }} AS DT_RECESSO,
    CAST(A.annuoLordo AS NUMBER(12,2)) AS EU_PREMIO_LORDO,
    CAST(A.annuoNetto AS NUMBER(12,2)) AS EU_PREMIO_NETTO,
    CASE A.frazionamento
        WHEN 0 THEN 'Non selezionato'
        WHEN 1 THEN 'Mensile'
        WHEN 2 THEN 'Bimestrale'
        WHEN 3 THEN 'Trimestrale'
        WHEN 4 THEN 'Quadrimestrale'
        WHEN 5 THEN 'Semestrale'
        WHEN 6 THEN 'Annuale'
        WHEN 7 THEN 'Unico'
        ELSE NULL
    END AS DS_FREQUENZA,
    CASE
        WHEN A.DATA_EFFETTO IS NOT NULL AND A.DATA_CANCELLAZIONE > A.DATA_EFFETTO THEN 'S'
    END AS FL_CONVERTITA,
    --PR_GERARCHIA_TERRITORIALE,
    CAST(A.idNodo AS NUMBER(11)) AS CD_NODO,
    N.dsNodo AS DS_NODO,
    CAST(N.idNodoPadre AS NUMBER(11)) AS CD_NODO_PADRE, 
    N2.dsNodo AS DS_NODO_PADRE,
    CASE WHEN N.idNodoPadre = '73' THEN N.codNodo END AS CD_FILIALE_AGOS
    /*{{ custom_to_date('A.dataCreazione') }} AS DT_INSERIMENTO*/
FROM {{ ref('tblpreventivo') }} A --acedrv_tblpreventivo
LEFT JOIN {{ ref('tblprodottiversioni') }} PV 
    ON PV.idProdottoVersione = A.idProdotto
    AND CURRENT_TIMESTAMP >= PV.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < PV.TS_FINE_VALIDITA
LEFT JOIN {{ ref('tblprodotti') }} PR 
    ON PR.idProdotto = PV.idProdotto
    AND CURRENT_TIMESTAMP >= PR.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < PR.TS_FINE_VALIDITA
LEFT JOIN {{ ref('tblpolstato') }} PS 
    ON PS.idStatoPol = A.Stato_Pol
    AND CURRENT_TIMESTAMP >= PS.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < PS.TS_FINE_VALIDITA
LEFT JOIN {{ ref('ccanagr') }} AN 
ON AN.AC_CODICE = A.ID_CONTRAENTE
LEFT JOIN {{ ref('tblcampagne') }} C 
    ON C.idCampagna = A.IDCAMPAGNA
    AND CURRENT_TIMESTAMP >= C.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < C.TS_FINE_VALIDITA
LEFT JOIN {{ ref('tblnodi') }} N 
    ON N.idNodo = A.idNodo
    AND CURRENT_TIMESTAMP >= N.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < N.TS_FINE_VALIDITA
LEFT JOIN {{ ref('tblnodi') }} N2 
    ON N2.idNodo = N.idNodoPadre
    AND CURRENT_TIMESTAMP >= N2.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < N2.TS_FINE_VALIDITA
WHERE CURRENT_TIMESTAMP >= A.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < A.TS_FINE_VALIDITA