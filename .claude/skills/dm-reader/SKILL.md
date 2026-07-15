---
name: dm-reader
description: Legge i data model Excel Agos L2 e L3 e li espone in forma strutturata. Usare quando l'utente chiede di consultare un data model, oppure come base per le skill develop-l2/develop-l3 quando devono generare SQL/YML dbt.
---

# DM READER

Legge i data model Excel Agos (L2 e L3) e li espone in forma strutturata. E'
la fonte autoritativa per: comandi di lettura, formato dell'output e
struttura dell'Excel. Le skill `develop-l2` e `develop-l3` si appoggiano a
questa.

## Input: dove trovare l'Excel

Lo script auto-rileva l'Excel piu' recente in `raw/` (ricorsivo, relativo alla
working directory da cui viene lanciato). Se in `raw/` convivono piu' data
model (es. L2 e L3), vince il piu' recente per data di modifica: per
lavorare su uno specifico, passa `--file "raw/nome-file.xlsx"`.

Nessun file trovato in `raw/` -> fermati e chiedi all'utente di aggiungerlo
li'. Non inventare contenuti del data model.

Niente cache: l'Excel viene letto direttamente a ogni esecuzione.

## Comandi

Lo script e' `scripts/dm.py`, accanto a questa SKILL.md. Non scrive nulla:
eseguilo in place con path assoluto, senza copiarlo. Servono `pandas` e
`openpyxl`; se non sono installati nell'interprete di default, usa `uv run`:

```bash
# Lista fogli disponibili (utile per il nome esatto dell'entita'/DataMart)
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py sheets

# Catalogo: tutto, per subject area / sotto-processo, o singola entita'/DM
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py catalog
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py catalog SUBJECT_AREA
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py catalog SUBJECT_AREA ENTITA

# Foglio entita'/DataMart: campi, PK, tipi, TAB/COL/RT/CHIAVI per procedura
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py sheet NOME_ENTITA
# scorciatoia: il primo argomento non-sottocomando equivale a 'sheet'
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py NOME_ENTITA

# Forzare un file specifico invece dell'auto-detect (qualunque sottocomando)
uv run --with pandas --with openpyxl python .claude/skills/dm-reader/scripts/dm.py sheet NOME_ENTITA --file "raw/Agos X - Layer L3 - DataMart.xlsx"
```

(Se `python3`/`pandas` sono gia' disponibili nell'ambiente, si puo' invocare
direttamente `python3 .claude/skills/dm-reader/scripts/dm.py ...` senza `uv
run`.)

Il formato del catalogo (L2 vs L3) e' auto-rilevato dall'header del foglio
`Catalogo Entità`: `Nome Entità` -> L2, `Nome DataMart` -> L3. Per il filtro
catalogo L3, il primo argomento matcha l'`ID_SOTTO_PROCESSO` (es. `BASILEA`)
e il secondo il nome esatto del DataMart; per filtrare solo per nome usa un
primo argomento qualsiasi (es. `X NOME_DM`).

## Formato output (contratto)

**catalog L2** — una riga per entita':
```
NOME_ENTITA | SUBJECT_AREA | S1/S2/S3/S4 | SORGENTI: tab:cluster, ... | DIP: -
```
Storicizzazione: S1–S4 (oppure WIP/N/A se non definita).
SORGENTI: coppie tabella_L1:cluster (es. `OXTRFTRU:A2`, `OXTRFPTR:C`).
DIP: dipendenza da altre entita' L2 (- se nessuna).

**catalog L3** — una riga per DataMart:
```
NOME_DM | DM_ID | SOTTO_PROCESSO | MAIN: ... | L1: tab, ... | L2: ent, ... | FREQ: ... | PROFONDITA: ... | PERIMETRO: <SQL perimetro su una riga>
```
MAIN: entita' main del DataMart. L1 / L2: sorgenti in input per layer (- se
nessuna). FREQ: frequenza update (es. Mensile); PROFONDITA: profondita'
storica. PERIMETRO: la Regola Tecnica Perimetro normalizzata su una riga.

**sheet** (L2 e L3) — intestazione `=== NOME | P=n (proc1, ...) ===`, poi una
riga per campo per procedura:
```
CAMPO | PK | TIPO | PROC | TAB | COL | RT | CHIAVI
```
- TAB/COL possono elencare piu' sorgenti con prefisso layer, separate da ` ; `
  (es. `[L1] IFBLFPVKCO ; [L2] MANUAL_ADJUSTMENT_O`). Una COL senza prefisso
  che coincide col nome di un altro CAMPO del DM e' una dipendenza da campo
  calcolato, non una colonna sorgente.
