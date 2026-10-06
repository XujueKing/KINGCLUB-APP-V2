"""Read-only aggregate audit of a MySQL dump; never prints customer records."""
import collections
import hashlib
import json
import pathlib
import re
import sys

schema_path, data_path = map(pathlib.Path, sys.argv[1:3])
schema = schema_path.read_text(encoding="utf-8-sig")
targets = {
    "k_user_relation": ["agenyType", "agencyStatus"],
    "k_wallet": ["walletType", "walletStatus"],
    "k_balance_details": ["accountType", "detailsStatus"],
    "k_commission_log": ["personType"],
    "k_withdrawal": ["withdrawalStatus"],
}
columns = {}
result = {}
for name, fields in targets.items():
    match = re.search(r"CREATE TABLE `" + name + r"` \((.*?)\n\)", schema, re.S)
    columns[name] = re.findall(r"^\s*`([^`]+)`", match[1], re.M)
    result[name] = {"rows": 0, "activeRows": 0, "distribution": {f: collections.Counter() for f in fields}}

def rows(source):
    quoted = escaped = False
    depth = 0
    row, value = [], []
    for c in source:
        if escaped:
            value.append(c)
            escaped = False
        elif quoted and c == "\\":
            escaped = True
        elif c == "'":
            quoted = not quoted
        elif quoted:
            value.append(c)
        elif c == "(":
            depth += 1
            if depth == 1:
                row, value = [], []
        elif c == "," and depth == 1:
            row.append("".join(value).strip())
            value = []
        elif c == ")":
            depth -= 1
            if depth == 0:
                row.append("".join(value).strip())
                yield row
        elif depth:
            value.append(c)
    if quoted or depth:
        raise ValueError("Multiline or incomplete INSERT: audit stopped")

with data_path.open("rb") as handle:
    for line in handle:
        if not line.startswith(b"INSERT INTO `k_"):
            continue
        match = re.match(rb"INSERT INTO `([^`]+)`(?: \(([^;]+?)\))? VALUES (.*);\s*$", line)
        if not match or match[1].decode() not in targets:
            continue
        name = match[1].decode()
        insert_columns = re.findall(r"`([^`]+)`", match[2].decode()) if match[2] else columns[name]
        for values in rows(match[3].decode("utf-8")):
            if len(values) != len(insert_columns):
                raise ValueError("Column count mismatch: " + name)
            row = dict(zip(insert_columns, values))
            stats = result[name]
            stats["rows"] += 1
            stats["activeRows"] += row.get("deleted") == "0"
            for field, counter in stats["distribution"].items():
                counter[row[field]] += 1

if not result["k_user_relation"]["rows"] or not result["k_wallet"]["rows"]:
    raise ValueError("Expected populated tables missing; do not treat parser failure as zero rows")
print(json.dumps({"scope": "historical local dump, NOT live balances",
    "schemaSha256": hashlib.sha256(schema_path.read_bytes()).hexdigest(),
    "dataBytes": data_path.stat().st_size, "tables": result}, ensure_ascii=False, indent=2))
