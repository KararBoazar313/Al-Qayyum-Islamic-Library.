#!/usr/bin/env python3
"""Validate Qayyum catalog CSV rows before any database import.
No network calls, no invented records, and no automatic madhhab inference.
"""
import argparse, csv, hashlib, json, re, sys
from pathlib import Path
from urllib.parse import urlparse

REQUIRED = ["author_name", "language", "source_id", "source_record_id", "verification_status"]
ALLOWED_FAMILIES = {"Shi'i", "Sunni", "Ibadi", "Zaydi", "Ismaili", "Other Muslim", "Comparative/Unassigned", ""}
ALLOWED_VERIFY = {"Verified", "Needs review", "Unverified"}
URL_FIELDS = ["catalogue_record_url", "full_text_url", "pdf_url"]

def norm(s):
    s = (s or "").strip().lower()
    s = re.sub(r"[\u064B-\u065F\u0670ـ]", "", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي")
    return re.sub(r"\s+", " ", s)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv_file", type=Path)
    ap.add_argument("--out", type=Path, default=None, help="Optional JSON report path")
    args = ap.parse_args()
    raw = args.csv_file.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    # utf-8-sig accepts the BOM used by common Arabic spreadsheet exports.
    with args.csv_file.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        headers = reader.fieldnames or []
        missing = [h for h in REQUIRED if h not in headers]
        rows = list(reader)
    report = {"file": args.csv_file.name, "sha256": digest, "headers": headers,
              "rows": len(rows), "valid": 0, "needs_review": 0,
              "errors": [], "duplicate_candidates": [],
              "note": "Validation only; this tool does not create book records or import files."}
    if missing:
        report["errors"].append({"row": 0, "issues": ["missing required columns: " + ", ".join(missing)]})
    seen = {}
    for n, row in enumerate(rows, start=2):
        issues = []
        for field in REQUIRED:
            if not (row.get(field) or "").strip(): issues.append(f"missing {field}")
        if not ((row.get('title_ar') or '').strip() or (row.get('title_original') or '').strip()): issues.append('missing title_ar or title_original')
        family = (row.get("school_family") or "").strip()
        if family not in ALLOWED_FAMILIES: issues.append("unknown school_family; do not infer it")
        status = (row.get("verification_status") or "").strip()
        if status and status not in ALLOWED_VERIFY: issues.append("invalid verification_status")
        for field in URL_FIELDS:
            value = (row.get(field) or "").strip()
            if value:
                p = urlparse(value)
                if p.scheme not in {"http", "https"} or not p.netloc:
                    issues.append(f"invalid URL in {field}")
        key = (norm(row.get("title_ar")), norm(row.get("author_name")))
        if all(key) and key in seen:
            report["duplicate_candidates"].append({"rows": [seen[key], n], "title": row.get("title_ar"), "author": row.get("author_name")})
        elif all(key): seen[key] = n
        if issues: report["errors"].append({"row": n, "issues": issues})
        else:
            report["valid"] += 1
            if status != "Verified" or family == "": report["needs_review"] += 1
    report["duplicate_candidate_count"] = len(report["duplicate_candidates"])
    report["passed_structure"] = not missing and not report["errors"]
    output = json.dumps(report, ensure_ascii=False, indent=2)
    print(output)
    if args.out: args.out.write_text(output + "\n", encoding="utf-8")
    return 0 if report["passed_structure"] else 2

if __name__ == "__main__":
    sys.exit(main())
