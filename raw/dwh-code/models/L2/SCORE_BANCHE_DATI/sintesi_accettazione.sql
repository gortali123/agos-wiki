-- Modello L2: SINTESI_ACCETTAZIONE
-- Storicizzazione: S4 (incremental / insert_overwrite) - nessun blocco incremental, nessun LASTMODIFIEDDATA
-- Multiprocedura P=3: Consumo (TP_PROCEDURA_OCS='CO'), CARTE ('CA'), CQS
--
-- WARN: il Catalogo Entita' riporta SORGENTI: - (nessuna coppia tabella:cluster indicata), quindi non e'
-- possibile determinare con certezza i cluster (A1/A2/B1/C) delle tabelle sorgente L1 per applicare
-- automaticamente il filtro FL_DELETED o il pre_hook delete_l2. Nessun filtro FL_DELETED è stato aggiunto
-- sulle tabelle main (IFKCFRSI/QSPRA/PLPRAT/CRCAR) salvo dove esplicitamente presente nella regola tecnica.
-- WARN: per Consumo/CARTE si è dedotto un filtro WHERE IFKCRSI_PROCEDURA_OCS = 'CO'/'CA' sul perimetro
-- IFKCFRSI per separare le due procedure (il data model mostra questo filtro solo come condizione aggiuntiva
-- nella JOIN verso PLPRAT/CRCAR, non esplicitamente come WHERE sulla select principale).
--
-- CORREZIONE UTENTE (perimetro "perim"): come richiesto, Consumo e CARTE non partono piu' da IFKCFRSI
-- grezza ma da una pre-elaborazione che tiene, per ciascuna coppia (IFKCRSI_PROCEDURA_OCS, IFKCRSI_CD_PRATICA),
-- solo l'ultima chiamata non-VariazLight (vedi CTE perim_ifkcfrsi). CQS continua a partire da QSPRA cosi'
-- come indicato.
-- WARN: la UNION letterale fornita dall'utente (perim_pre filtrato su IFKCFRSI UNION SELECT * FROM QSPRA)
-- non e' eseguibile: le due tabelle hanno schemi/numero di colonne differenti, quindi non puo' essere una
-- vera UNION SQL. E' stata interpretata come "basi distinte per ramo" (perim_ifkcfrsi per Consumo/CARTE,
-- QSPRA diretta per CQS), preservando l'intento di business senza produrre SQL non eseguibile.

with

light_ranked as (
    -- CTE riusata per CD_FASCIA_RBP_LIGHT (Consumo e CARTE): ultima chiamata con CD_OPERAZIONE = 'VariazLight'
    select
        l.ifkcrsi_procedura_ocs,
        l.ifkcrsi_cd_pratica,
        l.ifkcrsi_richiesta,
        l.ifkcrsi_fascia_rbp,
        row_number() over (
            partition by l.ifkcrsi_procedura_ocs, l.ifkcrsi_cd_pratica
            order by l.ifkcrsi_data desc, l.ifkcrsi_ora desc
        ) as ordinamento_chiamate_prat
    from {{ ref('ifkcfrsi') }} as l
    where l.ifkcrsi_cd_operazione = 'VariazLight'
),

perim_pre as (
    -- Pre-elaborazione richiesta dall'utente: ultima chiamata NON-VariazLight per (procedura, pratica)
    select
        a.*,
        row_number() over (
            partition by a.ifkcrsi_procedura_ocs, a.ifkcrsi_cd_pratica
            order by a.ifkcrsi_data desc, a.ifkcrsi_ora desc
        ) as ordinamento_chiamate_prat
    from {{ ref('ifkcfrsi') }} as a
    where a.ifkcrsi_cd_operazione <> 'VariazLight'
),

perim_ifkcfrsi as (
    -- Perimetro Consumo/CARTE: solo l'ultima chiamata non-VariazLight per pratica/procedura
    select *
    from perim_pre
    where ordinamento_chiamate_prat = 1
),

