/* =========================================================
   ANAGRAFICA GERARCHIA TERRITORIALE - VERSIONE MENSILE (S3)
   Grana: una riga per NODO FOGLIA (livello 5) per DT_OSSERVAZIONE
   Struttura: 4 livelli territoriali + nodo foglia
   Reti e mappatura livelli: config-driven via CFG_RETE_LIVELLI
   Main: CCANATFI_M (versione mensile di CCANATFI) - DT_OSSERVAZIONE
   presa direttamente dalla sorgente.
   ========================================================= */
WITH
/* ---------------------------------------------------------
   0) CCANATFI_M_1: snapshot mensile main, filtrato al mese
      corrente sui run incrementali (append). Sul full-refresh
      (is_incremental() falso) passano tutti gli storici presenti
      in CCANATFI_M, per permettere il backfill di tutte le
      DT_OSSERVAZIONE disponibili.
   --------------------------------------------------------- */
CCANATFI_M_1 AS (
    SELECT
        ANATFI_FILIALE,
        ANATFI_AREA,
        ANATFI_DISTRETTO,
        ANATFI_DESCRIZIONE,
        ANATFI_AGENTE,
        DT_OSSERVAZIONE,
        LASTMODIFIEDDATA
    FROM {{ ref('ccanatfi_m') }}
    {% if is_incremental() %}
    WHERE DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
),
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
    FROM {{ ref('ccanainin') }} i
    INNER JOIN {{ ref('ccanaisa') }} sa
        ON sa.ISA_CODICE = i.INT_CODICE
    LEFT JOIN {{ ref('ccanagr') }} gr
        ON sa.ISA_CODICE = gr.AC_CODICE
        --ON TRY_TO_NUMBER(sa.ISA_CODICE) = gr.AC_CODICE
    LEFT JOIN CCANATFI_M_1 fi
        ON fi.ANATFI_FILIALE = i.INT_FILIALE
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
    FROM CCANATFI_M_1 t
    JOIN {{ ref('cctabare') }} ar
        ON ar.TABARE_AREA = t.ANATFI_AREA
       AND ar.FL_DELETED  = 'N'
       AND t.DT_OSSERVAZIONE >= LAST_DAY(DATEADD(MONTH, -1, ar.TS_INIZIO_VALIDITA))
       --AND t.DT_OSSERVAZIONE >= ar.TS_INIZIO_VALIDITA
        AND t.DT_OSSERVAZIONE <  ar.TS_FINE_VALIDITA
    UNION ALL
    /* Distretto -> 300 */
    SELECT t.ANATFI_FILIALE,
           '300',
           t.ANATFI_DISTRETTO,
           di.ANATDI_DESCRIZIONE
    FROM CCANATFI_M_1 t
    JOIN {{ ref('ccanatdi') }} di
        ON di.ANATDI_DISTRETTO = t.ANATFI_DISTRETTO
       AND di.FL_DELETED       = 'N'
       AND t.DT_OSSERVAZIONE >= LAST_DAY(DATEADD(MONTH, -1, di.TS_INIZIO_VALIDITA))
       --AND t.DT_OSSERVAZIONE >= di.TS_INIZIO_VALIDITA
        AND t.DT_OSSERVAZIONE <  di.TS_FINE_VALIDITA
    UNION ALL
    /* Filiale -> 400 */
    SELECT t.ANATFI_FILIALE,
           '400',
           t.ANATFI_FILIALE,
           t.ANATFI_DESCRIZIONE
    FROM CCANATFI_M_1 t
    UNION ALL
    /* Agente -> 500 */
    SELECT t.ANATFI_FILIALE,
           '500',
           --t.ANATFI_AGENTE,
           CAST(t.ANATFI_AGENTE AS VARCHAR(10)) AS CD_ATTR,  --DEVE ESSERE ALMENO VARCHAR(9)
           TRIM(gr.AC_COGNOME)||' '||TRIM(gr.AC_NOME)
    FROM CCANATFI_M_1 t
    LEFT JOIN {{ ref('ccanagr') }}  gr
        ON gr.AC_CODICE = t.ANATFI_AGENTE
    UNION ALL
    /* Subagente -> 600: nodo foglia per Agenti e CQS */
    SELECT t.ANATFI_FILIALE,
           '600',
           CAST(i.INT_CODICE AS VARCHAR(10)) AS CD_ATTR,
           i.DS_SUBAGENTE
    FROM CCANATFI_M_1 t
    LEFT JOIN CCANAININ_1 i
        ON i.INT_FILIALE = t.ANATFI_FILIALE
),
/* ---------------------------------------------------------
   2) BASE: una riga per nodo foglia con la rete associata.
      La rete arriva da CCANAININ.INT_RETE quando esiste
      (reti con subagente/split), altrimenti dall'area.
      → split MAIF/BANCHE/CQS risolto dal dato, non castato
      DT_OSSERVAZIONE portata dalla main CCANATFI_M.
   --------------------------------------------------------- */
