

with

-- =========================================================================
-- 1. UNIONE DELLE TRE FONTI PRINCIPALI (grain di base)
-- =========================================================================

src_crco as (

    select
        scrco_pratica              as cd_pratica,
        scrco_provenienza          as tp_procedura,
        scrco_cliente              as cd_controparte,
        scrco_data_estrazione      as dt_osservazione,
        null                       as cd_emettitore,   -- scrco_cmeme non c'è nella scrco
        scrco_cdsecur              as cd_secur,
        scrco_nm_mesi_impagato     as nm_mesi_impagato,
        scrco_imrdtann             as eu_reddito_annuo_cliente,
        scrco_cdocc                as cd_occupazione,
        scrco_dt_decorrenza        as dt_decorrenza,
        'CO'                       as sistema_origine,
        'AIRB'                     as tp_perimetro,
        cast(null as varchar)      as tp_origine_pratica_raw,   -- CO: valorizzato via join a PRATICA_M
        scrco_data_caricamento     as dt_caricamento_raw,
        scrco_cdstciv              as cd_stato_civile_raw,
        cast(null as varchar)      as fl_atc_raw,               -- FL_ATC esiste solo su IFBLFSTDPR
        scrco_ragset               as cd_subptf_det_raw,
        cast(null as varchar)      as tp_subptf_raw,            -- CO: TP_SUBPTF valorizzato via join a IFBLFPVKCO
        scrco_e_onb                as eu_on_balance_raw
    from AGOS_DEV_16000.L1_O_BAS.IFBLFSCRCO_TEST

),

src_crca as (

    select
        scrca_pratica              as cd_pratica,
        scrca_provenienza          as tp_procedura,
        scrca_cliente              as cd_controparte,
        scrca_data_estrazione      as dt_osservazione,
        scrca_cmeme                as cd_emettitore,
        cast(null as varchar)      as cd_secur,                 -- FL_SRT non previsto per le carte da specifica
        scrca_nm_mesi_impagato     as nm_mesi_impagato,
        scrca_imrdtann             as eu_reddito_annuo_cliente,
        scrca_cdocc                as cd_occupazione,
        scrca_dt_decorrenza        as dt_decorrenza,
        'CA'                       as sistema_origine,
        'AIRB'                     as tp_perimetro,
        cast(null as varchar)      as tp_origine_pratica_raw,   -- CA: valorizzato via join a PRATICA_M
        cast(null as date)         as dt_caricamento_raw,       -- CA: valorizzato via join a PRATICA_M
        cast(null as varchar)      as cd_stato_civile_raw,      -- CA: valorizzato via join a SOCIODEMO_SCORE
        cast(null as varchar)      as fl_atc_raw,
        cast(null as varchar)      as cd_subptf_det_raw,        -- TODO: origine non chiara in specifica (rif. "PD_TYPE")
        cast(null as varchar)      as tp_subptf_raw,            -- CA: TP_SUBPTF valorizzato via join a IFBLFPVKCA
        scrca_e_onb                as eu_on_balance_raw
   from AGOS_DEV_16000.L1_O_BAS.IFBLFSCRCA_TEST

),

src_stdpr as (

    select
        stdpr_pratica              as cd_pratica,
        stdpr_provenienza          as tp_procedura,
        stdpr_cliente              as cd_controparte,
        stdpr_data_estrazione      as dt_osservazione,
        stdpr_cmeme                as cd_emettitore,
        stdpr_cdsecur              as cd_secur,
        stdpr_nm_mesi_impagato     as nm_mesi_impagato,
        stdpr_imrdtann             as eu_reddito_annuo_cliente,
        stdpr_cdocc                as cd_occupazione,
        stdpr_data_decorrenza      as dt_decorrenza,
        'STD'                      as sistema_origine,
        'STD'                      as tp_perimetro,
        stdpr_tp_orig_prat         as tp_origine_pratica_raw,
        stdpr_data_caricamento     as dt_caricamento_raw,
        stdpr_cdstciv              as cd_stato_civile_raw,
        stdpr_atc                  as fl_atc_raw,
        stdpr_ragset               as cd_subptf_det_raw,
        stdpr_subptf               as tp_subptf_raw,
        cast(null as number(13,2)) as eu_on_balance_raw          -- STD: valorizzato via join a SALDO_CONTABILE_M
    from AGOS_DEV_16000.L1_O_BAS.IFBLFSTDPR_TEST

),

