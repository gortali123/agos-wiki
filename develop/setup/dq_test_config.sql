create table if not exists {{ env_var('DBT_DATABASE') }}.TECH.CFG_DQ_TEST_CONFIG (
    DS_MODELLO   varchar,     -- nome modello dbt, es. 'L2_ANAGR_CONTROPARTE'
    DS_COLONNA   varchar,     -- null per test a livello tabella
    DS_TEST_TYPE varchar,     -- nome del generic test custom, es. 'is_valid_email'
    GN_PARAMS    variant,     -- parametri specifici del test type, in json
    DS_SEVERITY  varchar,     -- 'warn' | 'error' (letterale dbt config.severity)
    FL_ACTIVE    varchar(1) default 'Y'
);

insert into {{ env_var('DBT_DATABASE') }}.TECH.CFG_DQ_TEST_CONFIG
    (DS_MODELLO, DS_COLONNA, DS_TEST_TYPE, GN_PARAMS, DS_SEVERITY, FL_ACTIVE)
values ('L2_ANAGR_CONTROPARTE', 'DS_EMAIL', 'is_valid_email', null, 'warn', 'Y');