crcarblo_rt as (
    -- WARN: la RT originale raggruppa per CAB_PRATICA, CAB_OPE_IMMISSIONE ma seleziona solo CAB_PRATICA:
    -- puo' produrre piu' righe per CAB_PRATICA nella successiva LEFT JOIN (fan-out)
    select
        b.cab_pratica,
        max(b.cab_data_immissione) as dt_ritirata
    from {{ ref('crcarblo') }} as b
    where b.cab_cod_blocco_ocs = 'RT'
      and b.fl_deleted = 'N'
    group by b.cab_pratica, b.cab_ope_immissione
),

qsprast_35 as (
    select
        qprst_num_pratica,
        max(qprst_data) as dt_respinta
    from {{ ref('qsprast') }}
    where qprst_stato = '35'
      and fl_deleted = 'N'
    group by qprst_num_pratica
),

qsprast_rt as (
    select
        qprst_num_pratica,
        max(qprst_data) as dt_ritirata
    from {{ ref('qsprast') }}
    where qprst_attributo = 'RT'
      and fl_deleted = 'N'
    group by qprst_num_pratica
),

scoring_dettaglio_agg as (
    select
        b.cd_inquirycode,
        max(case when b.pr_modulo = 1 then b.cd_modulo_objcode end) as cd_score_modulo_1_objcode,
        max(case when b.pr_modulo = 1 then b.nm_modulo_aligned end) as nm_score_modulo_1_aligned,
        max(case when b.pr_modulo = 2 then b.cd_modulo_objcode end) as cd_score_modulo_2_objcode,
        max(case when b.pr_modulo = 2 then b.nm_modulo_aligned end) as nm_score_modulo_2_aligned,
        max(case when b.pr_modulo = 3 then b.cd_modulo_objcode end) as cd_score_modulo_3_objcode,
        max(case when b.pr_modulo = 3 then b.nm_modulo_aligned end) as nm_score_modulo_3_aligned,
        max(case when b.pr_modulo = 8 then b.cd_modulo_objcode end) as cd_score_modulo_8_objcode,
        max(case when b.pr_modulo = 8 then b.nm_modulo_aligned end) as nm_score_modulo_8_aligned,
        max(case when b.pr_modulo = 9 then b.cd_modulo_objcode end) as cd_score_modulo_9_objcode,
        max(case when b.pr_modulo = 9 then b.nm_modulo_aligned end) as nm_score_modulo_9_aligned
    from {{ ref('scoring_dettaglio_output') }} as b
    group by b.cd_inquirycode
),

scoring_testata as (
    select
        b.cd_inquirycode,
        b.cd_segmentazione
    from {{ ref('scoring_testata_output') }} as b
),