base as (
    select * from src_crco
    union all
    select * from src_crca
    union all
    select * from src_stdpr
),

-- =========================================================================
-- 2. DIMENSIONI / MASTER "SEMPLICI" (join diretta su CD_PRATICA + TP_PROCEDURA,
--    nessun rischio di fan-out se le master sono a grana pratica/procedura)
-- =========================================================================

pratica as (
    select
        p.cd_pratica,
        p.tp_procedura,
        p.cd_tipo_prodotto,
        p.cd_prodotto,
        p.cd_stato,
        p.ds_stato,
        p.tp_orig_prat,
        c.nm_durata_finanz,
        p.dt_chiusura_regolare,
        p.dt_chiusura_effettiva,
        p.dt_estinzione_anticipata,
        p.dt_passaggio_perdita,
        p.dt_cessione,
        p.dt_liquidazione,
        p.dt_caricamento           as dt_caricamento_pratica,
        p.dt_stornata,
    --    p.dt_attivazione,
        p.dt_prima_scadenza,
        p.fl_dbt,
        p.eu_finanziato,
        p.eu_fido,
        p.cd_macro_prodotto_1,
        p.cd_macro_prodotto_2,
        p.cd_macro_prodotto_3,
        p.cd_macro_prodotto_4,
        p.cd_mercato_1,
        p.cd_mercato_2,
        p.cd_mercato_3,
        p.cd_mercato_4
    from {{ ref('pratica_m') }} as p
    left join {{ ref('consumo_m') }} as c
    on p.cd_pratica = c.cd_pratica
    and p.tp_procedura = c.tp_procedura
),

carta as (
    select
        cd_pratica,
        tp_procedura,
        tp_categoria_carte,
        cd_blocco,
        dt_rinnovo,
        dt_primo_utilizzo,      -- corretto: la specifica selezionava per errore DT_RINNOVO
        cd_spedizione,
        dt_attivazione_carta as dt_attivazione
    from {{ ref('carta_m') }}
),

sociodemo as (
    select
        cd_pratica,
        tp_procedura,
        cd_controparte,
        cd_stato_civile,
        tp_attivita
    from AGOS_DEV_16000.L2_SCORING.SOCIODEMO_SCORE_TEST
    where tp_rapporto = 'CL'   -- filtra solo il record associato al cliente
),

pvkco as (
    select
        pvkco_pratica     as cd_pratica,
        pvkco_provenienza as tp_procedura,
        pvkco_data_estrazione as dt_osservazione,
        pvkco_fl_sme,
        PVKCO_SUBPTF as tp_subptf
    from AGOS_DEV_16000.L1_O_BAS.IFBLFPVKCO_TEST
),

pvkca as (
    select
        pvkca_pratica     as cd_pratica,
        pvkca_provenienza as tp_procedura,
        pvkca_data_estrazione as dt_osservazione,
        pvkca_fl_sme,
        PVKCA_SUBPTF as tp_subptf
    from AGOS_DEV_16000.L1_O_BAS.IFBLFPVKCA_TEST
),

cartolarizzazioni as (
    select distinct
        cd_pratica,
        tp_procedura
    from {{ ref('cartolarizzazioni_m') }}
),

srt as (
    select
        cd_secur,
        fl_srt
    from AGOS_DEV_16000.TECH.LOOKUP_SRT_O
),

stato_creditizio as (
    select
        cd_pratica,
        tp_procedura,
        fl_dflt_eba
    from {{ ref('stato_creditizio_m') }}
),

saldo_contabile as (
    select
        cd_pratica,
        tp_procedura,
        eu_on_balance
    from {{ ref('saldo_contabile_m') }}
),

saldo_off as (
    select
        cd_pratica,
        tp_procedura,
        eu_off_balance
    from {{ ref('saldo_off_m') }}
),

saldo_gestionale as (
    select
        cd_pratica,
        tp_procedura,
        dt_osservazione,
        eu_impiego_gestionale,
        eu_capitale_scaduto,
        eu_interessi_scaduto
    from {{ ref('saldo_gestionale_m') }}
),

default_eba as (
    select
        cd_pratica,
        tp_procedura,
        dt_osservazione,
        dt_ingrs_dflt_eba,
        dt_uscita_dflt_eba
    from AGOS_DEV_16000.L3_CAMPIONI.DM_PRATICHE_DEFAULT_M  -- ('dm_pratiche_default_m') 
),

