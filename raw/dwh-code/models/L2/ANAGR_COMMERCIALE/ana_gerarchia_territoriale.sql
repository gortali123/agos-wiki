/* =========================================================
   ANAGRAFICA GERARCHIA TERRITORIALE
   Grana: una riga per NODO FOGLIA (livello 5)
   Struttura: 4 livelli territoriali + nodo foglia
   Reti e mappatura livelli: config-driven via CFG_RETE_LIVELLI
   ========================================================= */
WITH
/* ---------------------------------------------------------
   Subagenti attivi: da CCANAININ filtrando tipo ISA,
   agganciati ai subagenti veri di CCANAISA.
   INT_RETE porta la rete risolta (MAIF/BANCHE/CQS/...)
   --------------------------------------------------------- */
CCANAININ_1 AS (
    SELECT
        i.INT_CODICE,
        --sa.ISA_TIPO_ANA,
        --COALESCE(i.INT_TIPOLOGIA, sa.ISA_TIPO_ANA),
        i.INT_TIPOLOGIA,
        i.INT_FILIALE,
        fi.ANATFI_DISTRETTO,
        fi.ANATFI_AREA,
        TRIM(gr.AC_COGNOME)||' '||TRIM(gr.AC_NOME) AS DS_SUBAGENTE
        --gr.AC_NOME AS DS_SUBAGENTE
    FROM {{ ref('ccanainin') }} i
    INNER JOIN {{ ref('ccanaisa') }} sa
    --INNER JOIN AGOS_DEV_16000.L0.CCANAISA sa
        ON sa.ISA_CODICE = i.INT_CODICE
        --ON TRY_TO_NUMBER(sa.ISA_CODICE) = i.INT_CODICE -- ISA_CODICE è VARCHAR IN L0 maDIVENTERà NUMERICO IN l1
    LEFT JOIN {{ ref('ccanagr') }} gr
        ON sa.ISA_CODICE = gr.AC_CODICE
        --ON TRY_TO_NUMBER(sa.ISA_CODICE) = gr.AC_CODICE
    LEFT JOIN {{ ref('ccanatfi') }} fi
        ON fi.ANATFI_FILIALE = i.INT_FILIALE
    --WHERE i.INT_TIPOLOGIA = 'ISA'
),
--Sono tutte actual
/* ---------------------------------------------------------
   1) ATTR_FILIALE: verticalizzo gli attributi in key-value.
      ATTR_CODE = codice numerico di livello (100/300/400/500/600).
      Permette di scegliere dinamicamente quale attributo
      mappare su ogni livello tramite la config.
   --------------------------------------------------------- */
ATTR_FILIALE AS (
    /* Area -> 100 */
    SELECT t.ANATFI_FILIALE AS CODICE_FILIALE,
           '100'               AS ATTR_CODE,
           CASE WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I01' THEN 'IFQ1'
             WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I10' THEN 'IFQ2'
             WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I99' THEN 'IFQ3' 
             ELSE t.ANATFI_AREA
             END AS CD_ATTR,
           --t.ANATFI_AREA     AS CD_ATTR,
           ar.TABARE_DESCRIZIONE AS DS_ATTR
    FROM {{ ref('ccanatfi') }} t
    JOIN {{ ref('cctabare') }} ar
        ON ar.TABARE_AREA = t.ANATFI_AREA
       AND ar.FL_DELETED  = 'N'
       AND CURRENT_TIMESTAMP() >= ar.TS_INIZIO_VALIDITA
        AND CURRENT_TIMESTAMP() <  ar.TS_FINE_VALIDITA
    UNION ALL
    /* Distretto -> 300 */
    SELECT t.ANATFI_FILIALE,
           '300',
           t.ANATFI_DISTRETTO,
           di.ANATDI_DESCRIZIONE
    FROM {{ ref('ccanatfi') }} t
    JOIN {{ ref('ccanatdi') }} di
        ON di.ANATDI_DISTRETTO = t.ANATFI_DISTRETTO
       AND di.FL_DELETED       = 'N'
       AND CURRENT_TIMESTAMP() >= di.TS_INIZIO_VALIDITA
        AND CURRENT_TIMESTAMP() <  di.TS_FINE_VALIDITA
    UNION ALL
    /* Filiale -> 400 */
    SELECT t.ANATFI_FILIALE,
           '400',
           t.ANATFI_FILIALE,
           t.ANATFI_DESCRIZIONE
    FROM {{ ref('ccanatfi') }} t
    UNION ALL
    /* Agente -> 500 */
    SELECT t.ANATFI_FILIALE,
           '500',
           --t.ANATFI_AGENTE,
           CAST(t.ANATFI_AGENTE AS VARCHAR(10)) AS CD_ATTR,  --DEVE ESSERE ALMENO VARCHAR(9)
           TRIM(gr.AC_COGNOME)||' '||TRIM(gr.AC_NOME) 
    FROM {{ ref('ccanatfi') }} t
    LEFT JOIN {{ ref('ccanagr') }}  gr
        ON gr.AC_CODICE = t.ANATFI_AGENTE 
    UNION ALL
    /* Subagente -> 600: nodo foglia per Agenti e CQS */
    SELECT t.ANATFI_FILIALE,
           '600',
           CAST(i.INT_CODICE AS VARCHAR(10)) AS CD_ATTR,
           i.DS_SUBAGENTE
    FROM {{ ref('ccanatfi') }} t
    LEFT JOIN CCANAININ_1 i
        ON i.INT_FILIALE = t.ANATFI_FILIALE
),
/* ---------------------------------------------------------
   2) BASE: una riga per nodo foglia con la rete associata.
      La rete arriva da CCANAININ.INT_RETE quando esiste
      (reti con subagente/split), altrimenti dall'area.
      → split MAIF/BANCHE/CQS risolto dal dato, non castato
   --------------------------------------------------------- */