accettazione_input_agg as (
    -- WARN: per i campi *_CLI/_COO, la CARTE ha nel data model refusi sistematici (alias errato
    -- "AS [L2]ACCETTAZIONE_INPUT" e "GROUP BS" invece di "GROUP BY"); la logica CD_RUOLO='R'/'G' e' identica
    -- a quella Consumo (stesso CD_INQUIRYCODE), quindi la CTE e' condivisa tra Consumo e CARTE.
    -- WARN: per NM_CTCPOS_SCORE_COMPLETO_CLI la riga CARTE del data model usa CD_RUOLO = 'G' (invece di 'R'
    -- come in Consumo per lo stesso campo _CLI): trattato come refuso di copia e mantenuto 'R' per coerenza
    -- con la semantica CLI/COO applicata a tutti gli altri campi.
    select
        b.cd_inquirycode,
        max(case when b.cd_ruolo = 'R' then b.nm_eurisc_cbscore end) as nm_eurisc_cbscore_cli,
        max(case when b.cd_ruolo = 'G' then b.nm_eurisc_cbscore end) as nm_eurisc_cbscore_coo,
        max(case when b.cd_ruolo = 'R' then b.nm_eurisc_nohit_punteggio end) as nm_eurisc_nohit_punteggio_cli,
        max(case when b.cd_ruolo = 'G' then b.nm_eurisc_nohit_punteggio end) as nm_eurisc_nohit_punteggio_coo,
        max(case when b.cd_ruolo = 'R' then b.tp_eurisc_fascia_score end) as tp_eurisc_fascia_score_cli,
        max(case when b.cd_ruolo = 'G' then b.tp_eurisc_fascia_score end) as tp_eurisc_fascia_score_coo,
        max(case when b.cd_ruolo = 'R' then b.cd_ctcpos_score_completo end) as nm_ctcpos_score_completo_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_ctcpos_score_completo end) as nm_ctcpos_score_completo_coo,
        max(case when b.cd_ruolo = 'R' then b.cd_ctcpos_score_completo_fascia end) as tp_ctcpos_score_completo_fascia_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_ctcpos_score_completo_fascia end) as tp_ctcpos_score_completo_fascia_coo,
        max(case when b.cd_ruolo = 'R' then b.fl_ctcpos_hit_nohit end) as fl_ctcpos_hit_nohit_cli,
        max(case when b.cd_ruolo = 'G' then b.fl_ctcpos_hit_nohit end) as fl_ctcpos_hit_nohit_coo,
        case
            when max(case when b.cd_ruolo = 'R' then b.nm_eurisc_cbscore end) not in (99997, 99998) then 'HIT'
            when max(case when b.cd_ruolo = 'R' then b.nm_eurisc_cbscore end) = 99998 then 'NOHIT'
            else null
        end as fl_eurisc_hit_nohit_cli,
        case
            when max(case when b.cd_ruolo = 'G' then b.nm_eurisc_cbscore end) not in (99997, 99998) then 'HIT'
            when max(case when b.cd_ruolo = 'G' then b.nm_eurisc_cbscore end) = 99998 then 'NOHIT'
            else null
        end as fl_eurisc_hit_nohit_coo,
        max(case when b.cd_ruolo = 'R' then b.nm_ob_score end) as nm_ob_score_cli,
        max(case when b.cd_ruolo = 'R' then b.fl_ob_esenzione_reddito end) as fl_ob_esenzione_reddito_cli,
        max(case when b.cd_ruolo = 'R' then b.cd_ob_stato end) as cd_ob_stato_cli,
        max(case when b.cd_ruolo = 'R' then b.cd_ctcpos_stato end) as cd_ctcpos_stato_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_ctcpos_stato end) as cd_ctcpos_stato_coo,
        max(case when b.cd_ruolo = 'R' then b.cd_eurisc_crif_stato end) as cd_eurisc_crif_stato_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_eurisc_crif_stato end) as cd_eurisc_crif_stato_coo,
        max(case when b.cd_ruolo = 'G' then b.pc_dbr_perc_indebitamento_pratica end) as pc_dbr_perc_indebitamento_pratica,
        max(case when b.cd_ruolo = 'G' then b.cd_inquirycode end) as cd_inquirycode_out,
        max(case when b.cd_ruolo = 'G' then b.cd_processcode end) as cd_processcode,
        max(case when b.cd_ruolo = 'R' then b.cd_indicatore_prequalifica end) as cd_indicatore_prequalifica_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_indicatore_prequalifica end) as cd_indicatore_prequalifica_coo,
        max(case when b.cd_ruolo = 'R' then b.cd_news_banco end) as cd_news_banco_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_news_banco end) as cd_news_banco_coo,
        max(case when b.cd_ruolo = 'R' then b.cd_segmento_personal end) as cd_segmento_personal_cli,
        max(case when b.cd_ruolo = 'G' then b.cd_segmento_personal end) as cd_segmento_personal_coo,
        -- WARN: TAB indicava [L2]ACCETTAZIONE_OUTPUT per TP_SCIPAFI_CLI/COO, ma la RT referenzia L2.ACCETTAZIONE_INPUT:
        -- mantenuta la sorgente indicata dalla RT (autoritativa)
    from {{ ref('accettazione_input') }} as b
    group by b.cd_inquirycode
),

