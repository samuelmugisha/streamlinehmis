"""Minimal stdlib-only FHIR R5 stub server. See README.md in this directory
for why this exists and what it deliberately does not do."""
import json
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

import demo_data


def _load(name: str) -> dict:
    # The fixture files key patients as pt-demo-NNN; the DB uses UUID tokens
    # (patients.id), so swap in the same stable UUIDs demo_data uses.
    with open(os.path.join(os.path.dirname(__file__), name)) as f:
        text = re.sub(r"pt-demo-\d{3}", lambda m: demo_data.patient_token(m.group(0)), f.read())
    return json.loads(text)


FIXTURES: dict[str, list[dict]] = _load("fixtures.json")
SYNC_FIXTURES: dict[str, list[dict]] = _load("sync_fixtures.json")

# Generated operational data (billing, appointments, lab, pharmacy, staffing, OT),
# dated relative to today -- see demo_data.py.
DEMO = demo_data.build()
for rtype, resources in demo_data.fhir_resources(DEMO).items():
    FIXTURES.setdefault(rtype, []).extend(resources)
SYNC_FIXTURES.update({
    "dept": DEMO["departments"],
    "lab": DEMO["lab_orders"],
    "lab_result": DEMO["lab_results"],
    "lab_sample": DEMO["lab_samples"],
    "lab_analyzer": DEMO["lab_analyzers"],
    "pharmacy_order": DEMO["pharmacy_orders"],
    "pharmacy_inventory": DEMO["pharmacy_inventory"],
    "ot_room": DEMO["ot_rooms"],
    "ot_room_status": DEMO["ot_room_status"],
    "ot_schedule": DEMO["ot_schedule"],
    "ot_surgery": DEMO["ot_surgeries"],
    "staff_roster": DEMO["staff_roster"],
    "staff": DEMO["staff"],
})

# Plain-REST surface under /api/ (financial, appointments, pharmacy, lab ops, OT):
# path -> rows, plus {query param: row field} filters. Comma-separated values OR.
_REST: dict[str, tuple[list, dict]] = {
    "financial/invoices": (DEMO["invoices"], {"payment_status": "payment_status", "patient": "patient_id",
                                              "invoice_type": "invoice_type"}),
    "financial/claims": (DEMO["claims"], {"status": "status", "patient": "patient_token", "visit_id": "visit_id"}),
    "financial/payments": (DEMO["payments"], {}),
    "financial/payments/refunds": (DEMO["refunds"], {"invoice_id": "invoice_id"}),
    "financial/contracts": (DEMO["contracts"], {}),
    "appointments": (DEMO["appointments"], {"patient_id": "patient_id", "provider_id": "provider_id",
                                            "department_id": "department_id", "status": "status"}),
    "appointments/slots": (DEMO["doctor_slots"], {"provider_id": "provider_id", "date": "slot_date",
                                                  "specialization": "specialization"}),
    "pharmacy/orders": (DEMO["pharmacy_orders"], {}),
    "pharmacy/pending": ([o for o in DEMO["pharmacy_orders"] if o["status"] == "pending"], {}),
    "pharmacy/stat": ([o for o in DEMO["pharmacy_orders"] if o["is_stat"]], {}),
    "pharmacy/inventory": (DEMO["pharmacy_inventory"], {}),
    "pharmacy/dispensing-log": (DEMO["pharmacy_dispensing_log"], {}),
    "pharmacy/interactions": (DEMO["pharmacy_interactions"], {}),
    "pharmacy/substitutions": (DEMO["pharmacy_substitutions"], {}),
    "pharmacy/controlled-log": (DEMO["pharmacy_controlled_log"], {}),
    "pharmacy/capacity": (DEMO["pharmacy_capacity"], {}),
    "lab/qc-logs": (DEMO["lab_qc_logs"], {}),
    "lab/reflex-rules": (DEMO["lab_reflex_rules"], {}),
    "lab/validation-rules": (DEMO["lab_validation_rules"], {}),
    "lab/capacity-history": (DEMO["lab_capacity"], {}),
    "lab/critical-escalations": (DEMO["lab_critical_escalations"], {}),
    "ot/rooms": (DEMO["ot_rooms"], {}),
    "ot/room-status": (DEMO["ot_room_status"], {}),
    "ot/surgery-schedule": (DEMO["ot_schedule"], {}),
    "ot/surgeries": (DEMO["ot_surgeries"], {}),
    "ot/equipment-usage": (DEMO["ot_equipment"], {}),
}
# Child collections: <parent>/<id>/<child> -> rows whose <fk> == id
_REST_CHILDREN: dict[tuple[str, str], tuple[list, str]] = {
    ("financial/invoices", "line_items"): (DEMO["invoice_line_items"], "invoice_id"),
    ("financial/claims", "line_items"): (DEMO["claim_line_items"], "claim_id"),
    ("financial/claims", "history"): (DEMO["claim_history"], "claim_id"),
    ("financial/claims", "queries"): (DEMO["claim_queries"], "claim_id"),
    ("financial/payments", "entries"): (DEMO["payment_entries"], "payment_id"),
    ("financial/contracts", "rates"): (DEMO["contract_rates"], "contract_id"),
}


