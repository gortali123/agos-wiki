"""dm.py - lettore dei data model Excel Agos L2 e L3 (skill: dm-reader).

Parser condiviso: usato standalone per consultare il data model, e dalle skill
develop-l2 / develop-l3 (generazione SQL/YML dbt) per generare codice dbt.
Non scrive nulla: si puo' eseguire in place anche da un mount in sola lettura.

Sottocomandi:
  python3 dm.py sheets                       # lista fogli
  python3 dm.py catalog [SUBJECT_AREA] [ENTITA]
  python3 dm.py sheet NOME_ENTITA
  python3 dm.py NOME_ENTITA                  # scorciatoia di 'sheet NOME_ENTITA'

Tutti i sottocomandi accettano --file PATH per puntare a un Excel specifico,
altrimenti si auto-rileva il piu' recente in DM_DIR (default: raw/, relativo
alla working directory da cui viene lanciato lo script; override con env
var DM_DIR).

Il formato del catalogo viene auto-rilevato dall'header del foglio
'Catalogo Entità':
- L2 ('Nome Entità'): per ogni entita' -> subject area, storicizzazione
  (S1-S4), coppie sorgente -> cluster (es. OXTRFTRU:A2) e dipendenze.
- L3 ('Nome DataMart'): per ogni DataMart -> DM_ID, sotto-processo, entita'
  main, sorgenti L1 e L2 in input, frequenza update e regola tecnica perimetro.

Da 'sheet' ricavi, per ogni campo e procedura: PK, tipo, TAB / COL / RT /
CHIAVI (tabelle sorgente, colonne sorgente, regola tecnica, chiavi di
aggancio). Vale sia per i fogli entita' L2 sia per i fogli DataMart L3.

Ricerca Excel: auto-rileva il file Excel piu' recente in DM_DIR (default
'raw', override con env var DM_DIR o flag --file). Se in DM_DIR convivono piu'
data model (es. L2 e L3), vince il piu' recente per mtime: per lavorare su un
file specifico, passa --file.
"""
import os, sys, re, glob
import pandas as pd

DM_DIR = os.environ.get('DM_DIR', 'raw')

# sottocomandi riconosciuti: tutto il resto al primo argomento e' un nome foglio
SUBCOMMANDS = {'sheets', 'catalog', 'sheet'}


def find_excel(explicit=None):
    if explicit:
        if not os.path.isfile(explicit):
            sys.exit(f"File non trovato: {explicit}")
        return explicit
    files = sorted(
        glob.glob(os.path.join(DM_DIR, '**', '*.xlsx'), recursive=True)
        + glob.glob(os.path.join(DM_DIR, '**', '*.xlsm'), recursive=True)
        + glob.glob(os.path.join(DM_DIR, '**', '*.xls'), recursive=True),
        key=os.path.getmtime, reverse=True,
    )
    if not files:
        sys.exit(
            f"Nessun Excel trovato in {DM_DIR}/.\n"
            "Aggiungi il data model in raw/ (o passa --file PATH / imposta DM_DIR)."
        )
    return files[0]


def cell(v):
    """Normalizza una cella a stringa pulita; '' per vuoti/placeholder."""
    if isinstance(v, pd.Series):
        v = v.dropna().iloc[0] if len(v.dropna()) > 0 else None
    if (pd.isna(v) if not isinstance(v, str) else False):
        return ''
    s = str(v).strip()
    return '' if s in ('---', 'nan', 'None', '-') else s


# ---------------------------------------------------------------- sheets
def cmd_sheets(file=None):
    path = find_excel(file)
    xl = pd.ExcelFile(path)
    print(f'# {path}')
    for s in xl.sheet_names:
        print(s)