accettazione_output_agg as (
    select
        b.cd_inquirycode,
        max(case when b.cd_ruolo = 'R' then b.tp_scipafi end) as tp_scipafi_cli,
        max(case when b.cd_ruolo = 'G' then b.tp_scipafi end) as tp_scipafi_coo
    from {{ ref('accettazione_output') }} as b
    group by b.cd_inquirycode
),


accettazione_output_pr_ov_agg as (
    -- Consolida in un'unica CTE le RT che nel data model erano ripetute con LEFT JOIN separate
    -- filtrate su B.tp_regola = 'PR' oppure 'OV': il filtro tp_regola e' stato spostato dentro i CASE WHEN.
    select
        b.cd_inquirycode,
        sum(case when b.tp_regola = 'PR' and b.ds_esito_regola = 'KO' then 1 else 0 end) as nm_regole_ko,
        listagg(case when b.tp_regola = 'PR' and b.ds_esito_regola = 'KO' then b.ds_messaggio_regola end, ' - ')
            within group (order by b.ds_messaggio_regola) as ds_regole_ko,
        sum(case when b.tp_regola = 'PR' and b.ds_esito_regola = 'NC' then 1 else 0 end) as nm_regole_nc,
        listagg(case when b.tp_regola = 'PR' and b.ds_esito_regola = 'NC' then b.ds_messaggio_regola end, ' - ')
            within group (order by b.ds_messaggio_regola) as ds_regole_nc,
        max(case when b.tp_regola = 'PR' and b.ds_esito_regola = 'KO' then b.cd_firma_regola else null end) as nm_livello_firma_max_ko,
        count(case when b.tp_regola = 'OV' then 1 end) as nm_regole_overrride,
        listagg(case when b.tp_regola = 'OV' then b.ds_messaggio_regola end, ' - ')
            within group (order by b.ds_messaggio_regola) as ds_regole_override,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 180 then b.ds_messaggio_regola end) as ds_regola_180_messaggio,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 180 then b.ds_regola end) as ds_regola_180_descrizione_rules,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 179 then b.ds_messaggio_regola end) as ds_regola_179_messaggio,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 179 then b.ds_regola end) as ds_regola_179_descrizione_rules,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 194 then b.ds_messaggio_regola end) as ds_regola_194_messaggio,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 194 then b.ds_regola end) as ds_regola_194_descrizione_rules,
        max(case when b.tp_regola = 'PR' and b.pr_regola = 43 then b.ds_regola end) as ds_regola_43_descrizione_rules
    from {{ ref('accettazione_output_pr_ov') }} as b
    group by b.cd_inquirycode
),

prescreening_output_lkp as (
    select
        b.cd_inquirycode,
        b.cd_esito as cd_esito_prescreening,
        b.ds_esito as ds_esito_prescreening
    from {{ ref('prescreening_output') }} as b
),

prescreening_pr_agg as (
    -- WARN: TAB indicava PRESCREENING_OUTPUT_PR ma la RT referenzia L2.PRESCREENING_OUTPUT: mantenuta la sorgente da RT.
    -- WARN: la riga Consumo filtra su CD_POLICY_ESITO, la riga CARTE (stesso campo target) su TP_POLICY_ESITO:
    -- trattato come refuso e usata CD_POLICY_ESITO per entrambe le procedure.
    select
        b.cd_inquirycode,
        sum(case when b.cd_policy_esito = 'KO' then 1 else 0 end) as nm_policy_prescreening_ko_cli
    from {{ ref('prescreening_output_pr') }} as b
    group by b.cd_inquirycode
),