- RT = regola tecnica (query standalone da integrare nel modello).
- CHIAVI = chiavi di aggancio: snippet FROM/JOIN che dice come agganciare le
  sorgenti non-main (soprattutto in L3). Usale come specifica dei JOIN.

Campi vuoti resi come `-`. Un campo presente in 2 procedure -> 2 righe con
stesso CAMPO.

## Struttura dell'Excel (riferimento)

Come lo script interpreta il file — utile se il parsing fallisce o l'Excel
cambia formato:

- **Catalogo L2**: foglio `Catalogo Entità`, header a riga 2, dati da riga 3.
  Storicizzazione e coppie sorgente -> cluster sono parsate dalla colonna
  `STORICIZZAZIONE ENTITA FINALE E ARCHIVI SORGENTI`; le subject area `_OLD`
  sono escluse dai filtri per area.
- **Catalogo L3**: stesso foglio `Catalogo Entità`, header a riga 2 con
  colonne `DM_ID`, `Nome DataMart`, `ID_SOTTO_PROCESSO`,
  `Regola Tecnica Perimetro`, `ENTITà MAIN`, `ENTITà L1 IN INPUT`,
  `ENTITà L2 IN INPUT`, `PROFONDITA STORICA`, `FREQUENZA UPDATES`. Le
  celle-lista (`;`/newline) sono normalizzate in `a, b`.
- **Foglio entita'/DataMart**: riga procedura a riga 2, header a riga 3, dati
  da riga 4. I blocchi procedura si individuano dalle colonne header che
  iniziano con `MODULO` (multiprocedura); dentro ogni blocco si cercano
  `SORGENTE TABELLA`, `SORGENTE CAMPI`, `REGOLA TECNICA`,
  `CHIAVI DI AGGANCIO`. Senza colonne `MODULO` il foglio e' a procedura
  singola e il nome procedura si deriva da `SORGENTE TABELLA <X> L1`
  (altrimenti `P1`).
- Celle placeholder (`---`, `-`, `nan`, vuote, `NA` per le CHIAVI) -> campo
  vuoto.

## Se l'output non è quello atteso

Non concludere subito "niente sorgente/PK, foglio non generabile" solo
perché `dm.py sheet` restituisce TAB/COL/RT vuoti o senza `FLAG_PK` per
un'entità che dovrebbe averne (es. compare nel catalogo con sorgenti/cluster
noti, o altre entità dello stesso foglio hanno dati reali). Prima di
scartare l'entità, leggi il foglio grezzo con openpyxl:

```python
import openpyxl
wb = openpyxl.load_workbook('raw/<file>.xlsx', read_only=True)
ws = wb['NOME_ENTITA']
for i, row in enumerate(ws.iter_rows(values_only=True)):
    print(i, row)
```

Casi tipici trovati così, entrambi da correggere (nel parser se è un bug
generale, altrimenti solo nella lettura di quel foglio):
- **Bug del parser**: header con colonne duplicate senza prefisso `MODULO`
  (es. due blocchi sorgente TIG-CO/TIG-CA su un foglio a procedura singola)
  — verifica che `detect_procedures` prenda la prima occorrenza di
  `SORGENTE TABELLA`/`SORGENTE CAMPI`/`REGOLA TECNICA`/`CHIAVI DI AGGANCIO`,
  non l'ultima. Se trovi un bug che si applica in generale, correggilo in
  `scripts/dm.py` (non un fix a mano solo per quel foglio) e segnalalo.
- **Errore di compilazione nello sheet**: colonne shiftate rispetto
  all'header dichiarato (es. il nome tabella reale finito nella colonna
  `SORGENTE CAMPI` invece che in `SORGENTE TABELLA`, e il vero nome colonna
  finito in `REGOLA FUNZIONALE`). Se lo shift è sistematico su tutte le
  righe del foglio, ricostruisci la mappatura corretta e segnalalo
  (`-- WARN` nel codice generato); non è "inventare", è leggere colonne
  spostate in modo verificabile riga per riga.

Solo se dopo questo controllo il foglio risulta genuinamente privo di
sorgente/PK per ogni campo (nessuna tabella indicata da nessuna parte, non
solo nelle colonne standard) è corretto trattarlo come non generabile.

## Uso standalone

Se l'utente sta solo consultando il data model (niente generazione),
rispondi con l'output dei comandi riassunto in modo leggibile. Se invece
chiede di generare SQL/YML dbt -> usa la skill `develop-l2` (entita' L2) o
`develop-l3` (DataMart L3).