BASE AS (
    SELECT
        t.ANATFI_FILIALE     AS CODICE_FILIALE,
        --COALESCE(t.ANATFI_AREA, ar.TABARE_AREA) AS CD_RETE,
        COALESCE (CASE WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I01' THEN 'IFQ1'
             WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I10' THEN 'IFQ2'
             WHEN t.ANATFI_AREA='IFQ' AND t.ANATFI_DISTRETTO ='I99' THEN 'IFQ3' 
             ELSE t.ANATFI_AREA
             END,
            CASE WHEN ar.TABARE_AREA='IFQ' THEN 'IFQ1' END) AS CD_RETE, 
        t.DT_OSSERVAZIONE    AS DT_OSSERVAZIONE,
        t.LASTMODIFIEDDATA
    FROM CCANATFI_M_1 t
    JOIN {{ ref('cctabare') }} ar
        ON ar.TABARE_AREA = t.ANATFI_AREA
       AND ar.FL_DELETED  = 'N'
        AND t.DT_OSSERVAZIONE >= LAST_DAY(DATEADD(MONTH, -1, ar.TS_INIZIO_VALIDITA))
        --AND t.DT_OSSERVAZIONE >= ar.TS_INIZIO_VALIDITA
        AND t.DT_OSSERVAZIONE <  ar.TS_FINE_VALIDITA
    LEFT JOIN CCANAININ_1 i ON i.INT_FILIALE = t.ANATFI_FILIALE
)


SELECT DISTINCT
    b.DT_OSSERVAZIONE,
    SUBSTR(a1.CD_ATTR, 1, 3) AS CD_GER_TERRITORIALE_1,
    a1.DS_ATTR AS DS_GER_TERRITORIALE_1,

    a2.CD_ATTR AS CD_GER_TERRITORIALE_2,
    a2.DS_ATTR AS DS_GER_TERRITORIALE_2,

    a3.CD_ATTR AS CD_GER_TERRITORIALE_3,
    a3.DS_ATTR AS DS_GER_TERRITORIALE_3,

    a4.CD_ATTR AS CD_GER_TERRITORIALE_4,
    a4.DS_ATTR AS DS_GER_TERRITORIALE_4,

    a5.CD_ATTR AS CD_NODO_FOGLIA,
    a5.DS_ATTR AS DS_NODO_FOGLIA,
    b.LASTMODIFIEDDATA
FROM BASE b
/* Config struttura livelli per la rete: solo riga vigente */
JOIN {{ ref('cfg_rete_livelli') }} c
        ON c.CD_RETE = b.CD_RETE
        AND b.DT_OSSERVAZIONE >= c.TS_INIZIO_VALIDITA
        AND b.DT_OSSERVAZIONE <  c.TS_FINE_VALIDITA
        --AND CURRENT_TIMESTAMP() >= c.TS_INIZIO_VALIDITA
        --AND CURRENT_TIMESTAMP() <  c.TS_FINE_VALIDITA

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