BASE AS (
    SELECT
        t.ANATFI_FILIALE     AS CODICE_FILIALE,
        COALESCE (CASE WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I01' THEN 'IFQ1'
             WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I10' THEN 'IFQ2'
             WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I99' THEN 'IFQ3' 
             ELSE t.ANATFI_AREA
             END,

        CASE WHEN ar.TABARE_AREA='IFQ' THEN 'IFQ1' END) AS CD_RETE
        --COALESCE(t.ANATFI_AREA, ar.TABARE_AREA) AS CD_RETE 
    FROM {{ ref('ccanatfi') }} t
    JOIN {{ ref('cctabare') }} ar --è QUELLO CHE HA SED IN TABARE_AREA
        ON ar.TABARE_AREA = t.ANATFI_AREA 
       AND ar.FL_DELETED  = 'N'
       AND CURRENT_TIMESTAMP() >= ar.TS_INIZIO_VALIDITA
        AND CURRENT_TIMESTAMP() <  ar.TS_FINE_VALIDITA

    LEFT JOIN CCANAININ_1 i ON i.INT_FILIALE = t.ANATFI_FILIALE
)


SELECT DISTINCT
    SUBSTR(a1.CD_ATTR, 1, 3) AS CD_GER_TERRITORIALE_1,
    a1.DS_ATTR AS DS_GER_TERRITORIALE_1,

    a2.CD_ATTR AS CD_GER_TERRITORIALE_2,
    a2.DS_ATTR AS DS_GER_TERRITORIALE_2,

    a3.CD_ATTR AS CD_GER_TERRITORIALE_3,
    a3.DS_ATTR AS DS_GER_TERRITORIALE_3,

    a4.CD_ATTR AS CD_GER_TERRITORIALE_4,
    a4.DS_ATTR AS DS_GER_TERRITORIALE_4,

    a5.CD_ATTR AS CD_NODO_FOGLIA,
    a5.DS_ATTR AS DS_NODO_FOGLIA
FROM BASE b
/* Config struttura livelli per la rete: solo riga vigente */
JOIN {{ ref('cfg_rete_livelli') }} c 
    ON c.CD_RETE = b.CD_RETE
        AND CURRENT_TIMESTAMP() >= c.TS_INIZIO_VALIDITA
        AND CURRENT_TIMESTAMP() <  c.TS_FINE_VALIDITA

/* Livelli 1...4 territoriali */
LEFT JOIN ATTR_FILIALE a1
    ON a1.CODICE_FILIALE = b.CODICE_FILIALE AND a1.ATTR_CODE = c.CD_GER_TERRITORIALE_1
LEFT JOIN ATTR_FILIALE a2
    ON a2.CODICE_FILIALE = b.CODICE_FILIALE AND a2.ATTR_CODE = c.CD_GER_TERRITORIALE_2
LEFT JOIN ATTR_FILIALE a3
    ON a3.CODICE_FILIALE = b.CODICE_FILIALE AND a3.ATTR_CODE = c.CD_GER_TERRITORIALE_3
LEFT JOIN ATTR_FILIALE a4
    ON a4.CODICE_FILIALE = b.CODICE_FILIALE AND a4.ATTR_CODE = c.CD_GER_TERRITORIALE_4

/* Nodo foglia: sempre il default configurato per la rete */
LEFT JOIN ATTR_FILIALE a5
    ON a5.CODICE_FILIALE = b.CODICE_FILIALE
    AND a5.ATTR_CODE      = c.CD_NODO_FOGLIA