# --------------------------------------------------------------- catalog
def parse_storicizzazione(val):
    if pd.isna(val):
        return 'N/A', []
    s = str(val).strip()
    if not s or s == 'nan':
        return 'N/A', []
    if s.startswith('OP'):
        return 'WIP', []
    stor = None
    sources = []
    for line in s.split('\n'):
        line = line.strip()
        if not line:
            continue
        m_expl = re.match(r'Storicizzazione\s*:\s*(S[1-4])', line, re.IGNORECASE)
        if m_expl:
            stor = m_expl.group(1)
            continue
        if re.match(r'^S[1-4]$', line):
            if not stor:
                stor = line
            continue
        m = re.search(r'(?:\[L1\]\s*)?(\w+)\s*-+>\s*(\w+)', line)
        if m:
            tab, rest = m.group(1), m.group(2)
            if re.match(r'^S[1-4]$', rest):
                if not stor:
                    stor = rest
            else:
                sources.append(f'{tab}:{rest}')
                m2 = re.search(r'-+>\s*(S[1-4])', line[m.end():])
                if m2 and not stor:
                    stor = m2.group(1)
    return stor or 'N/A', sources


def _norm_header(h):
    """Normalizza un nome colonna del catalogo per il matching."""
    return re.sub(r'\s+', ' ', str(h)).strip().upper()


def _find_col(header, *needles):
    """Indice della prima colonna il cui nome normalizzato contiene tutti i needle."""
    for i, h in enumerate(header):
        nh = _norm_header(h)
        if nh and all(n in nh for n in needles):
            return i
    return None


def _norm_list(val):
    """Normalizza una cella-lista del catalogo L3 ('A;\\nB' / 'A, B') in 'A, B'."""
    s = cell(val)
    if not s or s.upper() in ('NA', 'N/A', '/'):
        return ''
    parts = re.split(r'[;,\n]+', s)
    parts = [p.strip() for p in parts if p.strip() and p.strip() not in ('-',)]
    return ', '.join(parts)


def detect_catalog_format(raw):
    """'L2' se l'header (riga 2) contiene 'Nome Entità', 'L3' se 'Nome DataMart'."""
    header = [_norm_header(h) for h in raw.iloc[1]]
    if any('NOME ENTIT' in h for h in header):
        return 'L2'
    if any('NOME DATAMART' in h for h in header):
        return 'L3'
    return 'L2'  # fallback: comportamento storico


def parse_catalog_l3(raw, area=None, entity=None):
    """Catalogo L3 (DataMart). Restituisce dict:
    {name, dm_id, processo, main, l1, l2, freq, profondita, perimetro}."""
    header = list(raw.iloc[1])
    df = raw.iloc[2:].copy().reset_index(drop=True)
    c_name = _find_col(header, 'NOME DATAMART')
    c_id = _find_col(header, 'DM_ID')
    c_proc = _find_col(header, 'SOTTO_PROCESSO')
    c_main = _find_col(header, 'MAIN')
    c_l1 = _find_col(header, 'L1', 'INPUT')
    c_l2 = _find_col(header, 'L2', 'INPUT')
    c_freq = _find_col(header, 'FREQUENZA')
    c_prof = _find_col(header, 'PROFONDITA')
    c_perim = _find_col(header, 'REGOLA TECNICA PERIMETRO')
    area = area.upper().strip() if area else None
    entity = entity.upper().strip() if entity else None
    records = []
    for _, row in df.iterrows():
        name = cell(row.get(c_name)) if c_name is not None else ''
        if not name:
            continue
        if entity and name.upper() != entity:
            continue
        processo = cell(row.get(c_proc)) if c_proc is not None else ''
        if area and not entity and area not in processo.upper():
            continue
        perim = cell(row.get(c_perim)) if c_perim is not None else ''
        if perim:
            perim = ' '.join(perim.split())
        prof = cell(row.get(c_prof)) if c_prof is not None else ''
        if prof:
            prof = ' '.join(prof.split())
        records.append({
            'name': name,
            'dm_id': cell(row.get(c_id)) if c_id is not None else '',
            'processo': processo,
            'main': _norm_list(row.get(c_main)) if c_main is not None else '',
            'l1': _norm_list(row.get(c_l1)) if c_l1 is not None else '',
            'l2': _norm_list(row.get(c_l2)) if c_l2 is not None else '',
            'freq': cell(row.get(c_freq)) if c_freq is not None else '',
            'profondita': prof,
            'perimetro': perim,
        })
    return records


