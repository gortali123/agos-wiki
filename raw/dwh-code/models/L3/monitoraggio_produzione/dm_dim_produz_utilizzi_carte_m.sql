-- DataMart L3: DM_DIM_PRODUZ_UTILIZZI_CARTE_M
-- Processo: MONITORAGGIO_PRODUZIONE  |  schema target: L3_MONITORING_PRODUZIONE
--
-- Storicizzazione: "foto mensile SCD2" ancorata al FINE MESE DI RIFERIMENTO (merge).
-- L'intera logica di storicizzazione e' incapsulata nella macro `scd2_foto_mensile`
-- (riusabile come standard per altri DataMart L3 con la stessa storicizzazione):
--   * full-refresh -> ricostruzione storica di TUTTE le finestre passate;
--   * run incrementale -> passo in avanti sul solo mese chiuso piu' recente.
-- Vedi il docstring della macro per i dettagli delle due modalita'.
--
-- NOTA OPERATIVA: per (ri)costruire tutta la storia lanciare una volta
--   `dbt run --full-refresh --select dm_dim_produz_utilizzi_carte_m`.
--   I run successivi (senza flag) appendono solo il mese chiuso piu' recente.
--
-- Qui il modello si occupa SOLO della proiezione L2 -> L3 (src_sql); la macro
-- ricava da sola biz_cols / payload_cols e fa il resto.
--
-- FIX:  L2 non ha EU_FINANZIAMENTO -> mappato da CU.EU_FINANZIATO (verificare se invece EU_EROGATO).
-- TODO: CD_GER_TERRITORIALE_1..4 da ana_gerarchia_territoriale_m (LEFT JOIN su CD_NODO_FOGLIA):
--   join lasciato commentato in src_sql, per ora NULL tipizzati.


{# ---- proiezione L2 -> L3: una riga per VERSIONE sorgente. NON aprire un WITH qui. ---- #}
{%- set src_sql -%}
    SELECT
        CU.TP_PROCEDURA,
        CU.CD_PRATICA,
        CU.CD_PROTOCOLLO,
        CU.CD_RIGA,
        CU.CD_EMETTITORE,
        CU.CD_MACRO_PRODOTTO_1,
        CU.CD_MACRO_PRODOTTO_2,
        CU.CD_MACRO_PRODOTTO_3,
        CU.CD_MACRO_PRODOTTO_4,
        CU.CD_MERCATO_1,
        CU.CD_MERCATO_2,
        CU.CD_MERCATO_3,
        CU.CD_MERCATO_4,
        CAST(NULL AS VARCHAR(10)) AS CD_GER_TERRITORIALE_1,   -- TODO AGT.CD_RETE
        CAST(NULL AS VARCHAR(3))  AS CD_GER_TERRITORIALE_2,   -- TODO AGT.CD_AREA
        CAST(NULL AS VARCHAR(3))  AS CD_GER_TERRITORIALE_3,   -- TODO AGT.CD_DISTRETTO
        CAST(NULL AS VARCHAR(3))  AS CD_GER_TERRITORIALE_4,   -- TODO AGT.CD_FILIALE
        CU.CD_NODO_FOGLIA,
        CU.EU_FINANZIATO AS EU_FINANZIAMENTO,                 -- FIX: L2 had EU_FINANZIATO
        CU.NM_DURATA_FINANZ,
        CU.NM_IRR,
        CU.TP_UTILIZZO,
        CU.TP_MOVIMENTO,
        CU.FL_STORNATO,
        CU.FL_STORNO,
        CU.CD_PROMOZIONE,
        CU.NM_MESI_DILAZIONE,
        CU.PC_COMMISSIONE,
        CU.NM_TAEG,
        CU.FL_CONTRIBUTI_PROMO,
        CU.NM_TAN_PROMO,
        CU.NM_TEG_PROMO,
        CU.NM_TAEG_PROMO,
        CU.FL_TAEG_FISSO,
        CU.NM_TAEG_FISSO_MIN,
        CU.NM_TAEG_FISSO_MAX,
        CU.PC_SCONTO,
        CU.NM_RATE,
        CU.PC_TASSO_RATA,
        CU.TS_INIZIO_VALIDITA
    --FROM AGOS_DEV_16000.L2_PRODOTTO.CARTE_UTILIZZI_TEST AS CU
    FROM {{ ref('carte_utilizzi')}} AS CU
    -- TODO LEFT JOIN {{ '{{' }} ref('ana_gerarchia_territoriale_m') {{ '}}' }} AS AGT
    --   ON AGT.CD_NODO_FOGLIA = CU.CD_NODO_FOGLIA
    --   poi sostituire i CAST(NULL...) con AGT.CD_RETE / CD_AREA / CD_DISTRETTO / CD_FILIALE
{%- endset -%}

{{ scd2_foto_mensile(
    src_sql  = src_sql,
    key_cols = ['TP_PROCEDURA', 'CD_PROTOCOLLO', 'CD_RIGA', 'CD_EMETTITORE'],
    ts_col   = 'TS_INIZIO_VALIDITA'
) }}