recupero_contenzioso as (
    select distinct
        cd_pratica,
        tp_provenienza as tp_procedura
    from {{ ref('pratica_a_recupero') }}
    where cd_stato_contenzioso is not null     
),

-- =========================================================================
-- 3. LOGICHE "POINT IN TIME" / DEDUP — risolte 1 riga per chiave di `base`
--    per evitare fan-out quando poi le agganciamo tutte insieme
-- =========================================================================

residenza as (
    select
        b.cd_pratica,
        b.tp_procedura,
        b.dt_osservazione,
        va.cd_provincia_residenza,
        va.cd_regione_residenza
    from base b
    left join {{ ref('variazioni_anagrafiche') }} va
        on b.cd_controparte = va.cd_controparte
        -- NOTE: logica SCD2 point-in-time corretta (vedi punto 2 in testa al file)
        and va.ts_inizio_validita <= b.dt_osservazione
        and (va.ts_fine_validita > b.dt_osservazione or va.ts_fine_validita is null)
    qualify row_number() over (
        partition by b.cd_pratica, b.tp_procedura, b.dt_osservazione
        order by va.ts_inizio_validita desc
    ) = 1
),

sovraindebitamento as (
    select
        b.cd_pratica,
        b.tp_procedura,
        b.dt_osservazione,
        s.cd_controparte as sov_match
    from base b
    left join (
        select cd_controparte, TS_INSERIMENTO, dt_inizio, dt_fine, pr_segnalazione
        from {{ ref('segnalazioni_anagrafiche') }}
        where tp_segnalazione = 'SOV'
    ) s
        on b.cd_controparte = s.cd_controparte
        and s.TS_INSERIMENTO < b.dt_osservazione
        and s.dt_inizio < b.dt_osservazione
        and (s.dt_fine > b.dt_osservazione or s.dt_fine is null)
    qualify row_number() over (
        partition by b.cd_pratica, b.tp_procedura, b.dt_osservazione
        order by s.pr_segnalazione desc
    ) = 1
),

truffa as (
    select
        b.cd_pratica,
        b.tp_procedura,
        b.dt_osservazione,
        t.cd_pratica as truffa_match
    from base b
    left join (
        select cd_pratica, tp_procedura, ts_inserimento
        from {{ ref('gestione_truffe') }}
        where fl_subita = 'S' or fl_sventata = 'S'
    ) t
        on b.cd_pratica = t.cd_pratica
        and b.tp_procedura = t.tp_procedura
        and b.dt_osservazione >= t.ts_inserimento
    qualify row_number() over (
        partition by b.cd_pratica, b.tp_procedura, b.dt_osservazione
        order by t.ts_inserimento desc
    ) = 1
),

scaduto_eba as (
    select
        b.cd_pratica,
        b.tp_procedura,
        b.dt_osservazione,
        gs.nm_gg_scaduto_eba_cli
    from base b
    left join {{ ref('giorni_scaduto') }} gs
        on b.cd_pratica = gs.cd_pratica
        and b.tp_procedura = gs.tp_procedura
        and b.dt_osservazione >= gs.ts_inserimento
    qualify row_number() over (
        partition by b.cd_pratica, b.tp_procedura, b.dt_osservazione
        order by gs.ts_inserimento desc
    ) = 1
),

cessioni_resolved as (
    select
        b.cd_pratica,
        b.tp_procedura,
        b.dt_osservazione,
        c.eu_incasso_cessione
    from base b
    left join (
        select cd_pratica, tp_procedura, dt_cessione, eu_incasso_cessione
        from {{ ref('cessioni') }}
        qualify row_number() over (
            partition by cd_pratica, tp_procedura
            order by pr_cessione
        ) = 1
    ) c
        on b.cd_pratica = c.cd_pratica
        and b.tp_procedura = c.tp_procedura
        and b.dt_osservazione >= c.dt_cessione
),