def parse_catalog(area=None, entity=None, raw=None, file=None):
    """Catalogo L2. Restituisce una lista di dict: {name, area, stor, sources, dep}."""
    if raw is None:
        raw = pd.read_excel(find_excel(file), sheet_name='Catalogo Entità', header=None)
    df = raw.iloc[2:].copy()
    df.columns = list(raw.iloc[1])
    df = df.reset_index(drop=True).dropna(subset=['Nome Entità'])
    area = area.upper().strip() if area else None
    entity = entity.upper().strip() if entity else None
    if entity:
        mask = df['Nome Entità'].astype(str).str.upper().str.strip() == entity
    elif area:
        mask = df['Subject Area'].astype(str).str.upper().str.strip().str.contains(area, na=False)
        mask = mask & ~df['Subject Area'].astype(str).str.contains('_OLD', na=False)
    else:
        mask = pd.Series([True] * len(df))
    stor_col = 'STORICIZZAZIONE ENTITA FINALE E ARCHIVI SORGENTI'
    dep_col = 'DIPENDENZA DA ALTRE ENTITA L2'
    records = []
    for _, row in df[mask].iterrows():
        name = str(row['Nome Entità']).strip()
        a = str(row['Subject Area']).strip().replace('​', '').replace('\xa0', ' ')
        stor, sources = parse_storicizzazione(row.get(stor_col))
        dep_raw = str(row.get(dep_col, '')).strip()
        dep = '-' if dep_raw in ('', 'nan', 'None') else dep_raw
        records.append({'name': name, 'area': a, 'stor': stor, 'sources': sources, 'dep': dep})
    return records


def cmd_catalog(area=None, entity=None, file=None):
    raw = pd.read_excel(find_excel(file), sheet_name='Catalogo Entità', header=None)
    fmt = detect_catalog_format(raw)
    if fmt == 'L3':
        records = parse_catalog_l3(raw, area, entity)
        if not records:
            print('Nessun DataMart trovato.' + (f" Filtro: {entity or area}" if (entity or area) else ''))
            return
        for r in records:
            print(f"{r['name']} | {r['dm_id'] or '-'} | {r['processo'] or '-'} | "
                  f"MAIN: {r['main'] or '-'} | L1: {r['l1'] or '-'} | L2: {r['l2'] or '-'} | "
                  f"FREQ: {r['freq'] or '-'} | PROFONDITA: {r['profondita'] or '-'} | "
                  f"PERIMETRO: {r['perimetro'] or '-'}")
        return
    for r in parse_catalog(area, entity, raw=raw):
        src_str = ', '.join(r['sources']) if r['sources'] else '-'
        print(f"{r['name']} | {r['area']} | {r['stor']} | SORGENTI: {src_str} | DIP: {r['dep']}")


# ----------------------------------------------------------------- sheet
def load_sheet(name, file=None):
    """Trova il foglio (case-insensitive) e restituisce (match, proc_row, header, df).
    Esce con messaggio chiaro se il foglio non esiste."""
    xl = pd.ExcelFile(find_excel(file))
    match = next((s for s in xl.sheet_names if s.strip().upper() == name.strip().upper()), None)
    if match is None:
        print(f"Sheet '{name}' non trovato.")
        print('Disponibili: ' + ', '.join(xl.sheet_names))
        sys.exit(1)
    raw = xl.parse(match, header=None)
    proc_row = raw.iloc[1]
    header = list(raw.iloc[2])
    df = raw.iloc[3:].copy()
    df.columns = range(len(header))
    df = df.reset_index(drop=True)
    return match, proc_row, header, df


