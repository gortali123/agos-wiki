{% macro create_proc_report_masterscale() %}

{% set create_proc %}

CREATE OR REPLACE PROCEDURE {{ env_var('DBT_DATABASE') }}.L3_BASILEA.PR_GENERATE_REPORT_FONDI_MASTERSCALE(
    anno_mese_rif  VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.13'
PACKAGES = ('snowflake-snowpark-python', 'openpyxl', 'pandas')
HANDLER = 'main'
AS
$$
import io
import os
import calendar
from datetime import datetime

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import snowflake.snowpark as snowpark

MESI = {
    1: "Gennaio", 2: "Febbraio", 3: "Marzo", 4: "Aprile",
    5: "Maggio", 6: "Giugno", 7: "Luglio", 8: "Agosto",
    9: "Settembre", 10: "Ottobre", 11: "Novembre", 12: "Dicembre"
}

def build_sheet(wb: openpyxl.Workbook, df, sheet_name: str) -> None:

    # var performing/default
    P_TITLE_FONT  = Font(name='Arial', bold=False, size=10, color='0000FF')
    P_HEADER_FONT = Font(name='Arial', bold=True, color='000000', size=10)
    P_HEADER_FILL = PatternFill('solid', start_color='FFFFFF')
    P_TOT_FILL    = PatternFill('solid', start_color='A8A8FF') 
    P_BODY_FONT   = Font(name='Calibri', size=11)
    P_THIN        = Side(style='thin', color='000000')
    P_BORDER      = Border(left=P_THIN, right=P_THIN, top=P_THIN, bottom=P_THIN)
    
    P_TITLE_ROW  = 1
    P_EMPTY_ROW  = 2
    P_HEADER_ROW = 3
    P_DATA_START = 4

    ws = wb.create_sheet(title=sheet_name)
    ws.sheet_view.showGridLines = False

    n_cols          = len(df.columns)
    n_rows          = len(df)
    last_col_letter = get_column_letter(n_cols)

    # Riga 1  titolo
    ws.merge_cells(f'A{P_TITLE_ROW}:{last_col_letter}{P_TITLE_ROW}')
    tc           = ws[f'A{P_TITLE_ROW}']
    tc.value = f'Detail for {sheet_name} Contracts by SME, SRT, PD, LGD, CCF and SEGMENT'
    tc.font      = P_TITLE_FONT
    tc.alignment = Alignment(horizontal='center', vertical='bottom')
    ws.row_dimensions[P_TITLE_ROW].height = 12

    # Riga 2  vuota
    ws.row_dimensions[P_EMPTY_ROW].height = 10

    # Riga 3  header
    for c, col in enumerate(df.columns, 1):
        cell           = ws.cell(row=P_HEADER_ROW, column=c, value=str(col))
        cell.font      = P_HEADER_FONT
        cell.fill      = P_HEADER_FILL
        cell.alignment = Alignment(horizontal='center', vertical='bottom', wrap_text=True)
        cell.border    = P_BORDER
    ws.row_dimensions[P_HEADER_ROW].height = 90

    # Righe 4+  dati
    for r, row in enumerate(df.itertuples(index=False), P_DATA_START):
        is_last = (r == n_rows + P_DATA_START - 1)
        for c, val in enumerate(row, 1):
            cell           = ws.cell(row=r, column=c, value=val)
            cell.font      = P_BODY_FONT
            cell.alignment = Alignment(horizontal='left', vertical='bottom')
            cell.border    = P_BORDER

            if is_last:
                cell.fill = P_TOT_FILL
            
            else:
                cell.fill = P_HEADER_FILL

            if c in df.columns.get_indexer(["SME", "SRT","SEGMENT"])+1:  
                cell.alignment = Alignment(horizontal='left', vertical='bottom')

            elif c in df.columns.get_indexer(["PD CLASS", "LGD CLASS","CCF CLASS"])+1:
                cell.alignment = Alignment(horizontal='right', vertical='bottom')

            elif c in df.columns.get_indexer(["PD", "LGD", "CCF", "ELBE"])+1:
                cell.alignment = Alignment(horizontal='right', vertical='bottom')
                cell.number_format = '0.00000%'

            elif c in df.columns.get_indexer(["Number of receivables", "Outstanding on balance sheet","Available amounts not used at the end of the month", "EAD", "EL", "RWA", "Capital Requirement" ])+1:
                cell.alignment = Alignment(horizontal='right', vertical='bottom')
                cell.number_format = '#,##0'

            else:
                cell.alignment = Alignment(horizontal='right', vertical='bottom')
                cell.number_format = '0.00000'

    for c, col in enumerate(df.columns, 1):
         ws.column_dimensions[get_column_letter(c)].width = 22
        

    # Freeze prime 3 righe, filtro
    ws.freeze_panes = f'A{P_DATA_START}'

def build_sheet_KPI(wb: openpyxl.Workbook, df1, df2, sheet_name: str) -> None:

    # var kpi
    KPI_TITLE_FONT    = Font(name='Arial', bold=False, size=10, color='0000FF')
    KPI_SUBTITLE_FONT = Font(name='Arial', bold=False, size=10, color='000000')
    KPI_HEADER_FONT   = Font(name='Arial', bold=True, color='000000', size=10)
    KPI_HEADER_FILL   = PatternFill('solid', start_color='FFFFFF')                 
    KPI_BODY_FONT     = Font(name='Calibri', size=11, color='000000')               
    KPI_THIN        = Side(style='thin', color='000000')
    KPI_BORDER      = Border(left=KPI_THIN, right=KPI_THIN, top=KPI_THIN, bottom=KPI_THIN)
    
    
    KPI_TITLE_ROW      = 1
    KPI_SUBTITLE_ROW   = 2
    KPI_EMPTY_1        = 3
    KPI_SUBTITLE_ROW_2 = 4
    KPI_EMPTY_2        = 5
    KPI_HEADER_ROW     = 6
    KPI_DATA_START     = 7

    ws = wb.create_sheet(title=sheet_name[:31])
    ws.sheet_view.showGridLines = False

    n_cols          = max(len(df1.columns), len(df2.columns))
    last_col_letter = get_column_letter(n_cols)

    ws.merge_cells(f'A{KPI_TITLE_ROW}:{last_col_letter}{KPI_TITLE_ROW}')
    tc           = ws[f'A{KPI_TITLE_ROW}']
    tc.value     = "Basel II compte rendu risque CRR V2 - P6 FONDI -  MasterScale"
    tc.font      = KPI_TITLE_FONT
    tc.alignment = Alignment(horizontal='center', vertical='bottom')
    ws.row_dimensions[KPI_TITLE_ROW].height = 24

    ws.merge_cells(f'A{KPI_SUBTITLE_ROW}:{last_col_letter}{KPI_SUBTITLE_ROW}')
    sc           = ws[f'A{KPI_SUBTITLE_ROW}']
    sc.value     = f'Dati aggiornati a {mese_riferimento} {anno_riferimento} Elaborato il {datetime.today().strftime("%d/%m/%Y")}'
    sc.font      = KPI_SUBTITLE_FONT
    sc.alignment = Alignment(horizontal='center', vertical='bottom')
    ws.row_dimensions[KPI_SUBTITLE_ROW].height = 12

    ws.row_dimensions[KPI_EMPTY_1].height = 10

    ws.merge_cells(f'A{KPI_SUBTITLE_ROW_2}:{last_col_letter}{KPI_SUBTITLE_ROW_2}')
    sc           = ws[f'A{KPI_SUBTITLE_ROW_2}']
    sc.value     = 'AGOS SPA'
    sc.font      = KPI_SUBTITLE_FONT
    sc.alignment = Alignment(horizontal='center', vertical='bottom')
    ws.row_dimensions[KPI_SUBTITLE_ROW_2].height = 12

    ws.row_dimensions[KPI_EMPTY_2].height = 10

    for c, col_name in enumerate(df1.columns, 1):
        cell           = ws.cell(row=KPI_HEADER_ROW, column=c, value=str(col_name))
        cell.font      = KPI_HEADER_FONT
        cell.fill      = KPI_HEADER_FILL
        cell.alignment = Alignment(horizontal='center', vertical='bottom', wrap_text=True)
        cell.border    = KPI_BORDER
    ws.row_dimensions[KPI_HEADER_ROW].height = 20  

    for r, row in enumerate(df1.itertuples(index=False), KPI_DATA_START):
        for c, val in enumerate(row, 1):
            cell           = ws.cell(row=r, column=c, value=val)
            cell.font      = KPI_BODY_FONT
            cell.border    = KPI_BORDER
            if c == 3:
                cell.number_format = '0.00"%"'
                cell.alignment = Alignment(horizontal='right', vertical='bottom')
            elif c == 4:
                cell.number_format = '0.00"%"'
                cell.alignment = Alignment(horizontal='right', vertical='bottom')
            else:
                cell.alignment = Alignment(horizontal='left', vertical='bottom')
        ws.row_dimensions[r].height = 18

    s2_empty_3      = KPI_DATA_START + len(df1)
    s2_header_row_2 = s2_empty_3 + 1
    s2_data_start_2 = s2_header_row_2 + 1

    ws.row_dimensions[s2_empty_3].height = 10

    for c, col_name in enumerate(df2.columns, 1):
        cell           = ws.cell(row=s2_header_row_2, column=c, value=str(col_name))
        cell.font      = KPI_HEADER_FONT
        cell.fill      = KPI_HEADER_FILL
        cell.alignment = Alignment(horizontal='center', vertical='bottom')
        cell.border    = KPI_BORDER
    ws.row_dimensions[s2_header_row_2].height = 18  

    for r, row in enumerate(df2.itertuples(index=False), s2_data_start_2):
        for c, val in enumerate(row, 1):
            cell           = ws.cell(row=r, column=c, value=val)
            cell.font      = KPI_BODY_FONT
            cell.border    = KPI_BORDER
            cell.alignment = Alignment(horizontal='left', vertical='bottom')
            cell.number_format = '#,##0'
        ws.row_dimensions[r].height = 18

    for c in range(1, n_cols + 1):
        has_data = False
        if c <= len(df1.columns):
            has_data = df1.iloc[:, c - 1].notna().any()
        if not has_data and c <= len(df2.columns):
            has_data = df2.iloc[:, c - 1].notna().any()
    
        ws.column_dimensions[get_column_letter(c)].width = 24 if has_data else 8


def main(session: snowpark.Session, anno_mese_rif:  str) -> str:    

    data = datetime.strptime(anno_mese_rif, "%Y%m")
    ultimo_giorno = calendar.monthrange(data.year, data.month)[1]
    fine_mese_rif = f"""{data.year}-{data.month:02d}-{ultimo_giorno:02d}"""

    global mese_riferimento, anno_riferimento
    mese_riferimento = MESI.get(data.month)
    anno_riferimento = data.year
   
    query_performing = f"""
    WITH 
    PERIMETRO AS (
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            FL_SRT,   
            TP_LGD_CLASSE_RISC,
            null as TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            null as PC_CCF,
            null as PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            null as EU_DISPONIBILE_NOUTI,
            EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE        
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CO_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}' AND FL_DEFAULT = 'N'
        UNION ALL
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            null as FL_SRT,
            TP_LGD_CLASSE_RISC,
            TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            PC_CCF,
            PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            EU_DISPONIBILE_NOUTI,
            EU_EAD_STIMATA_FLOOR as EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL as EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA as EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB as EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CA_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}' AND FL_DEFAULT = 'N'
    )
    ,AGGREGAZIONE AS (
        SELECT 
            NVL(FL_SME, 'TOTALE') AS SME
            ,TP_CLASSE_RISCHIO AS "PD CLASS"
            ,FL_SRT AS "Y"
            ,TP_LGD_CLASSE_RISC AS "LGD CLASS"
            ,TP_CCF_CLASSE_RISC AS "CCF CLASS"
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE AVG(NVL(PC_PD_SCORE_FLOOR, 0)/100)
            END AS PD
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE AVG(PC_LGD_SCORE_FLOOR/100) 
            END AS LGD
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE AVG(GREATEST(NVL(PC_CCF,0), NVL(PC_K,0), 0)/100)
            END AS CCF
            ,TP_PD_TYPE AS "SEGMENT"
            ,COUNT(CD_PRATICA) AS "Number of receivables"
            ,ROUND(SUM(NVL(EU_IMPIEGHI,0))) AS "Outstanding on balance sheet"
            ,ROUND(SUM(GREATEST(NVL(EU_DISPONIBILE_NOUTI, 0), 0))) AS "Available amounts not used at the end of the month"
            ,ROUND(SUM(NVL(IFF(TP_CO_RE = 1,EU_EAD_FLOOR_GROSS_SRT, EU_EAD_STIMATA_FLOOR),0))) AS EAD
            ,ROUND(SUM(NVL(IFF(TP_CO_RE = 1,EU_EL_GROSS_SRT,EU_EL),0))) AS EL
            ,ROUND(SUM(NVL(IFF(TP_CO_RE = 1,EU_RWA_GROSS_SRT,EU_RWA),0))) AS RWA
            ,ROUND(SUM(NVL(IFF(TP_CO_RE = 1,EU_PV_IRB_GROSS_SRT,EU_PV_IRB),0))) AS "Capital Requirement"
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE ROUND(AVG(NVL(EU_CAPITAL_REQUIREMENT,0)),7) 
            END AS K
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE ROUND(AVG(NVL(EU_CORRELATION,0)),7)
            END AS R
        FROM PERIMETRO
        GROUP BY GROUPING SETS ((TP_CO_RE,FL_SME, TP_CLASSE_RISCHIO, FL_SRT, TP_LGD_CLASSE_RISC, TP_CCF_CLASSE_RISC, TP_PD_TYPE), NULL)
        ORDER BY TP_CO_RE DESC NULLS LAST, TP_CLASSE_RISCHIO, TP_LGD_CLASSE_RISC, TP_CCF_CLASSE_RISC, TP_PD_TYPE, FL_SRT, FL_SME
    )
    SELECT * FROM AGGREGAZIONE
    """
    
    query_default = f"""
    WITH 
    PERIMETRO AS (
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            FL_SRT,
            TP_LGD_CLASSE_RISC,
            null as TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            null as PC_CCF,
            null as PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            null as EU_DISPONIBILE_NOUTI,
            EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE        
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CO_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}' AND FL_DEFAULT = 'S'
        UNION ALL
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            null as FL_SRT,
            TP_LGD_CLASSE_RISC,
            TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            PC_CCF,
            PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            EU_DISPONIBILE_NOUTI,
            EU_EAD_STIMATA_FLOOR as EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL as EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA as EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB as EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CA_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}' AND FL_DEFAULT = 'S'
    )
    ,AGGREGAZIONE AS (
        SELECT 
            NVL(FL_SME, 'TOTALE') AS SME
            ,FL_SRT AS "Y"
            ,TP_CLASSE_RISCHIO AS "PD CLASS"
            ,TP_LGD_CLASSE_RISC AS "LGD CLASS"
            ,TP_CCF_CLASSE_RISC AS "CCF CLASS"    
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE AVG(NVL(PC_PD_SCORE_FLOOR, 0)/100) 
            END AS PD        
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE AVG(PC_LGD_SCORE_FLOOR/100) 
            END AS LGD
            ,CASE 
                WHEN FL_SME IS NULL THEN NULL 
                ELSE AVG(NVL(PC_ELBE_SCORE,0)/100)
            END AS ELBE
            ,TP_PD_TYPE AS "SEGMENT"
            ,COUNT(CD_PRATICA) AS "Number of receivables"
            ,ROUND(SUM(NVL(EU_IMPIEGHI,0))) AS "Outstanding on balance sheet"
            ,ROUND(SUM(GREATEST(NVL(EU_DISPONIBILE_NOUTI, 0), 0))) AS "Available amounts not used at the end of the month"
            ,ROUND(SUM(NVL(EU_EAD_FLOOR_GROSS_SRT,0))) AS EAD
            ,ROUND(SUM(NVL(EU_EL_GROSS_SRT,0))) AS EL
            ,ROUND(SUM(NVL(EU_RWA_GROSS_SRT,0))) AS RWA
            ,ROUND(SUM(NVL(EU_PV_IRB_GROSS_SRT,0))) AS "Capital Requirement"
        FROM PERIMETRO
        GROUP BY GROUPING SETS ((TP_CO_RE, FL_SME, FL_SRT, TP_CLASSE_RISCHIO, TP_LGD_CLASSE_RISC, TP_CCF_CLASSE_RISC, TP_PD_TYPE), NULL)
        ORDER BY TP_CO_RE DESC NULLS LAST,TP_CLASSE_RISCHIO, TP_LGD_CLASSE_RISC, TP_CCF_CLASSE_RISC, TP_PD_TYPE, FL_SRT, FL_SME
    )
    SELECT * FROM AGGREGAZIONE
    """
    
    query_kpi_1 = f"""
    WITH 
    PERIMETRO AS (
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            FL_SRT,
            TP_LGD_CLASSE_RISC,
            null as TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            null as PC_CCF,
            null as PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            null as EU_DISPONIBILE_NOUTI,
            EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE        
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CO_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}'
        UNION ALL
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            null as FL_SRT,
            TP_LGD_CLASSE_RISC,
            TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            PC_CCF,
            PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            EU_DISPONIBILE_NOUTI,
            EU_EAD_STIMATA_FLOOR as EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL as EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA as EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB as EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CA_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}'
    )
    ,AGGREGAZIONE AS (
        SELECT 
            FL_DEFAULT
            ,TP_CO_RE
            ,AVG(NVL(PC_PD_SCORE_FLOOR, 0)/100)*COUNT(CD_PRATICA)*100 AS PD_X_PRAT
            ,CASE 
                WHEN FL_DEFAULT = 'N' THEN AVG(NVL(PC_LGD_SCORE_FLOOR, 0)/100)*COUNT(CD_PRATICA)*100
                WHEN FL_DEFAULT = 'S' THEN AVG(NVL(PC_ELBE_SCORE, 0)/100)*COUNT(CD_PRATICA)*100
            END AS LGD_X_PRAT
            ,COUNT(CD_PRATICA) AS CONTRATTI
        FROM PERIMETRO
        GROUP BY (TP_CO_RE, FL_SME, TP_CLASSE_RISCHIO, FL_SRT, TP_LGD_CLASSE_RISC, TP_CCF_CLASSE_RISC, TP_PD_TYPE, FL_DEFAULT)
    )
    ,KPI AS (
        SELECT 
            CASE
                WHEN FL_DEFAULT = 'N' THEN 'Performing'
                WHEN FL_DEFAULT IS NULL THEN 'Total'
                ELSE 'Default'
            END AS "Group"
            ,CASE
                WHEN TP_CO_RE = 1 THEN 'Fixed Term Loans'
                WHEN TP_CO_RE = 2 THEN 'Revolving'
            END AS "Macro Product"
            ,SUM(PD_X_PRAT)/SUM(CONTRATTI) AS PD
            ,SUM(LGD_X_PRAT)/SUM(CONTRATTI) AS LGD
        FROM AGGREGAZIONE
        GROUP BY GROUPING SETS ((FL_DEFAULT, TP_CO_RE), TP_CO_RE)
        HAVING FL_DEFAULT = 'N' OR FL_DEFAULT IS NULL
        ORDER BY FL_DEFAULT, TP_CO_RE
    )
    SELECT * FROM KPI
    """
    
    query_kpi_2 = f"""
    WITH PERIMETRO AS (
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            FL_SRT,
            TP_LGD_CLASSE_RISC,
            null as TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            null as PC_CCF,
            null as PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            null as EU_DISPONIBILE_NOUTI,
            EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE        
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CO_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}'
        UNION ALL
        SELECT 
            DT_ESTRAZIONE,
            FL_DEFAULT,
            TP_CO_RE,
            FL_SME,
            TP_CLASSE_RISCHIO,
            null as FL_SRT,
            TP_LGD_CLASSE_RISC,
            TP_CCF_CLASSE_RISC,
            PC_PD_SCORE_FLOOR,
            PC_LGD_SCORE_FLOOR,
            PC_CCF,
            PC_K,
            TP_PD_TYPE,
            CD_PRATICA,
            EU_IMPIEGHI,
            EU_DISPONIBILE_NOUTI,
            EU_EAD_STIMATA_FLOOR as EU_EAD_FLOOR_GROSS_SRT,
            EU_EAD_STIMATA_FLOOR,
            EU_EL as EU_EL_GROSS_SRT,
            EU_EL,
            EU_RWA as EU_RWA_GROSS_SRT,
            EU_RWA,
            EU_PV_IRB as EU_PV_IRB_GROSS_SRT,
            EU_PV_IRB,
            EU_CAPITAL_REQUIREMENT,
            EU_CORRELATION,
            PC_ELBE_SCORE
        FROM {{ env_var('DBT_DATABASE') }}.L3_BASILEA.DM_BASILEA_CA_VAR_PV_K_M
        WHERE DT_ESTRAZIONE = DATE'{fine_mese_rif}'
    )
    SELECT 
        ROUND(SUM(EU_RWA))                AS RWA
        ,ROUND(SUM(EU_EL))                AS EL
        ,ROUND(SUM(EU_EAD_STIMATA_FLOOR)) AS EAD
    FROM PERIMETRO
    """

    # 1. Esegui le due query
    df_p = session.sql(query_performing).to_pandas()
    df_d = session.sql(query_default).to_pandas()
    df_kpi_1    = session.sql(query_kpi_1).to_pandas()
    df_kpi_2 = session.sql(query_kpi_2).to_pandas()

   # Controlla che il mese di riferimento sia presente nei Datamarts
    if df_p.empty or df_d.empty:
        raise ValueError(f"Nessun dato per il mese di riferimento: {anno_mese_rif}")

    # 2. Costruisci il workbook con i due sheet
    wb = openpyxl.Workbook()
    wb.remove(wb.active)   

    
    build_sheet_KPI(wb, df_kpi_1, df_kpi_2, 'KPI')
    build_sheet(wb, df_p, 'Performing')
    build_sheet(wb, df_d, 'Default')

    file_prefix = f'Fondi_MasterScale'  

    # 3. Salva su /tmp e carica sullo stage S3
    stage_path = '@{{ env_var('DBT_DATABASE') }}.L0.STG_OUTPUT_DEV/BASILEA/FONDI_MASTERSCALE'
    file_name = f'{file_prefix}_{anno_mese_rif}.xls'
    tmp_path  = f'/tmp/{file_name}'

    buf = io.BytesIO()
    wb.save(buf)
    with open(tmp_path, 'wb') as f:
        f.write(buf.getvalue())

    dest = stage_path.rstrip('/') + '/'
    session.file.put(tmp_path, dest, auto_compress=False, overwrite=True)
    os.remove(tmp_path)


    return (
        f'OK - {dest}{file_name}' 
    )

$$
;


{% endset %}

{% do run_query(create_proc) %}

{% endmacro %}