consolidamenti_resolved as (
    select
        b.cd_pratica,
        b.tp_procedura,
        b.dt_osservazione,
        cons.cd_pratica_consolidata,
        cons.cd_pratica_consolidante,
        cons.TS_INSERIMENTO
    from base b
    left join (
        select
            cd_pratica_consolidata,
            cd_pratica_consolidante,
            TP_PROC_CONSOLIDANTE,
            TS_INSERIMENTO,
            nm_progressivo
        from {{ ref('consolidamenti') }}   
        qualify row_number() over (
            partition by cd_pratica_consolidante, TP_PROC_CONSOLIDANTE
            order by nm_progressivo desc
        ) = 1
    ) cons
        on b.cd_pratica = cons.cd_pratica_consolidante
        and b.tp_procedura = cons.TP_PROC_CONSOLIDANTE
),

-- =========================================================================
-- 4. ENRICHMENT — un'unica passata di LEFT JOIN sulle CTE sopra
-- =========================================================================

enriched as (

    select
        b.*,

        p.cd_tipo_prodotto,
        p.cd_prodotto,
        p.cd_stato,
        p.ds_stato,
        p.tp_orig_prat,
        p.nm_durata_finanz,
        p.dt_chiusura_regolare,
        p.dt_chiusura_effettiva,
        p.dt_estinzione_anticipata,
        p.dt_passaggio_perdita,
        p.dt_cessione,
        p.dt_liquidazione,
        p.dt_caricamento_pratica,
        p.dt_stornata,
        c.dt_attivazione,
        p.dt_prima_scadenza,
        p.fl_dbt,
        p.eu_finanziato,
        p.eu_fido,
        p.cd_macro_prodotto_1,
        p.cd_macro_prodotto_2,
        p.cd_macro_prodotto_3,
        p.cd_macro_prodotto_4,
        p.cd_mercato_1,
        p.cd_mercato_2,
        p.cd_mercato_3,
        p.cd_mercato_4,

        c.tp_categoria_carte,
        c.cd_blocco,
        c.dt_rinnovo,
        c.dt_primo_utilizzo,
        c.cd_spedizione,

        sd.cd_stato_civile   as cd_stato_civile_sociodemo,
        sd.tp_attivita       as sociodemo_tp_attivita,

        pvkco.pvkco_fl_sme        as pvkco_fl_sme,
        pvkco.tp_subptf      as pvkco_subptf,
        pvkca.pvkca_fl_sme       as pvkca_fl_sme,
        pvkca.tp_subptf      as pvkca_subptf,

        case when sec.cd_pratica is not null then 'S' else 'N' end as fl_secur,
        case when srt.fl_srt = 'Y' then 'Y' else 'N' end            as fl_srt,
        sc.fl_dflt_eba,

        sco.eu_on_balance    as eu_on_balance_saldo_contabile,
        so.eu_off_balance,
        sg.eu_impiego_gestionale,
        sg.eu_capitale_scaduto,
        sg.eu_interessi_scaduto,

        def.dt_ingrs_dflt_eba,
        def.dt_uscita_dflt_eba,

        case when rec.cd_pratica is not null then 'S' else 'N' end as fl_rif_contenzioso_match,

        res.cd_provincia_residenza,
        res.cd_regione_residenza,

        case when sov.sov_match is not null then 'S' else 'N' end as fl_sovraindebitamento,
        case when tr.truffa_match is not null then 'S' else 'N' end as fl_truffa,

        sca.nm_gg_scaduto_eba_cli,
        ces.eu_incasso_cessione,

        cons.cd_pratica_consolidata,
        cons.cd_pratica_consolidante,
        cons.TS_INSERIMENTO as consolidamento_TS_INSERIMENTO,

        -- flag di supporto per FL_BASE_DATI / FL_AQR
        case when p.dt_passaggio_perdita is not null then 'S' else 'N' end as fl_perdita,
        case
            when c.cd_spedizione is not null and c.cd_spedizione not in ('D', 'S') then 'S'
            else 'N'
        end as fl_virtuale   
        
    from base b
    left join pratica                 p    on b.cd_pratica = p.cd_pratica   and b.tp_procedura = p.tp_procedura
    left join carta                   c    on b.cd_pratica = c.cd_pratica   and b.tp_procedura = c.tp_procedura
    left join sociodemo               sd   on b.cd_pratica = sd.cd_pratica  and b.tp_procedura = sd.tp_procedura and b.cd_controparte = sd.cd_controparte
    left join pvkco                        on b.cd_pratica = pvkco.cd_pratica and b.tp_procedura = pvkco.tp_procedura and b.dt_osservazione = pvkco.dt_osservazione
    left join pvkca                        on b.cd_pratica = pvkca.cd_pratica and b.tp_procedura = pvkca.tp_procedura and b.dt_osservazione = pvkca.dt_osservazione
    left join cartolarizzazioni       sec  on b.cd_pratica = sec.cd_pratica  and b.tp_procedura = sec.tp_procedura
    left join srt                          on b.cd_secur = srt.cd_secur
    left join stato_creditizio        sc   on b.cd_pratica = sc.cd_pratica   and b.tp_procedura = sc.tp_procedura
    left join saldo_contabile         sco  on b.cd_pratica = sco.cd_pratica  and b.tp_procedura = sco.tp_procedura
    left join saldo_off               so   on b.cd_pratica = so.cd_pratica   and b.tp_procedura = so.tp_procedura
    left join saldo_gestionale        sg   on b.cd_pratica = sg.cd_pratica   and b.tp_procedura = sg.tp_procedura and b.dt_osservazione = sg.dt_osservazione
    left join default_eba             def  on b.cd_pratica = def.cd_pratica  and b.tp_procedura = def.tp_procedura and b.dt_osservazione = def.dt_osservazione
    left join recupero_contenzioso    rec  on b.cd_pratica = rec.cd_pratica  and b.tp_procedura = rec.tp_procedura
    left join residenza               res  on b.cd_pratica = res.cd_pratica  and b.tp_procedura = res.tp_procedura and b.dt_osservazione = res.dt_osservazione
    left join sovraindebitamento      sov  on b.cd_pratica = sov.cd_pratica  and b.tp_procedura = sov.tp_procedura and b.dt_osservazione = sov.dt_osservazione
    left join truffa                  tr   on b.cd_pratica = tr.cd_pratica   and b.tp_procedura = tr.tp_procedura and b.dt_osservazione = tr.dt_osservazione
    left join scaduto_eba             sca  on b.cd_pratica = sca.cd_pratica  and b.tp_procedura = sca.tp_procedura and b.dt_osservazione = sca.dt_osservazione
    left join cessioni_resolved       ces  on b.cd_pratica = ces.cd_pratica  and b.tp_procedura = ces.tp_procedura and b.dt_osservazione = ces.dt_osservazione
    left join consolidamenti_resolved cons on b.cd_pratica = cons.cd_pratica and b.tp_procedura = cons.tp_procedura and b.dt_osservazione = cons.dt_osservazione

),

