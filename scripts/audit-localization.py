"""Inventory Chinese Dart literals for manual localization review, not auto-translation.

Includes translated source strings and business data: counts are candidates, NOT
confirmed missing translations. Skips comments and generated Dart files.
Run from the repository root: python scripts/audit-localization.py
"""
import csv
import re
from collections import Counter
from pathlib import Path

root = Path('lib')
out = Path('docs/audits/localization-2026-10-05')
out.mkdir(parents=True, exist_ok=True)
token = re.compile(r'''//[^\n]*|/\*[\s\S]*?\*/|r?(?:"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27)''')
han = re.compile(r'[\u3400-\u9fff]')
rows = []
files = list(root.rglob('*.dart'))
for file in sorted(files):
    if file.name.endswith(('.g.dart', '.freezed.dart')):
        continue
    source = file.read_text(encoding='utf-8')
    for match in token.finditer(source):
        value = match.group()
        if value.startswith(('//', '/*')) or not han.search(value):
            continue
        prefix = source[max(0, match.start()-100):match.start()]
        classification = 'review-context'
        if re.search(r'(?:Text|TextSpan)\s*\(\s*(?:text\s*:\s*)?$', prefix) or re.search(r'(?:tooltip|hintText|labelText|title|message)\s*:\s*$', prefix):
            classification = 'direct-ui-candidate'
        rows.append((file.as_posix(), source.count('\n', 0, match.start())+1, classification, value))
with (out/'chinese-literals.csv').open('w', encoding='utf-8-sig', newline='') as output:
    writer = csv.writer(output)
    writer.writerow(('file', 'line', 'classification', 'literal'))
    writer.writerows(rows)
counts = Counter()
direct = Counter()
for file, _, category, _ in rows:
    parts = file.split('/')
    module = parts[3] if '/features/' in file else 'core-and-app'
    counts[module] += 1
    direct[module] += category == 'direct-ui-candidate'
print(f'Scanned {len(files)} Dart files (generated files excluded from literal extraction).')
print(f'{len(rows)} Chinese literals; {sum(direct.values())} direct UI candidates.')
for module, count in counts.most_common():
    print(f'{module}: {count} literals, {direct[module]} direct UI candidates')
