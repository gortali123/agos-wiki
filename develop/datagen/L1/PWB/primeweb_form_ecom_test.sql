-- WARN: schema dedotto dal tracciato L2 fornito dall'utente (colonne con sorgente PRIMEWEB_PP),
-- non dal modello L2 reale ne' da un modello L1 vendorizzato in raw/dwh-code/.
-- Nome colonna = campo sorgente (non il nome target L2). Escluse le colonne senza
-- sorgente PRIMEWEB_PP: TP_FORM, TS_INIZIO_VALIDITA, TS_FINE_VALIDITA, TP_PROCEDURA,
-- DS_ESITO_FORM, CD_MERCHANT, DS_PRODOTTO_FINANZIATO (valori fissi/campi ETL/non presenti per PP).

CREATE OR REPLACE TABLE AGOS_DEV_16000.L1_E_PWB.PRIMEWEB_FORM_ECOM_TEST (
    FORMREQUESTID     VARCHAR(100),   -- CD_FORM, chiave primaria del form PP
    SESSION_UID       VARCHAR(100),   -- CD_SESSIONE
    CD_PRATICA        NUMBER(16,0),
    BROKERCODE        VARCHAR(20),    -- CD_BROKER
    SUBSIDIARYCODE    VARCHAR(10),    -- CD_FILIALE
    FORMREQUESTSTATE  VARCHAR(20),    -- TP_STATO_FORM
    CREATIONDATE      TIMESTAMP_NTZ,  -- TS_CREAZIONE
    IPADDRESS         VARCHAR(50),    -- CD_IP_ADDRESS
    MOBILE            VARCHAR(1),     -- FL_MOBILE
    IM_IMFIN          NUMBER(15,2),   -- EU_IMPORTO_FINANZIATO
    NM_NMRATE         NUMBER(5,0),    -- NM_RATE
    FL_DATI_MARK      VARCHAR(1),     -- FL_CONSENSO_MARKETING
    FL_DATI_PERS      VARCHAR(1),     -- FL_CONSENSO_DATI_PERS
    DIGITALSIGN       BOOLEAN,        -- FL_FIRMA_DIGITALE, booleano lato sorgente -> S/N solo in L2
    CAMPAIGNID        VARCHAR(50),    -- CD_CAMPAGNA, presente solo per PP
    CD_CDTPPAGCLI     VARCHAR(2),     -- CD_TIPO_PAGAMENTO
    IBAN              VARCHAR(45)     -- CD_IBAN
);

INSERT INTO AGOS_DEV_16000.L1_E_PWB.PRIMEWEB_FORM_ECOM_TEST (
    FORMREQUESTID, SESSION_UID, CD_PRATICA, BROKERCODE, SUBSIDIARYCODE,
    FORMREQUESTSTATE, CREATIONDATE, IPADDRESS, MOBILE, IM_IMFIN, NM_NMRATE,
    FL_DATI_MARK, FL_DATI_PERS, DIGITALSIGN, CAMPAIGNID, CD_CDTPPAGCLI, IBAN
)
VALUES
-- caso business normale 1: form completo, consensi dati, firma digitale attiva
('FRQ0000001', 'SESSPP-0001-AAAA', 1000123456, 'BRK001', 'SUB01',
 'COMPLETED', '2026-07-01 09:15:00', '82.10.24.101', 'S', 15000.50, 24,
 'S', 'S', TRUE, 'CMP-ESTATE26', '01', 'IT60X0542811101000000123456'),

-- caso business normale 2: form in corso, no marketing, firma non ancora data
('FRQ0000002', 'SESSPP-0002-BBBB', 1000123457, 'BRK002', 'SUB02',
 'PENDING', '2026-07-02 14:42:11', '93.45.12.7', 'N', 8200.00, 12,
 'N', 'S', FALSE, 'CMP-ESTATE26', '02', 'IT28W8000000292100645211151'),

-- caso limite: NM_RATE e IM_IMFIN a 0 (piano/rata non ancora impostati, non placeholder OCS: fonte web, 0 legittimo)
('FRQ0000003', 'SESSPP-0003-CCCC', 1000123458, 'BRK001', 'SUB01',
 'DRAFT', '2026-07-03 08:00:00', '151.20.33.44', 'N', 0.00, 0,
 'N', 'N', FALSE, NULL, '01', NULL),

-- caso NULL: campi facoltativi non valorizzati (sorgente web, NULL legittimo, non placeholder OCS)
('FRQ0000004', 'SESSPP-0004-DDDD', 1000123459, NULL, 'SUB03',
 'REJECTED', '2026-07-04 19:30:45', NULL, NULL, NULL, NULL,
 NULL, NULL, NULL, NULL, NULL, NULL),

-- caso limite: FL_MOBILE valorizzato ma consensi entrambi negativi, IBAN estero (non IT)
('FRQ0000005', 'SESSPP-0005-EEEE', 1000123460, 'BRK003', 'SUB01',
 'COMPLETED', '2026-07-05 11:05:59', '213.45.67.89', 'S', 22750.75, 36,
 'N', 'N', TRUE, 'CMP-BLACKFRIDAY', '03', 'FR7630006000011234567890189'),

-- caso limite: importo/rate alti, campagna assente ma tipo pagamento e IBAN presenti
('FRQ0000006', 'SESSPP-0006-FFFF', 1000123461, 'BRK002', 'SUB02',
 'COMPLETED', '2026-07-06 16:20:00', '109.112.5.60', 'S', 48999.99, 60,
 'S', 'N', TRUE, NULL, '02', 'IT02R0300203280005050000123');