-- =========================================================================
-- 5. SELECT FINALE — ordine campi come da specifica
-- =========================================================================

final as (

    select

        e.cd_pratica,
        e.tp_procedura,
        e.cd_controparte,
        e.dt_osservazione,

        e.cd_tipo_prodotto,
        e.cd_emettitore,
        e.cd_prodotto,

        case when e.sistema_origine = 'CA' then e.tp_categoria_carte end as tp_categoria_carte,
        case when e.sistema_origine = 'CA' then e.cd_blocco end          as cd_blocco,

        e.cd_stato,
        e.ds_stato,

        case
            when e.sistema_origine = 'STD' then e.tp_origine_pratica_raw
            else e.tp_orig_prat
        end as tp_origine_pratica,

        e.nm_durata_finanz as nm_durata_finanziamento,

        case
            when e.consolidamento_TS_INSERIMENTO < e.dt_osservazione
                then e.cd_pratica_consolidata
        end as cd_ultima_pratica_old,

        e.nm_mesi_impagato,

        e.cd_provincia_residenza,
        e.cd_regione_residenza,

        e.eu_reddito_annuo_cliente,

        case
            when e.sistema_origine = 'CA' then e.cd_stato_civile_sociodemo
            else e.cd_stato_civile_raw
        end as cd_stato_civile,

        e.cd_occupazione,
        e.tp_perimetro,

        e.dt_chiusura_regolare as dt_chiusura,
        e.dt_estinzione_anticipata,
        e.dt_passaggio_perdita,
        e.dt_cessione,
        e.dt_liquidazione,
        e.dt_decorrenza,

        coalesce(e.dt_caricamento_raw, e.dt_caricamento_pratica) as dt_caricamento,

        e.dt_stornata as dt_storno,
        e.dt_attivazione,

        case when e.sistema_origine = 'CA' then e.dt_rinnovo end        as dt_rinnovo,
        case when e.sistema_origine = 'CA' then e.dt_primo_utilizzo end as dt_primo_utilizzo,

        e.dt_prima_scadenza,

        case
            when e.dt_decorrenza is not null and e.dt_chiusura_effettiva is null then 'S'
            else 'N'
        end as fl_passate_gestione,

        e.fl_truffa,
        e.fl_secur,
        e.fl_srt,
        e.fl_sovraindebitamento,

        e.fl_dbt,

        case when e.cd_pratica_consolidante is not null then 'S' else 'N' end as fl_rifin,
        case
            when e.cd_pratica_consolidante is not null and e.fl_rif_contenzioso_match = 'S' then 'S'
            else 'N'
        end as fl_rif_contenzioso,

        e.fl_dflt_eba as fl_default_eba,

        case when e.sistema_origine = 'STD' then e.fl_atc_raw end as fl_atc,

        case
            when e.sistema_origine = 'CO'  then e.pvkco_fl_sme
            when e.sistema_origine = 'CA'  then e.pvkca_fl_sme
            when e.sistema_origine = 'STD' then case when e.sociodemo_tp_attivita = 'A' then 'S' else 'N' end
        end as fl_sme,

        case
            when (
                    (coalesce(e.eu_on_balance_saldo_contabile, e.eu_on_balance_raw, 0) != 0
                     or coalesce(e.eu_off_balance, 0) != 0)
                    or e.fl_perdita = 'S'
                    or (
                        coalesce(e.eu_on_balance_saldo_contabile, e.eu_on_balance_raw, 0) = 0
                        and coalesce(e.eu_off_balance, 0) = 0
                        and coalesce(e.eu_impiego_gestionale, 0) != 0
                    )
                 )
                 and coalesce(e.fl_virtuale, 'N') = 'N'
            then 'S' else 'N'
        end as fl_base_dati,

        case
            when (
                    (coalesce(e.eu_on_balance_saldo_contabile, e.eu_on_balance_raw, 0) != 0
                     or coalesce(e.eu_off_balance, 0) != 0)
                    or e.fl_perdita = 'S'
                 )
                 and coalesce(e.fl_virtuale, 'N') = 'N'
                 and not (
                        coalesce(e.eu_on_balance_saldo_contabile, e.eu_on_balance_raw, 0) = 0
                        and coalesce(e.eu_off_balance, 0) = 0
                        and coalesce(e.eu_impiego_gestionale, 0) != 0
                     )
            then 'S' else 'N'
        end as fl_aqr,

        case
            when e.sistema_origine = 'CO'  then e.pvkco_subptf
            when e.sistema_origine = 'CA'  then e.pvkca_subptf
            when e.sistema_origine = 'STD' then e.tp_subptf_raw
        end as tp_subptf,

        case
            when e.sistema_origine in ('CO', 'STD') then e.cd_subptf_det_raw
            -- else NULL per CA: origine non chiara in specifica (rif. "PD_TYPE"),
        end as cd_subptf_det,

        e.cd_macro_prodotto_1,
        e.cd_macro_prodotto_2,
        e.cd_macro_prodotto_3,
        e.cd_macro_prodotto_4,

        e.cd_mercato_1,
        e.cd_mercato_2,
        e.cd_mercato_3,
        e.cd_mercato_4,

        cast(null as number(5,2)) as pc_indebitamento,   -- TODO: regola tecnica non fornita in specifica (fonte "CDE")

        e.eu_finanziato,
        cast(null as number(13,2)) as eu_rata_origine,   -- TODO: regola tecnica non fornita in specifica
        cast(null as number(13,2)) as eu_ultima_rata,    -- TODO: regola tecnica non fornita in specifica
        e.eu_fido,

        coalesce(e.eu_on_balance_raw, e.eu_on_balance_saldo_contabile) as eu_on_balance,
        e.eu_off_balance,
        e.eu_impiego_gestionale,

        cast(null as number(13,2)) as eu_incasso,        -- TODO: regola tecnica non fornita in specifica (fonte OXINFREPT)
        e.eu_incasso_cessione,

        e.eu_capitale_scaduto + e.eu_interessi_scaduto as eu_scaduto,

        e.nm_gg_scaduto_eba_cli as nm_gg_scaduto_eba,

        e.dt_ingrs_dflt_eba   as dt_ingrs_default_eba,
        e.dt_uscita_dflt_eba  as dt_uscita_default_eba

    from enriched e

)

select * from final