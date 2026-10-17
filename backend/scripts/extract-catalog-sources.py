#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
# Extraction des grilles partenaires reçues en PDF / XLSX vers des CSV relus.
#
# Outil de POSTE, pas de production : le conteneur `api` n'a pas Python. Les
# CSV produits sont commités dans `scripts/data/` et ce sont EUX que lisent les
# imports TypeScript (`import:omnes-spring`, `import:igensia`). On relance cet
# outil seulement quand le propriétaire envoie une nouvelle grille.
#
#   pip install pdfplumber openpyxl
#   python3 -I scripts/extract-catalog-sources.py omnes-spring scripts/data/omnes_spring_27.pdf > scripts/data/omnes_spring_27.csv
#   python3 -I scripts/extract-catalog-sources.py igensia scripts/data/igensia_2027.pdf > scripts/data/igensia_2027.csv
#   python3 -I scripts/extract-catalog-sources.py abc scripts/data/abc_2027.xlsx > scripts/data/abc_2027.csv
#
# Pourquoi lire les CARACTÈRES du PDF OMNES plutôt que `pdftotext` : l'export
# Salesforce fait déborder certaines cellules sur leurs voisines (« Bachelor
# 1ère année » chevauche la colonne Langue). `pdftotext -layout` entrelace alors
# les lettres (« aFnRnée ») et coupe des lignes en deux. Dans le flux du PDF,
# chaque cellule reste une suite de caractères contiguë : on la reconstitue
# dans l'ordre du flux, puis on la range dans la colonne où elle COMMENCE.
# ─────────────────────────────────────────────────────────────────────────────
import csv
import re
import sys

# En-têtes identiques à ceux de `omnes_fall_26.xlsx` : la grille de printemps
# se lit avec les mêmes noms de colonnes que celle d'automne.
OMNES_HEADERS = [
    'Ecole / School',
    'Type_Programme / Type of program',
    'Niveau_Etude_ / Level of studies',
    'Niveau Admission / Admission Level',
    'Langue / Language',
    'Rythme / Rythm',
    'Campus',
    'NOM / NAME',
    'Payment Comptant / Payment Upfront',
    'Paiement Echelonné / With installments (2)',
    'Date_de_Rentrée / Intake Date',
]

# Abscisse (pt) où commence chaque colonne de la grille SPRING 27, relevée sur
# la ligne d'en-tête. Une cellule appartient à la dernière colonne dont le
# début est à sa gauche (marge de 3 pt).
OMNES_COLUMNS = [
    ('school', 52.8),
    ('type', 97.4),
    ('level', 162.0),
    ('admission', 226.6),
    ('language', 291.1),
    ('rhythm', 321.8),
    ('campus', 355.2),
    ('name', 419.8),
    ('upfront', 787.4),
    ('installments_date', 852.0),
]

OMNES_SCHOOLS = {'ECE', 'ESCE', 'INSEEC', 'HEIP', 'Sup de Pub'}


def _column_of(x0):
    found = None
    for name, start in OMNES_COLUMNS:
        if x0 >= start - 3:
            found = name
    return found


def _runs(page):
    """Cellules reconstituées dans l'ordre du flux du PDF."""
    runs = []
    cur = None
    for c in page.chars:
        if (
            cur is not None
            and abs(c['top'] - cur['top']) < 2
            and cur['x1'] - 1.5 <= c['x0'] <= cur['x1'] + 4
        ):
            cur['text'] += c['text']
            cur['x1'] = c['x1']
        else:
            if cur is not None:
                runs.append(cur)
            cur = {'x0': c['x0'], 'x1': c['x1'], 'top': c['top'], 'text': c['text']}
    if cur is not None:
        runs.append(cur)
    return runs


def extract_omnes_spring(pdf_path):
    import pdfplumber

    rows = []
    current = None
    with pdfplumber.open(pdf_path) as pdf:
        for page_index, page in enumerate(pdf.pages):
            for run in _runs(page):
                text = run['text']
                column = _column_of(run['x0'])
                # La ligne d'en-tête de la première page.
                if page_index == 0 and run['top'] < 65:
                    continue
                if column == 'school':
                    if text.strip() in OMNES_SCHOOLS:
                        current = {name: '' for name, _ in OMNES_COLUMNS}
                        rows.append(current)
                    else:
                        # Le pavé « Filtres appliqués » de la dernière page.
                        current = None
                        continue
                if current is None:
                    continue
                current[column] = (current[column] + ' ' + text).strip() if current[column] else text

    out = csv.writer(sys.stdout, lineterminator='\n')
    out.writerow(OMNES_HEADERS)
    for row in rows:
        # « 702501/03/2027 » : l'échelonné et la date se touchent dans le flux.
        match = re.fullmatch(r'(\d+)\s*(\d{2}/\d{2}/\d{4})', row['installments_date'].strip())
        if not match or not row['upfront'].strip().isdigit():
            raise SystemExit(f'Ligne illisible : {row}')
        out.writerow([
            row['school'].strip(),
            row['type'].strip(),
            row['level'].strip(),
            row['admission'].strip(),
            row['language'].strip(),
            row['rhythm'].strip(),
            row['campus'].strip(),
            row['name'].strip(),
            row['upfront'].strip(),
            match.group(1),
            match.group(2),
        ])
    print(f'{len(rows)} lignes', file=sys.stderr)


IGENSIA_HEADERS = [
    'Ecole', 'Domaine', 'Programme', 'Diplome', 'Reconnaissance', 'Rentree',
    'Campus', 'Niveau entree', 'Prerequis', 'Tarif', 'Mode de candidature',
]


def _flat(cell):
    return re.sub(r'\s+', ' ', (cell or '').replace('\n', ' ')).strip()


def extract_igensia(pdf_path):
    import pdfplumber

    out = csv.writer(sys.stdout, lineterminator='\n')
    out.writerow(IGENSIA_HEADERS)
    count = 0
    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            for table in page.extract_tables():
                for row in table:
                    cells = [_flat(c) for c in row]
                    if not cells or cells[0] in ('', 'ECOLES'):
                        continue
                    if len(cells) != len(IGENSIA_HEADERS):
                        raise SystemExit(f'Ligne inattendue : {cells}')
                    out.writerow(cells)
                    count += 1
    print(f'{count} lignes', file=sys.stderr)


ABC_HEADERS = ['Ecole', 'Niveau', 'Campus', 'Domaine', 'Programme', 'Langue', 'Tarif', 'Rentree']


def extract_abc(xlsx_path):
    import openpyxl

    sheet = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True).worksheets[0]
    out = csv.writer(sys.stdout, lineterminator='\n')
    out.writerow(ABC_HEADERS)
    count = 0
    for row in sheet.iter_rows(values_only=True):
        cells = [_flat('' if c is None else str(c)) for c in row][: len(ABC_HEADERS)]
        # Le titre « PORTEFEUILLE ABC » et la ligne d'en-tête ne sont pas des
        # programmes ; une ligne de programme commence par l'école.
        if not cells or cells[0] != 'ABC':
            continue
        out.writerow(cells)
        count += 1
    print(f'{count} lignes', file=sys.stderr)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('omnes-spring', 'igensia', 'abc'):
        raise SystemExit('Usage : extract-catalog-sources.py omnes-spring|igensia|abc <fichier>')
    {'omnes-spring': extract_omnes_spring, 'igensia': extract_igensia, 'abc': extract_abc}[sys.argv[1]](sys.argv[2])