consumo as (
    select
        t.ifkcrsi_procedura_ocs as tp_procedura,
        t.ifkcrsi_cd_pratica as cd_pratica,
        pl.plc_stato as cd_stato_prat,
        pl.plc_attributo as cd_attributo_prat,
        null as cd_blocco_prat,
        pl.plc_esito_approvazione as cd_esito_prat,
        case
            when pl.plc_data_decorrenza is not null then pl.plc_data_decorrenza
            when pl.plc_attributo in ('RE', 'RT') then pl.plc_dat_stato_03
        end as dt_esito_prat,
        pl.plc_autore_overr as cd_user_esito_finale,
        pl.plc_motivo_overr as cd_motivo_override,
        cm.cremo_tipo_override as tp_override,
        t.ifkcrsi_esito_elab_cde as cd_esito_elab_cde,
        t.ifkcrsi_ds_esito_elab_cde as ds_esito_elab_cde,
        t.ifkcrsi_esito_chiamata as cd_esito_chiamata,
        t.ifkcrsi_esito_codice as cd_esito_codice,
        t.ifkcrsi_esito_messaggio as ds_esito_messaggio,
        t.ifkcrsi_cd_operazione as cd_operazione,
        t.ifkcrsi_richiesta as nm_richiesta,
        t.ifkcrsi_id_guid_cf as nm_id_guid_cf,
        t.ifkcrsi_esito_amlcheck as cd_esito_amlcheck,
        t.ifkcrsi_ds_esito_amlcheck as ds_esito_amlcheck,
        t.ifkcrsi_prt_car_ora_serv as fl_prt_car_ora_serv,
        t.ifkcrsi_esi_antifraud as cd_esito_antifraud,
        t.ifkcrsi_ds_esi_antifraud as ds_esito_antifraud,
        t.ifkcrsi_esito_gianos as cd_esito_gianos,
        t.ifkcrsi_esito_fircosoft as cd_esito_fircosoft,
        t.ifkcrsi_cd_valutaz_prt as cd_valutaz_prt,
        t.ifkcrsi_apag_con_sospens as fl_apag_con_sospens,
        t.ifkcrsi_scipafi_obbl as fl_scipafi_obbl,
        t.ifkcrsi_livello_firma_prt as cd_livello_firma_prt,
        t.ifkcrsi_area_rischio as cd_area_rischio,
        t.ifkcrsi_vendita_congiunta as fl_tipo_vendita_congiunta,
        {{ custom_to_decimal('t.ifkcrsi_fido_massimo', 13, 2) }} as eu_fido_massimo,
        t.ifkcrsi_motivo_esito as cd_motivo_esito,
        t.ifkcrsi_fascia_rbp as cd_fascia_rbp,
        lr.ifkcrsi_fascia_rbp as cd_fascia_rbp_light,
        t.ifkcrsi_cd_tab_finanz_irr as cd_tab_finanz_irr,
        {{ custom_to_decimal('t.ifkcrsi_fido_score', 13, 2) }} as eu_fido_score,
        t.ifkcrsi_utente as cd_utente,
        to_timestamp(
            lpad(t.ifkcrsi_data::varchar, 8, '0') || lpad(t.ifkcrsi_ora::varchar, 6, '0'),
            'YYYYMMDDHH24MISSFF2'
        ) as ts_risposta
    from perim_ifkcfrsi as t
    left join {{ ref('plprat') }} as pl
        on t.ifkcrsi_cd_pratica = pl.plc_num_pratica
       and t.ifkcrsi_procedura_ocs = 'CO'
    left join {{ ref('cccretmo') }} as cm
        on pl.plc_motivo_overr = cm.cremo_motivo
    left join light_ranked as lr
        on t.ifkcrsi_richiesta = lr.ifkcrsi_richiesta
       and lr.ordinamento_chiamate_prat = 1
    where t.ifkcrsi_procedura_ocs = 'CO'
),