def _rest(path: str, qs: dict) -> tuple[int, object]:
    if path in _REST:
        rows, filters = _REST[path]
        for param, field in filters.items():
            wanted = qs.get(param, [None])[0]
            if wanted:
                allowed = {v.strip().lower() for v in wanted.split(",")}
                rows = [r for r in rows if str(r.get(field) or "").lower() in allowed]
        if path == "appointments" and qs.get("date", [None])[0]:
            rows = [r for r in rows if (r.get("appointment_time") or "").startswith(qs["date"][0])]
        return 200, {"data": rows, "total": len(rows)}
    head, _, child = path.rpartition("/")
    parent, _, rid = head.rpartition("/")
    if (parent, child) in _REST_CHILDREN:
        rows, fk = _REST_CHILDREN[(parent, child)]
        match = [r for r in rows if r.get(fk) == rid]
        return 200, {"data": match, "total": len(match)}
    if parent == "financial" and head in ("financial/collections", "financial/reconciliation"):
        key = "collections" if head.endswith("collections") else "reconciliation"
        row = DEMO[key]
        if child == DEMO["today"]:
            return 200, row
    return 404, {"error": f"no mock data for /api/{path}"}


def _bundle(resources: list[dict]) -> dict:
    return {
        "resourceType": "Bundle",
        "type": "searchset",
        "total": len(resources),
        "entry": [{"resource": r} for r in resources],
    }


def _class_code(enc: dict) -> str | None:
    try:
        return enc["class"][0]["coding"][0]["code"]
    except (KeyError, IndexError, TypeError):
        return None


def _category_codes(obs: dict) -> set[str]:
    try:
        return {c["code"] for cat in (obs.get("category") or []) for c in cat.get("coding", [])}
    except (KeyError, TypeError):
        return set()


def _subject_id(obs: dict) -> str | None:
    ref = (obs.get("subject") or {}).get("reference")
    return ref.split("/", 1)[1] if ref and "/" in ref else None


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, obj: dict) -> None:
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/fhir+json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        parts = [p for p in parsed.path.split("/") if p]
        qs = parse_qs(parsed.query)

        # GET /api/sync/<table> -- the plain-REST keyset initial-sync contract
        # (a completely separate surface from /fhir/*; see README.md). Always
        # returns everything in one page -- fixture row counts are tiny.
        if len(parts) == 3 and parts[0] == "api" and parts[1] == "sync":
            table = parts[2]
            rows = SYNC_FIXTURES.get(table, [])
            self._send_json(200, {
                "sync_id": f"mock-sync-{table}",
                "table": table,
                "pagination": {"has_more": False, "next_cursor": None},
                "rows": rows,
            })
            return

        # GET /api/<financial|appointments|pharmacy|lab|ot>/... -- plain-REST surface
        if len(parts) >= 2 and parts[0] == "api":
            status, obj = _rest("/".join(parts[1:]), qs)
            self._send_json(status, obj)
            return

        if not parts or parts[0] != "fhir" or len(parts) < 2:
            self._send_json(404, {"resourceType": "OperationOutcome"})
            return

        rtype = parts[1]

        # GET /fhir/Bundle/$changed-resources -- initial_sync's change-feed poll.
        # No real change stream here; an empty collection Bundle is a legitimate
        # "nothing changed" answer, not an error.
        if rtype == "Bundle" and len(parts) >= 3 and parts[2] == "$changed-resources":
            self._send_json(200, {"resourceType": "Bundle", "type": "collection", "entry": []})
            return

        resources = FIXTURES.get(rtype, [])

        if len(parts) == 3:  # read-by-id: /fhir/<Type>/<id>
            match = next((r for r in resources if r.get("id") == parts[2]), None)
            if match is None:
                self._send_json(404, {"resourceType": "OperationOutcome"})
            else:
                self._send_json(200, match)
            return

        # search
        filtered = resources
        if rtype == "Encounter":
            cls = qs.get("class", [None])[0]
            if cls:
                filtered = [r for r in filtered if _class_code(r) == cls]
            status = qs.get("status", [None])[0]
            if status:
                filtered = [r for r in filtered if r.get("status") == status]
        elif rtype == "Observation":
            category = qs.get("category", [None])[0]
            if category:
                filtered = [r for r in filtered if category in _category_codes(r)]
            patient = qs.get("patient", [None])[0]
            if patient:
                filtered = [r for r in filtered if _subject_id(r) == patient]
            code = qs.get("code", [None])[0]
            if code:
                filtered = [r for r in filtered
                            if code in {c.get("code") for c in (r.get("code") or {}).get("coding", [])}]
        elif rtype in ("ServiceRequest", "Specimen", "Device"):
            status = qs.get("status", [None])[0]
            if status:
                filtered = [r for r in filtered if r.get("status") == status]
            patient = qs.get("patient", [None])[0]
            if patient:
                filtered = [r for r in filtered if _subject_id(r) == patient]
        self._send_json(200, _bundle(filtered))

    def do_POST(self) -> None:
        # $acknowledge and anything else -- accept, no-op.
        self._send_json(200, {})

    def do_PATCH(self) -> None:
        # Fixture server: writes are accepted and echoed but not persisted.
        self._send_json(200, {})

    def do_PUT(self) -> None:
        self._send_json(200, {})

    def log_message(self, format: str, *args) -> None:
        pass  # keep container logs quiet; this is fixture noise, not signal


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "9000"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.serve_forever()