def locate_columns(header):
    """Indici delle colonne campo fisse. Solleva KeyError con nome leggibile
    se manca una colonna richiesta (foglio non in formato entita').
    Alcuni fogli (es. sotto-processo Campioni) usano 'TYPE' al posto di
    'FORMATO': entrambe le etichette sono accettate."""
    cols = {}
    for key, labels in (('nome', ('NOME CAMPO',)), ('pk', ('FLAG_PK',)),
                        ('fmt', ('FORMATO', 'TYPE')), ('len', ('LENGTH',))):
        idx = next((header.index(l) for l in labels if l in header), None)
        if idx is None:
            raise KeyError(labels[0])
        cols[key] = idx
    cols['dec'] = next((i for i, h in enumerate(header)
                        if isinstance(h, str) and 'DECIMAL' in h.upper()), None)
    return cols


def detect_procedures(header, proc_row):
    """Rileva i blocchi procedura. Multiprocedura: colonne header che iniziano
    con 'MODULO'. Procedura singola: nessun MODULO, nome derivato da
    'SORGENTE TABELLA <X> L1'. Restituisce lista di dict {name, tab, src, rt, key}."""
    blocks = []
    i = 0
    while i < len(header):
        h = header[i]
        if isinstance(h, str) and h.startswith('MODULO'):
            tab_col = src_col = rt_col = key_col = None
            next_mod = next((k for k in range(i + 1, len(header))
                             if isinstance(header[k], str) and header[k].startswith('MODULO')), len(header))
            # Prima occorrenza vince: alcuni fogli hanno un secondo blocco
            # colonne (es. 'SORGENTE TABELLA FEA L1') dentro lo stesso range
            # senza un proprio header 'MODULO', che altrimenti sovrascrive
            # il blocco giusto.
            for j in range(i, next_mod):
                hj = str(header[j]) if pd.notna(header[j]) else ''
                if 'SORGENTE TABELLA' in hj and tab_col is None:
                    tab_col = j
                elif 'SORGENTE CAMPI' in hj and src_col is None:
                    src_col = j
                elif hj == 'REGOLA TECNICA' and rt_col is None:
                    rt_col = j
                elif 'CHIAVI DI AGGANCIO' in hj and key_col is None:
                    key_col = j
            pname = str(proc_row.iloc[i]).strip() if pd.notna(proc_row.iloc[i]) else ''
            if not pname or pname == '---' or pname.startswith("Y'") or 'compilare' in pname.lower():
                pname = f'P{len(blocks)+1}'
            else:
                pname = pname.split(' ')[0].split('\n')[0].strip()
            blocks.append({'name': pname, 'tab': tab_col, 'src': src_col, 'rt': rt_col, 'key': key_col})
        i += 1
    if blocks:
        return blocks

    # Fallback: procedura singola. Se l'header ripete queste etichette piu'
    # volte senza prefisso MODULO (es. blocchi doppi TIG-CO/TIG-CA su un
    # foglio a procedura unica), vince la PRIMA occorrenza: le colonne
    # successive sono blocchi ridondanti/vuoti, non un'altra procedura.
    tab_col = src_col = rt_col = key_col = None
    for j, h in enumerate(header):
        if not isinstance(h, str):
            continue
        if 'SORGENTE TABELLA' in h and tab_col is None:
            tab_col = j
        elif 'SORGENTE CAMPI' in h and src_col is None:
            src_col = j
        elif 'REGOLA TECNICA' in h and rt_col is None:
            rt_col = j
        elif 'CHIAVI DI AGGANCIO' in h and key_col is None:
            key_col = j
    pname = 'P1'
    if tab_col is not None:
        parts = header[tab_col].replace('SORGENTE TABELLA', '').strip().split()
        if parts:
            pname = parts[0]
    return [{'name': pname, 'tab': tab_col, 'src': src_col, 'rt': rt_col, 'key': key_col}]