carte as (
    select
        t.ifkcrsi_procedura_ocs as tp_procedura,
        t.ifkcrsi_cd_pratica as cd_pratica,
        cr.crcar_stato as cd_stato_prat,
        null as cd_attributo_prat,
        cr.crcar_blocco as cd_blocco_prat,
        cr.crcar_esito_approvazione as cd_esito_prat,
        coalesce(cr.crcar_st_data_3, cr.crcar_st_data_4, rt.dt_ritirata) as dt_esito_prat,
        cr.crcar_autorizz_override as cd_user_esito_finale,
        cr.crcar_override as cd_motivo_override,
        cm.cremo_tipo_override as tp_override,
        t.ifkcrsi_esito_elab_cde as cd_esito_elab_cde,
        t.ifkcrsi_ds_esito_elab_cde as ds_esito_elab_cde,
        t.ifkcrsi_esito_chiamata as cd_esito_chiamata,
        t.ifkcrsi_esito_codice as cd_esito_codice,
        t.ifkcrsi_esito_messaggio as ds_esito_messaggio,
        t.ifkcrsi_cd_operazione as cd_operazione,
        t.ifkcrsi_richiesta as nm_richiesta,
        t.ifkcrsi_id_guid_cf as nm_id_guid_cf,
        t.ifkcrsi_esito_amlcheck as cd_esito_amlcheck,
        t.ifkcrsi_ds_esito_amlcheck as ds_esito_amlcheck,
        t.ifkcrsi_prt_car_ora_serv as fl_prt_car_ora_serv,
        t.ifkcrsi_esi_antifraud as cd_esito_antifraud,
        t.ifkcrsi_ds_esi_antifraud as ds_esito_antifraud,
        t.ifkcrsi_esito_gianos as cd_esito_gianos,
        t.ifkcrsi_esito_fircosoft as cd_esito_fircosoft,
        t.ifkcrsi_cd_valutaz_prt as cd_valutaz_prt,
        t.ifkcrsi_apag_con_sospens as fl_apag_con_sospens,
        t.ifkcrsi_scipafi_obbl as fl_scipafi_obbl,
        t.ifkcrsi_livello_firma_prt as cd_livello_firma_prt,
        t.ifkcrsi_area_rischio as cd_area_rischio,
        t.ifkcrsi_vendita_congiunta as fl_tipo_vendita_congiunta,
        {{ custom_to_decimal('t.ifkcrsi_fido_massimo', 13, 2) }} as eu_fido_massimo,
        t.ifkcrsi_motivo_esito as cd_motivo_esito,
        t.ifkcrsi_fascia_rbp as cd_fascia_rbp,
        lr.ifkcrsi_fascia_rbp as cd_fascia_rbp_light,
        t.ifkcrsi_cd_tab_finanz_irr as cd_tab_finanz_irr,
        {{ custom_to_decimal('t.ifkcrsi_fido_score', 13, 2) }} as eu_fido_score,
        t.ifkcrsi_utente as cd_utente,
        to_timestamp(
            lpad(t.ifkcrsi_data::varchar, 8, '0') || lpad(t.ifkcrsi_ora::varchar, 6, '0'),
            'YYYYMMDDHH24MISSFF2'
        ) as ts_risposta
    from perim_ifkcfrsi as t
    left join {{ ref('crcar') }} as cr
        on t.ifkcrsi_cd_pratica = cr.crcar_key_n
       and t.ifkcrsi_procedura_ocs = 'CA'
    left join crcarblo_rt as rt
        on cr.crcar_key_n = rt.cab_pratica
    left join {{ ref('cccretmo') }} as cm
        on cr.crcar_override = cm.cremo_motivo
    left join light_ranked as lr
        on t.ifkcrsi_richiesta = lr.ifkcrsi_richiesta
       and lr.ordinamento_chiamate_prat = 1
    where t.ifkcrsi_procedura_ocs = 'CA'
),

cqs as (
    select
        'CQ' as tp_procedura,
        q.qpr_num_pratica as cd_pratica,
        q.qpr_stato as cd_stato_prat,
        q.qpr_attributo as cd_attributo_prat,
        null as cd_blocco_prat,
        q.qpr_esito_approvazione as cd_esito_prat,
        -- FIX: data model aveva un COALESCE annidato senza chiusura di parentesi: "COALESCE(COALESCE(...)"
        coalesce(q.qpr_data_perfezionamento, s35.dt_respinta, srt.dt_ritirata) as dt_esito_prat,
        q.qpr_autore_overr as cd_user_esito_finale,
        q.qpr_motivo_overr as cd_motivo_override,
        cm.cremo_tipo_override as tp_override,
        null as cd_esito_elab_cde,
        null as ds_esito_elab_cde,
        null as cd_esito_chiamata,
        null as cd_esito_codice,
        null as ds_esito_messaggio,
        null as cd_operazione,
        null as nm_richiesta,
        null as nm_id_guid_cf,
        null as cd_esito_amlcheck,
        null as ds_esito_amlcheck,
        null as fl_prt_car_ora_serv,
        null as cd_esito_antifraud,
        null as ds_esito_antifraud,
        null as cd_esito_gianos,
        null as cd_esito_fircosoft,
        null as cd_valutaz_prt,
        null as fl_apag_con_sospens,
        null as fl_scipafi_obbl,
        null as cd_livello_firma_prt,
        null as cd_area_rischio,
        null as fl_tipo_vendita_congiunta,
        null as eu_fido_massimo,
        null as cd_motivo_esito,
        null as cd_fascia_rbp,
        null as cd_fascia_rbp_light,
        null as cd_tab_finanz_irr,
        null as eu_fido_score,
        null as cd_utente,
        null as ts_risposta
    from {{ ref('qspra') }} as q
    left join qsprast_35 as s35
        on q.qpr_num_pratica = s35.qprst_num_pratica
    left join qsprast_rt as srt
        on q.qpr_num_pratica = srt.qprst_num_pratica
    left join {{ ref('cccretmo') }} as cm
        on q.qpr_motivo_overr = cm.cremo_motivo
),

unioned as (
    select * from consumo
    union all
    select * from carte
    union all
    select * from cqs
)