def extract_records(df, cols, procs):
    """Produce una lista di dict {nome, pk, tipo, proc, tab, col, rt, chiavi}.
    Un campo con N procedure -> N record con stesso 'nome'.
    TAB/COL multilinea (es. '[L1] X' / '[L2] Y') sono normalizzati su una riga
    con separatore ' ; '."""
    def multiline(v):
        parts = [' '.join(p.split()) for p in str(v).split('\n')]
        return ' ; '.join(p for p in parts if p)

    records = []
    for _, row in df.iterrows():
        nome = cell(row.get(cols['nome']))
        if not nome:
            continue
        pk = cell(row.get(cols['pk'])) or 'N'
        fmt = cell(row.get(cols['fmt']))
        length = cell(row.get(cols['len']))
        dec = cell(row.get(cols['dec'])) if cols['dec'] is not None else ''
        fmt_str = fmt
        if length:
            fmt_str = f'{fmt}({length}' + (f',{dec}' if dec else '') + ')'
        for proc in procs:
            tab = cell(row.get(proc['tab'])) if proc['tab'] is not None else ''
            src = cell(row.get(proc['src'])) if proc['src'] is not None else ''
            rt = cell(row.get(proc['rt'])) if proc['rt'] is not None else ''
            chiavi = cell(row.get(proc['key'])) if proc['key'] is not None else ''
            if tab:
                tab = multiline(tab)
            if src:
                src = multiline(src)
            if rt:
                rt = ' '.join(rt.split())
            if chiavi and chiavi.upper() in ('NA', 'N/A'):
                chiavi = ''
            if chiavi:
                chiavi = ' '.join(chiavi.split())
            records.append({'nome': nome, 'pk': pk, 'tipo': fmt_str,
                            'proc': proc['name'], 'tab': tab, 'col': src,
                            'rt': rt, 'chiavi': chiavi})
    return records


def cmd_sheet(name, file=None):
    match, proc_row, header, df = load_sheet(name, file)
    try:
        cols = locate_columns(header)
    except KeyError as e:
        print(f"Foglio '{match}' non in formato entita': manca la colonna {e}.")
        sys.exit(1)
    procs = detect_procedures(header, proc_row)
    records = extract_records(df, cols, procs)

    proc_names = [p['name'] for p in procs]
    print(f'=== {match} | P={len(procs)} ({", ".join(proc_names)}) ===')
    print()
    print('CAMPO | PK | TIPO | PROC | TAB | COL | RT | CHIAVI')
    for r in records:
        print(f'{r["nome"]} | {r["pk"]} | {r["tipo"]} | {r["proc"]} | '
              f'{r["tab"] or "-"} | {r["col"] or "-"} | {r["rt"] or "-"} | '
              f'{r["chiavi"] or "-"}')


def _extract_file_flag(args):
    """Rimuove --file PATH da args (in qualunque posizione), restituisce (args, path)."""
    if '--file' in args:
        i = args.index('--file')
        if i + 1 >= len(args):
            sys.exit('Uso: --file PATH')
        path = args[i + 1]
        return args[:i] + args[i + 2:], path
    return args, None


if __name__ == '__main__':
    args, file_arg = _extract_file_flag(sys.argv[1:])
    cmd = args[0] if args else 'sheets'
    if cmd == 'sheets':
        cmd_sheets(file_arg)
    elif cmd == 'catalog':
        rest = args[1:3]
        cmd_catalog(*(rest + [None] * (2 - len(rest))), file=file_arg)
    elif cmd == 'sheet':
        if len(args) < 2:
            sys.exit('Uso: dm.py sheet NOME_ENTITA [--file PATH]')
        cmd_sheet(args[1], file_arg)
    elif cmd not in SUBCOMMANDS:
        # scorciatoia: primo argomento trattato come nome foglio/entita'
        cmd_sheet(cmd, file_arg)
    else:
        sys.exit(f"Comando sconosciuto: {cmd}. Usa: sheets | catalog | sheet | NOME_ENTITA [--file PATH]")