select
    u.tp_procedura,
    u.cd_pratica,
    u.cd_stato_prat,
    u.cd_attributo_prat,
    u.cd_blocco_prat,
    u.cd_esito_prat,
    {{ ole_to_date('u.dt_esito_prat') }} as dt_esito_prat,
    u.cd_user_esito_finale,
    u.cd_motivo_override,
    u.tp_override,
    u.cd_esito_elab_cde,
    u.ds_esito_elab_cde,
    u.cd_esito_chiamata,
    u.cd_esito_codice,
    u.ds_esito_messaggio,
    u.cd_operazione,
    u.nm_richiesta,
    u.nm_id_guid_cf,
    u.cd_esito_amlcheck,
    u.ds_esito_amlcheck,
    u.fl_prt_car_ora_serv,
    u.cd_esito_antifraud,
    u.ds_esito_antifraud,
    u.cd_esito_gianos,
    u.cd_esito_fircosoft,
    u.cd_valutaz_prt,
    u.fl_apag_con_sospens,
    u.fl_scipafi_obbl,
    u.cd_livello_firma_prt,
    u.cd_area_rischio,
    u.fl_tipo_vendita_congiunta,
    u.eu_fido_massimo,
    u.cd_motivo_esito,
    u.cd_fascia_rbp,
    u.cd_fascia_rbp_light,
    u.cd_tab_finanz_irr,
    u.eu_fido_score,
    u.cd_utente,
    u.ts_risposta,
    sda.cd_score_modulo_1_objcode,
    sda.nm_score_modulo_1_aligned,
    sda.cd_score_modulo_2_objcode,
    sda.nm_score_modulo_2_aligned,
    sda.cd_score_modulo_3_objcode,
    sda.nm_score_modulo_3_aligned,
    sda.cd_score_modulo_8_objcode,
    sda.nm_score_modulo_8_aligned,
    sda.cd_score_modulo_9_objcode,
    sda.nm_score_modulo_9_aligned,
    st.cd_segmentazione,
    aia.nm_eurisc_cbscore_cli,
    aia.nm_eurisc_cbscore_coo,
    aia.nm_eurisc_nohit_punteggio_cli,
    aia.nm_eurisc_nohit_punteggio_coo,
    aia.tp_eurisc_fascia_score_cli,
    aia.tp_eurisc_fascia_score_coo,
    aia.nm_ctcpos_score_completo_cli,
    aia.nm_ctcpos_score_completo_coo,
    aia.tp_ctcpos_score_completo_fascia_cli,
    aia.tp_ctcpos_score_completo_fascia_coo,
    aia.fl_ctcpos_hit_nohit_cli,
    aia.fl_ctcpos_hit_nohit_coo,
    aia.fl_eurisc_hit_nohit_cli,
    aia.fl_eurisc_hit_nohit_coo,
    aia.nm_ob_score_cli,
    aia.fl_ob_esenzione_reddito_cli,
    aia.cd_ob_stato_cli,
    aia.cd_ctcpos_stato_cli,
    aia.cd_ctcpos_stato_coo,
    aia.cd_eurisc_crif_stato_cli,
    aia.cd_eurisc_crif_stato_coo,
    aia.pc_dbr_perc_indebitamento_pratica,
    aia.cd_inquirycode_out as cd_inquirycode,
    aia.cd_processcode,
    aia.cd_indicatore_prequalifica_cli,
    aia.cd_indicatore_prequalifica_coo,
    aia.cd_news_banco_cli,
    aia.cd_news_banco_coo,
    aia.cd_segmento_personal_cli,
    aia.cd_segmento_personal_coo,
    aova.nm_regole_ko,
    aova.ds_regole_ko,
    aova.nm_regole_nc,
    aova.ds_regole_nc,
    case when aova.nm_regole_ko > 0 then 'KO' else 'OK' end as fl_esito_policy,
    aova.nm_livello_firma_max_ko,
    aova.nm_regole_overrride,
    aova.ds_regole_override,
    aova.ds_regola_180_messaggio,
    aova.ds_regola_180_descrizione_rules,
    aova.ds_regola_179_messaggio,
    aova.ds_regola_179_descrizione_rules,
    aova.ds_regola_194_messaggio,
    aova.ds_regola_194_descrizione_rules,
    aova.ds_regola_43_descrizione_rules,
    aoa.tp_scipafi_cli,
    aoa.tp_scipafi_coo,
    pol.cd_esito_prescreening,
    pol.ds_esito_prescreening,
    ppa.nm_policy_prescreening_ko_cli
from unioned as u
left join scoring_dettaglio_agg as sda
    on u.nm_richiesta = try_cast(sda.cd_inquirycode as number)
left join scoring_testata as st
    on u.nm_richiesta = try_cast(st.cd_inquirycode as number)
left join accettazione_input_agg as aia
    on u.nm_richiesta = try_cast(aia.cd_inquirycode as number)
left join accettazione_output_agg as aoa
    on u.nm_richiesta = try_cast(aoa.cd_inquirycode as number)
left join accettazione_output_pr_ov_agg as aova
    on u.nm_richiesta = try_cast(aova.cd_inquirycode as number)
left join prescreening_output_lkp as pol
    on u.nm_richiesta = try_cast(pol.cd_inquirycode as number)
left join prescreening_pr_agg as ppa
    on u.nm_richiesta = try_cast(ppa.cd_inquirycode as number)
