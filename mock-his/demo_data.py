"""Carer Demo Hospital — generated operational data for the mock HIS.

Billing / invoices / claims / payments, appointments + doctor slots, lab (orders,
results, samples, analyzers, QC, rules), pharmacy (orders, inventory, logs, rules),
staffing (roster + staff) and OT (rooms, status, schedule, surgeries, equipment).

Stdlib only, like app.py. Ids are deterministic (uuid5) and every date is relative to
*today*, so the data never goes stale: app.py builds it at startup, and

    python demo_data.py --sql

prints the matching Postgres rows (the hospilot.* Hasura mirror some agents query
directly) for the same ids, to pipe into psql.
"""
import json
import math
import random
import sys
import uuid
from datetime import date, datetime, time, timedelta, timezone

NS = uuid.UUID("6f1c2a52-6a8e-4c56-9a7e-3b0f6d1e2c10")
ORG_ID = "cc72cc05-a57b-4dd9-86ee-1b8f88c3d31c"   # Carer Demo Hospital


def uid(kind: str, key) -> str:
    return str(uuid.uuid5(NS, f"{kind}:{key}"))


def patient_token(legacy: str) -> str:
    """Stable UUID token for a patient (the DB's patients.id)."""
    return uid("patient", legacy)


# ── patients ─────────────────────────────────────────────────────────────────
# The 9 inpatients already admitted in fixtures.json / sync_fixtures.json, by bed.
INPATIENTS = [
    ("pt-demo-001", "adm-bed-icu-02", "ICU", "Rajesh", "Kumar", "male", "1958-03-14"),
    ("pt-demo-002", "adm-bed-icu-04", "ICU", "Lakshmi", "Narayanan", "female", "1949-11-02"),
    ("pt-demo-003", "adm-bed-pcu-02", "PCU", "Arjun", "Mehta", "male", "1971-06-21"),
    ("pt-demo-004", "adm-bed-er-02", "Emergency", "Fatima", "Sheikh", "female", "1990-01-30"),
    ("pt-demo-005", "adm-bed-gen-02", "General Ward A", "Suresh", "Iyer", "male", "1965-09-09"),
    ("pt-demo-006", "adm-bed-gen-04", "General Ward B", "Priya", "Sharma", "female", "1982-04-17"),
    ("pt-demo-007", "adm-bed-gen-06", "General Ward B", "Mohammed", "Rafiq", "male", "1976-12-05"),
    ("pt-demo-008", "adm-bed-prv-02", "Private", "Ananya", "Reddy", "female", "1995-08-23"),
    ("pt-demo-009", "adm-bed-prv-04", "Private", "Vikram", "Singh", "male", "1960-02-11"),
]
OUTPATIENT_NAMES = [
    ("Neha", "Gupta", "female"), ("Rahul", "Verma", "male"), ("Kavya", "Nair", "female"),
    ("Amit", "Joshi", "male"), ("Sneha", "Patil", "female"), ("Imran", "Khan", "male"),
    ("Divya", "Menon", "female"), ("Karthik", "Rao", "male"), ("Pooja", "Desai", "female"),
    ("Sanjay", "Pillai", "male"), ("Meera", "Krishnan", "female"), ("Rohan", "Kapoor", "male"),
    ("Aisha", "Siddiqui", "female"), ("Deepak", "Chauhan", "male"), ("Ritu", "Bansal", "female"),
]

DOCTORS = [
    ("Dr. Anil Kapoor", "Cardiology", "dept-cardio"),
    ("Dr. Sunita Rao", "General Medicine", "dept-gen"),
    ("Dr. Farhan Ali", "Orthopedics", "dept-ortho"),
    ("Dr. Meenakshi Iyer", "Pediatrics", "dept-peds"),
    ("Dr. Rohit Malhotra", "Neurology", "dept-neuro"),
    ("Dr. Kavita Shah", "Gynecology", "dept-gyn"),
    ("Dr. Vivek Menon", "General Surgery", "dept-surg"),
    ("Dr. Nandini Bose", "Dermatology", "dept-derm"),
]
SURGEONS = [d for d in DOCTORS if d[1] in ("General Surgery", "Orthopedics", "Cardiology", "Neurology")]

DEPARTMENTS = [
    ("dept-icu", "Intensive Care Unit", "Clinical", 4, 85),
    ("dept-pcu", "Progressive Care Unit", "Clinical", 3, 85),
    ("dept-er", "Emergency", "Clinical", 3, 80),
    ("dept-gen", "General Medicine", "Clinical", 6, 85),
    ("dept-surg", "General Surgery", "Clinical", 4, 80),
    ("dept-cardio", "Cardiology", "Clinical", 0, 0),
    ("dept-ortho", "Orthopedics", "Clinical", 0, 0),
    ("dept-peds", "Pediatrics", "Clinical", 0, 0),
    ("dept-neuro", "Neurology", "Clinical", 0, 0),
    ("dept-gyn", "Gynecology", "Clinical", 0, 0),
    ("dept-derm", "Dermatology", "Clinical", 0, 0),
    ("dept-lab", "Laboratory", "Diagnostic", 0, 0),
    ("dept-pharm", "Pharmacy", "Support", 0, 0),
]

LAB_TESTS = {  # code: (name, unit, low, high, crit_low, crit_high, specimen)
    "718-7": ("Hemoglobin", "g/dL", 12.0, 16.0, 7.0, 20.0, "Blood"),
    "6690-2": ("WBC count", "10^3/uL", 4.0, 11.0, 2.0, 30.0, "Blood"),
    "2823-3": ("Potassium", "mmol/L", 3.5, 5.1, 2.8, 6.2, "Serum"),
    "2951-2": ("Sodium", "mmol/L", 135.0, 145.0, 120.0, 160.0, "Serum"),
    "2160-0": ("Creatinine", "mg/dL", 0.6, 1.2, None, 5.0, "Serum"),
    "10839-9": ("Troponin I", "ng/mL", 0.0, 0.04, None, 0.5, "Serum"),
    "2345-7": ("Glucose", "mg/dL", 70.0, 140.0, 40.0, 450.0, "Serum"),
    "2524-7": ("Lactate", "mmol/L", 0.5, 2.2, None, 4.0, "Blood"),
    "6301-6": ("INR", "", 0.8, 1.2, None, 5.0, "Blood"),
    "1988-5": ("CRP", "mg/L", 0.0, 10.0, None, None, "Serum"),
}


def build(today: date | None = None) -> dict:
    """Generate the whole dataset. Same `today` -> identical output."""
    rnd = random.Random(42)
    now = datetime.now(timezone.utc).replace(microsecond=0)
    today = today or now.date()

    def at(day_offset: int, hh: int, mm: int = 0) -> datetime:
        return datetime.combine(today + timedelta(days=day_offset), time(hh, mm), tzinfo=timezone.utc)

    def ago(minutes: float) -> datetime:
        return now - timedelta(minutes=minutes)

    def iso(v):
        return v.isoformat() if v is not None else None

    def money(x: float) -> float:
        return round(x, 2)

    # ── patients ──────────────────────────────────────────────────────────────
    patients = []
    for i, (legacy, adm, ward, first, last, gender, dob) in enumerate(INPATIENTS, 1):
        patients.append({
            "id": patient_token(legacy), "first_name": first, "last_name": last,
            "uhid": f"CDH-{100200 + i}", "gender": gender, "dob": dob,
            "phone": f"+9198{rnd.randint(10000000, 99999999)}", "admission_id": adm, "ward": ward,
            "inpatient": True,
        })
    for i, (first, last, gender) in enumerate(OUTPATIENT_NAMES, 1):
        patients.append({
            "id": patient_token(f"op-{i:03d}"), "first_name": first, "last_name": last,
            "uhid": f"CDH-{100300 + i}", "gender": gender,
            "dob": f"{rnd.randint(1955, 2015)}-{rnd.randint(1, 12):02d}-{rnd.randint(1, 28):02d}",
            "phone": f"+9197{rnd.randint(10000000, 99999999)}", "admission_id": None, "ward": None,
            "inpatient": False,
        })
    inpatients = [p for p in patients if p["inpatient"]]
    outpatients = [p for p in patients if not p["inpatient"]]

    def full_name(p):
        return f"{p['first_name']} {p['last_name']}"

    doctors = [{"id": uid("doctor", n), "name": n, "specialization": s, "department_key": d}
               for n, s, d in DOCTORS]
    dept_rows = [{"id": k, "name": n, "type": t, "capacity": c, "target_occupancy_pct": o}
                 for k, n, t, c, o in DEPARTMENTS]
    dept_name = {k: n for k, n, *_ in DEPARTMENTS}

    # ── insurance contracts + rates ──────────────────────────────────────────
    contract_specs = [
        ("Star Health Insurance", "Medi Assist TPA", "Cashless", 0.08, 18),
        ("ICICI Lombard", "Paramount Health Services", "Cashless", 0.12, 24),
        ("HDFC ERGO", "MD India Health", "Cashless", 0.06, 15),
        ("CGHS", "CGHS Bengaluru", "Government", 0.15, 45),
        ("Infosys Ltd (Corporate)", "Self-administered", "Corporate", 0.03, 30),
    ]
    contracts = []
    for i, (ins, tpa, ctype, rej, days) in enumerate(contract_specs, 1):
        contracts.append({
            "id": uid("contract", i), "insurer_name": ins, "tpa_name": tpa, "contract_type": ctype,
            "contract_number": f"CDH-CT-{2024 + i % 2}-{i:03d}",
            "start_date": iso(today - timedelta(days=300 + 30 * i)),
            "end_date": iso(today + timedelta(days=65 + 40 * i)),
            "status": "Active", "branch_id": None, "total_claims": rnd.randint(40, 260),
            "approved_amount": money(rnd.uniform(2e6, 9e6)), "rejection_rate": rej,
            "avg_settlement_days": days,
        })
    services = [
        ("SVC-ICU-BED", "ICU bed charges (per day)", 18000), ("SVC-GW-BED", "General ward bed (per day)", 3500),
        ("SVC-PVT-BED", "Private room (per day)", 7500), ("SVC-CONSULT", "Specialist consultation", 1200),
        ("SVC-CBC", "Complete blood count", 450), ("SVC-MRI-BR", "MRI brain", 9500),
        ("SVC-APPX", "Laparoscopic appendectomy package", 95000), ("SVC-ECHO", "2D echocardiography", 3200),
    ]
    contract_rates = []
    for c in contracts:
        disc = {"Government": 0.30, "Corporate": 0.15}.get(c["contract_type"], 0.10)
        for code, name, rate in services:
            contract_rates.append({
                "id": uid("rate", f"{c['id']}:{code}"), "contract_id": c["id"], "service_id": uid("service", code),
                "service_code": code, "service_name": name, "contract_rate": money(rate * (1 - disc)),
                "hospital_rate": rate, "discount_percentage": disc * 100, "is_active": True,
            })

    # ── invoices, line items, payments ───────────────────────────────────────
    invoices, invoice_lines, payments, payment_entries, refunds = [], [], [], [], []
    inv_no = 1
    visit_of = {p["id"]: uid("visit", p["id"]) for p in patients}
    contract_of = {}
    for i, p in enumerate(inpatients):
        contract_of[p["id"]] = contracts[i % 4]["id"] if i % 5 != 4 else None  # some self-pay

    def add_invoice(p, itype, day_off, lines, payment_status, contract_id=None, notes=None):
        nonlocal inv_no
        inv_id = uid("invoice", inv_no)
        subtotal = sum(q * r for _, _, q, r in lines)
        discount = money(subtotal * (0.05 if contract_id else 0))
        gst_rate = 5.0 if itype == "Pharmacy" else 0.0
        gst = money((subtotal - discount) * gst_rate / 100)
        total = money(subtotal - discount + gst)
        paid = {"Paid": total, "Unpaid": 0.0, "Partial": money(total * rnd.choice([0.3, 0.4, 0.5]))}[payment_status]
        inv_date = at(day_off, 10) + timedelta(minutes=rnd.randint(0, 400))
        invoices.append({
            "id": inv_id, "org_id": ORG_ID, "invoice_number": f"INV-{today.year}-{inv_no:05d}",
            "patient_id": p["id"], "patient_name": full_name(p), "uhid": p["uhid"],
            "invoice_date": iso(inv_date), "due_date": iso(inv_date + timedelta(days=15 if contract_id else 7)),
            "invoice_type": itype, "visit_id": visit_of[p["id"]], "admission_id": None,
            "package_id": None, "insurance_contract_id": contract_id,
            "subtotal": money(subtotal), "discount_amount": discount,
            "discount_percentage": 5.0 if contract_id else 0.0, "gst_amount": gst,
            "cgst_amount": money(gst / 2), "sgst_amount": money(gst / 2), "igst_amount": 0.0,
            "grand_total": total, "paid_amount": paid, "balance": money(total - paid),
            "status": "Finalized" if itype != "IPD" else "Interim", "payment_status": payment_status,
            "is_inter_state": False, "notes": notes, "created_by": None, "updated_by": None,
            "cancelled_by": None, "cancelled_at": None, "cancellation_reason": None, "branch_id": None,
            "created_at": iso(inv_date), "updated_at": iso(inv_date + timedelta(hours=2)),
        })
        for j, (code, name, q, r) in enumerate(lines, 1):
            amt = money(q * r)
            invoice_lines.append({
                "id": uid("inv_line", f"{inv_no}:{j}"), "invoice_id": inv_id, "service_id": uid("service", code),
                "service_code": code, "service_name": name, "description": name, "quantity": q, "rate": r,
                "amount": amt, "total": money(amt * (1 + gst_rate / 100)), "gst_rate": gst_rate,
                "gst_amount": money(amt * gst_rate / 100), "discount_amount": 0.0,
                "source_type": itype.lower(), "source_id": None,
            })
        if paid > 0:
            pay_id = uid("payment", inv_no)
            payments.append({
                "id": pay_id, "org_id": ORG_ID, "receipt_number": f"RCPT-{today.year}-{inv_no:05d}",
                "invoice_id": inv_id, "patient_id": p["id"], "payment_date": iso(inv_date + timedelta(hours=3)),
                "total_amount": paid, "status": "Completed", "received_by": None, "notes": None,
                "branch_id": None, "created_at": iso(inv_date + timedelta(hours=3)),
                "updated_at": iso(inv_date + timedelta(hours=3)),
            })
            mode = rnd.choice(["UPI", "Card", "Cash", "UPI", "Bank Transfer"])
            payment_entries.append({
                "id": uid("pay_entry", inv_no), "payment_id": pay_id, "payment_mode": mode, "amount": paid,
                "transaction_reference": f"TXN{rnd.randint(10**9, 10**10 - 1)}" if mode != "Cash" else None,
                "bank_name": "HDFC Bank" if mode == "Bank Transfer" else None,
                "card_last_four": f"{rnd.randint(1000, 9999)}" if mode == "Card" else None,
                "created_at": iso(inv_date + timedelta(hours=3)),
            })
        inv_no += 1
        return invoices[-1]

    los = {}
    for i, p in enumerate(inpatients):
        days = rnd.randint(2, 7)
        los[p["id"]] = days
        bed = {"ICU": ("SVC-ICU-BED", "ICU bed charges (per day)", 18000),
               "Private": ("SVC-PVT-BED", "Private room (per day)", 7500)}.get(
            p["ward"], ("SVC-GW-BED", "General ward bed (per day)", 3500))
        lines = [(bed[0], bed[1], days, bed[2]), ("SVC-CONSULT", "Specialist consultation", days, 1200),
                 ("SVC-CBC", "Complete blood count", rnd.randint(1, 3), 450)]
        if p["ward"] in ("ICU", "PCU"):
            lines.append(("SVC-ECHO", "2D echocardiography", 1, 3200))
        status = ["Unpaid", "Partial", "Unpaid", "Partial", "Unpaid", "Unpaid", "Partial", "Partial", "Unpaid"][i]
        add_invoice(p, "IPD", -1, lines, status, contract_of[p["id"]], notes="Interim bill — admission ongoing")
        add_invoice(p, "Pharmacy", 0, [("PHM-IPD", "Inpatient medications", 1, rnd.randint(2500, 14000))],
                    rnd.choice(["Unpaid", "Paid"]), contract_of[p["id"]])
    for i, p in enumerate(outpatients):
        lines = [("SVC-CONSULT", "Specialist consultation", 1, 1200)]
        if i % 3 == 0:
            lines.append(("SVC-CBC", "Complete blood count", 1, 450))
        if i % 5 == 0:
            lines.append(("SVC-MRI-BR", "MRI brain", 1, 9500))
        status = "Paid" if i % 4 else rnd.choice(["Unpaid", "Partial"])
        add_invoice(p, "OPD", -rnd.randint(0, 20), lines, status)
    # a leakage case: discharged-yesterday style invoice still unpaid well past due
    add_invoice(outpatients[2], "IPD", -34, [("SVC-APPX", "Laparoscopic appendectomy package", 1, 95000)],
                "Unpaid", contracts[1]["id"], notes="Package bill — pending TPA settlement")
    paid_inv = next(v for v in invoices if v["payment_status"] == "Paid" and v["invoice_type"] == "OPD")
    refunds.append({
        "id": uid("refund", 1), "invoice_id": paid_inv["id"],
        "payment_id": next(p["id"] for p in payments if p["invoice_id"] == paid_inv["id"]),
        "refund_amount": 450.0, "reason": "Duplicate CBC charge", "status": "Processed",
        "refund_date": iso(at(-2, 15)), "refund_mode": "UPI", "refund_number": f"RF-{today.year}-0001",
        "created_at": iso(at(-2, 14)),
    })

    # ── claims ───────────────────────────────────────────────────────────────
    claim_specs = [  # status, stage, risk, compliance, denial
        ("Submitted", "Submission", "low", "compliant", None),
        ("Under Review", "Adjudication", "medium", "compliant", None),
        ("Query Raised", "Adjudication", "high", "missing_documents", None),
        ("Approved", "Settlement", "low", "compliant", None),
        ("Partially Approved", "Settlement", "medium", "compliant", None),
        ("Denied", "Closed", "high", "coding_mismatch", "Diagnosis code does not support ICU admission"),
        ("Draft", "Pre-Auth", "medium", "missing_documents", None),
        ("Settled", "Closed", "low", "compliant", None),
    ]
    icd = ["I21.4", "J18.9", "N17.9", "K35.80", "E11.65", "I63.9", "S72.001A", "A41.9"]
    claims, claim_lines, claim_history, claim_queries = [], [], [], []
    insured = [v for v in invoices if v["insurance_contract_id"] and v["invoice_type"] == "IPD"]
    for n, inv in enumerate(insured):
        status, stage, risk, compliance, denial = claim_specs[n % len(claim_specs)]
        c = next(c for c in contracts if c["id"] == inv["insurance_contract_id"])
        cid = uid("claim", n)
        amt = inv["grand_total"]
        approved = {"Approved": amt, "Settled": amt, "Partially Approved": money(amt * 0.72)}.get(status)
        created = datetime.fromisoformat(inv["invoice_date"]) - timedelta(days=1)
        claims.append({
            "id": cid, "patient_token": inv["patient_id"], "patient_id": inv["patient_id"], "visit_id": inv["visit_id"],
            "tpa_id": uid("tpa", c["tpa_name"]), "tpa_name": c["tpa_name"], "claim_amount": amt,
            "status": status, "created_at": iso(created),
            "submitted_date": iso(created + timedelta(hours=6)) if status != "Draft" else None,
            "approved_amount": approved, "denial_reason": denial,
            "claim_number": f"CLM-{today.year}-{n + 1:05d}",
            "payer_type": {"Government": "Government", "Corporate": "Corporate"}.get(c["contract_type"], "Insurance"),
            "risk_level": risk, "risk_score": {"low": 0.18, "medium": 0.47, "high": 0.82}[risk] + n * 0.01,
            "stage": stage, "compliance_status": compliance, "diagnosis_code": icd[n % len(icd)],
            "branch_id": None, "insurer_name": c["insurer_name"], "invoice_id": inv["id"],
        })
        for j, li in enumerate(l for l in invoice_lines if l["invoice_id"] == inv["id"]):
            ok = status in ("Approved", "Settled") or (status == "Partially Approved" and j == 0)
            claim_lines.append({
                "id": uid("claim_line", f"{n}:{j}"), "claim_id": cid, "service_code": li["service_code"],
                "service_name": li["service_name"], "description": li["description"],
                "quantity": li["quantity"], "rate": li["rate"], "amount": li["amount"],
                "approved_amount": li["amount"] if ok else None, "approved_quantity": li["quantity"] if ok else None,
                "approved_rate": li["rate"] if ok else None,
                "status": "Approved" if ok else ("Rejected" if status == "Denied" else "Pending"),
                "category": "Room" if "bed" in li["service_name"].lower() else "Services", "unit": "unit",
                "rejection_reason": "Not covered under policy" if status == "Denied" else None,
            })
        trail = ["Draft", "Submitted", "Under Review", status]
        trail = trail[:trail.index(status) + 1] if status in trail[:3] else trail
        for k in range(1, len(trail)):
            claim_history.append({
                "id": uid("claim_hist", f"{n}:{k}"), "claim_id": cid, "from_status": trail[k - 1],
                "to_status": trail[k], "action": f"Moved to {trail[k]}",
                "changed_at": iso(created + timedelta(hours=6 * k)), "changed_by": "billing.desk",
                "remarks": denial if trail[k] == "Denied" else None,
            })
        if status == "Query Raised":
            claim_queries.append({
                "id": uid("claim_query", n), "claim_id": cid, "query_type": "Documentation",
                "query_text": "Please submit the discharge summary and ICU admission justification notes.",
                "status": "Open", "raised_at": iso(ago(60 * 26)), "raised_by": c["tpa_name"],
                "responded_by": None, "response_date": None, "response_text": None,
                "created_at": iso(ago(60 * 26)),
            })

    # Leakage + duplicate cases: day-care claims raised with no invoice behind them,
    # and the same pending claim submitted twice.
    extra = [  # patient idx, claim status, amount, contract idx, visit key, note
        (16, "Submitted", 42500.0, 0, "daycare-1", "Day-care cataract surgery — no invoice raised"),
        (19, "Under Review", 18750.0, 2, "daycare-2", "Day-care endoscopy — no invoice raised"),
        (5, "Pending", 6800.0, 1, None, "Duplicate submission"),
        (5, "Pending", 6800.0, 1, None, "Duplicate submission"),
    ]
    for k, (pidx, status, amt, ci, vkey, note) in enumerate(extra):
        p, c = patients[pidx], contracts[ci]
        n = len(claims)
        claims.append({
            "id": uid("claim", n), "patient_token": p["id"], "patient_id": p["id"],
            "visit_id": uid("visit", vkey) if vkey else visit_of[p["id"]],
            "tpa_id": uid("tpa", c["tpa_name"]), "tpa_name": c["tpa_name"], "claim_amount": amt,
            "status": status, "created_at": iso(ago(60 * (30 + k * 7))), "submitted_date": iso(ago(60 * (28 + k * 7))),
            "approved_amount": None, "denial_reason": None, "claim_number": f"CLM-{today.year}-{n + 1:05d}",
            "payer_type": "Insurance", "risk_level": "medium", "risk_score": 0.5, "stage": "Submission",
            "compliance_status": "missing_documents" if vkey else "compliant", "diagnosis_code": icd[k],
            "branch_id": None, "insurer_name": c["insurer_name"], "invoice_id": None, "notes": note,
        })

    today_payments = [p for p in payments if p["payment_date"][:10] == today.isoformat()]
    by_mode = {m: 0.0 for m in ("Cash", "UPI", "Card", "Bank Transfer")}
    for e in payment_entries:
        if e["created_at"][:10] == today.isoformat():
            by_mode[e["payment_mode"]] += e["amount"]
    total_today = money(sum(by_mode.values()))
    collections = {
        "id": uid("collection", today), "org_id": ORG_ID, "collection_date": iso(today),
        "cash_total": money(by_mode["Cash"]), "upi_total": money(by_mode["UPI"]),
        "card_total": money(by_mode["Card"]), "bank_transfer_total": money(by_mode["Bank Transfer"]),
        "cheque_total": 0.0, "total_collection": total_today,
        "invoice_count": len({v["id"] for v in invoices if v["invoice_date"][:10] == today.isoformat()}),
        "payment_count": len(today_payments), "is_reconciled": False, "reconciled_by": None,
        "reconciled_at": None, "variance": 0.0, "created_at": iso(now), "updated_at": iso(now),
    }
    reconciliation = {
        "id": uid("recon", today), "reconciliation_date": iso(today), "total_expected": total_today,
        "total_actual": money(total_today - 1200), "total_variance": -1200.0,
        "actual_cash": money(by_mode["Cash"] - 1200), "actual_card": money(by_mode["Card"]),
        "actual_upi": money(by_mode["UPI"]), "actual_bank": money(by_mode["Bank Transfer"]),
        "cash_variance": -1200.0, "card_variance": 0.0, "upi_variance": 0.0, "bank_variance": 0.0,
        "status": "Pending", "created_at": iso(now),
    }

    # ── appointments, doctor slots, waitlist, service slots ──────────────────
    doctor_slots, appointments = [], []
    for d_off in range(0, 7):
        day = today + timedelta(days=d_off)
        if day.weekday() == 6:
            continue
        for k, doc in enumerate(doctors):
            for sess, (start, end, cap) in enumerate([(9, 13, 12), (17, 19, 6)]):
                if sess == 1 and k % 2:
                    continue
                booked = min(cap, rnd.randint(2, cap + 3) if d_off < 2 else rnd.randint(0, cap - 2))
                doctor_slots.append({
                    "id": uid("slot", f"{doc['id']}:{day}:{sess}"), "provider_id": doc["id"],
                    "provider_name": doc["name"], "slot_date": iso(day),
                    "slot_start": f"{start:02d}:00:00", "slot_end": f"{end:02d}:00:00",
                    "slot_type": "teleconsult" if sess == 1 and k % 3 == 0 else "consultation",
                    "status": "full" if booked >= cap else "open", "max_patients": cap,
                    "booked_count": booked, "specialization": doc["specialization"],
                })
    for n in range(48):
        d_off = rnd.randint(-3, 5)
        doc = doctors[n % len(doctors)]
        p = outpatients[n % len(outpatients)] if n % 6 else inpatients[n % len(inpatients)]
        when = at(d_off, rnd.choice([9, 10, 11, 12, 17, 18]), rnd.choice([0, 15, 30, 45]))
        if d_off < 0:
            status = rnd.choice(["Completed", "Completed", "Completed", "No Show", "Cancelled"])
        elif d_off == 0:
            status = ("Completed" if when < now else "Scheduled") if n % 7 else "Checked In"
        else:
            status = "Cancelled" if n % 9 == 0 else "Scheduled"
        appointments.append({
            "id": uid("appointment", n), "patient_id": p["id"], "provider_id": doc["id"],
            "provider_name": doc["name"], "department_id": uid("dept", doc["department_key"]),
            "appointment_time": when.replace(tzinfo=None).isoformat(), "status": status,
            "type": rnd.choice(["New", "Follow-up", "Follow-up", "Teleconsult"]),
            "patient_name": full_name(p), "phone": p["phone"],
            "email": f"{p['first_name'].lower()}.{p['last_name'].lower()}@example.com",
            "specialization": doc["specialization"], "department_name": dept_name[doc["department_key"]],
        })
    waitlist = []
    for n, (spec, pri, reason) in enumerate([
        ("Cardiology", "High", "Chest discomfort on exertion — earliest slot requested"),
        ("Neurology", "High", "Recurring migraines with aura"),
        ("Orthopedics", "Medium", "Knee pain follow-up after MRI"),
        ("Dermatology", "Low", "Routine skin check"),
        ("Pediatrics", "Medium", "Vaccination catch-up"),
        ("Cardiology", "Medium", "Post-discharge review"),
    ]):
        p = outpatients[(n * 2 + 1) % len(outpatients)]
        waitlist.append({
            "id": uid("waitlist", n), "patient_id": p["id"], "patient_name": full_name(p),
            "phone": p["phone"], "email": f"{p['first_name'].lower()}@example.com", "specialization": spec,
            "priority": pri, "requested_date": iso(today + timedelta(days=n % 3)), "status": "waitlisted",
            "reason": reason, "created_at": iso(ago(60 * (20 + n * 9))),
        })
    service_slots = []
    for d_off in (0, 1):
        for hh in range(7, 13):
            for stype, loc in (("sample_collection", "Lab Collection Centre, Ground Floor"),
                               ("pharmacy_pickup", "OPD Pharmacy Counter 2")):
                cap = 10 if stype == "sample_collection" else 15
                booked = min(cap, rnd.randint(0, cap + 2))
                service_slots.append({
                    "id": uid("service_slot", f"{stype}:{d_off}:{hh}"), "slot_type": stype,
                    "slot_date": iso(today + timedelta(days=d_off)), "slot_start": f"{hh:02d}:00:00",
                    "slot_end": f"{hh + 1:02d}:00:00", "location": loc, "specialization": None,
                    "max_patients": cap, "booked_count": booked, "status": "full" if booked >= cap else "open",
                })

    # ── staffing ─────────────────────────────────────────────────────────────
    areas = [("icu", "ICU", 4), ("pcu", "PCU", 3), ("er", "Emergency", 3), ("gwa", "General Ward A", 3),
             ("gwb", "General Ward B", 3), ("private", "Private Ward", 3), ("ot", "Operating Theatres", 4)]
    roster = []
    short = {("icu", "Night"), ("er", "Day"), ("er", "Evening"), ("gwb", "Night"), ("pcu", "Day")}
    for area, label, beds in areas:
        for shift in ("Day", "Evening", "Night"):
            for role in (("Nurse", "Doctor") if area in ("icu", "er", "ot") else ("Nurse",)):
                load = {"ot": 7}.get(area, beds + rnd.randint(1, 4)) if role == "Nurse" else beds + 3
                if area == "er":
                    load += {"Day": 6, "Evening": 9, "Night": 4}[shift]
                ratio = 2 if area == "icu" and role == "Nurse" else 4 if role == "Nurse" else 8
                ideal = max(1, math.ceil(load / ratio))
                head = max(1, ideal - 1) if (area, shift) in short and role == "Nurse" else ideal
                roster.append({
                    "id": uid("roster", f"{area}:{shift}:{role}"), "area": area, "area_label": label,
                    "role": role, "shift": shift, "headcount": head, "assigned_load": load,
                    "load_per_staff": ratio, "branch_id": None,
                })
    first = ["Asha", "Bindu", "Chitra", "Deepa", "Elsa", "Gita", "Hema", "Jaya", "Kiran", "Lata", "Manju",
             "Nisha", "Omana", "Preeti", "Rani", "Sheela", "Tara", "Usha", "Vani", "Yamuna", "Joseph",
             "Rajan", "Thomas", "Ravi", "Sunil", "Abdul", "George", "Prakash", "Anand", "Biju"]
    staff = []
    for n, nm in enumerate(first):
        area, label, _ = areas[n % len(areas)]
        status = "on_duty" if n % 5 else rnd.choice(["off_duty", "on_leave", "float_pool"])
        hours = rnd.randint(30, 58)
        staff.append({
            "id": uid("staff", n), "name": f"{nm} {rnd.choice(['K', 'M', 'P', 'S', 'R', 'T'])}.",
            "role": "Staff Nurse" if n < 24 else "Ward Technician", "area": area, "area_label": label,
            "department": label, "shift": ("Day", "Evening", "Night")[n % 3], "status": status,
            "hours_this_week": hours, "overtime_hours": max(0, hours - 48),
            "skills": ["ACLS", "Ventilator care"] if area == "icu" else ["BLS"],
            "is_float_pool": status == "float_pool",
        })

    # ── operating theatres ───────────────────────────────────────────────────
    rooms = []
    for n, (rtype, status) in enumerate([("General", "In Use"), ("Orthopedic", "Cleaning"),
                                         ("Cardiac", "Available"), ("Neuro", "Available")], 1):
        rooms.append({
            "id": uid("ot_room", n), "room_code": f"OT-{n}", "room_name": f"Main OT {n} ({rtype})",
            "room_type": rtype, "status": status, "is_active": True, "floor": "2",
        })
    room_by_type = {r["room_type"]: r for r in rooms}
    surgery_specs = [  # day, room type, start, dur min, name, priority, patient idx, status
        (0, "General", (8, 0), 90, "Laparoscopic cholecystectomy", "elective", 4, "Completed"),
        (0, "General", (10, 0), 120, "Exploratory laparotomy", "urgent", 6, "In Progress"),
        (0, "General", (12, 30), 60, "Inguinal hernia repair", "elective", 10, "Scheduled"),
        (0, "Orthopedic", (8, 30), 150, "Total knee replacement", "elective", 8, "Completed"),
        (0, "Orthopedic", (13, 0), 120, "ORIF distal radius", "urgent", 13, "Scheduled"),
        (0, "Orthopedic", (14, 30), 90, "Arthroscopic ACL repair", "elective", 14, "Scheduled"),  # overlaps
        (0, "Cardiac", (15, 0), 180, "CABG x3", "elective", 2, "Scheduled"),
        (0, "Neuro", (16, 0), 60, "Emergency burr-hole evacuation", "emergency", 0, "Scheduled"),
        (1, "General", (9, 0), 75, "Laparoscopic appendectomy", "urgent", 11, "Scheduled"),
        (1, "Orthopedic", (9, 0), 120, "Hip hemiarthroplasty", "elective", 5, "Scheduled"),
        (1, "Cardiac", (10, 0), 150, "Mitral valve repair", "elective", 12, "Scheduled"),
        (1, "Neuro", (11, 0), 180, "Lumbar laminectomy", "elective", 15, "Scheduled"),
    ]
    surgeon_for = {"General": SURGEONS[2], "Orthopedic": SURGEONS[1], "Cardiac": SURGEONS[0], "Neuro": SURGEONS[3]}
    schedule, surgeries, equipment = [], [], []
    for n, (d_off, rtype, (hh, mm), dur, name, pri, pidx, status) in enumerate(surgery_specs, 1):
        room = room_by_type[rtype]
        start = at(d_off, hh, mm)
        end = start + timedelta(minutes=dur)
        if status == "In Progress":
            end += timedelta(minutes=40)   # running long -> delay risk
        sname, sspec, _ = surgeon_for[rtype]
        if n == 11:                         # same surgeon double-booked tomorrow
            sname = surgeon_for["Neuro"][0]
        p = patients[pidx]
        sid = uid("surgery", n)
        row = {
            "id": sid, "surgery_id": sid, "surgery_code": f"SRG-{1000 + n}",
            "surgery_name": name, "surgery_type": pri, "priority": pri, "urgency": pri,
            "room_id": room["id"], "room_code": room["room_code"], "room_type": rtype,
            "scheduled_date": iso(start.date()), "scheduled_start_time": start.strftime("%H:%M"),
            "scheduled_end_time": end.strftime("%H:%M"), "estimated_duration_minutes": dur,
            "surgeon_id": uid("doctor", sname), "surgeon_name": sname,
            "anesthetist_name": rnd.choice(["Dr. Rekha Pillai", "Dr. Sameer Joshi"]),
            "patient_token": p["id"], "admission_id": p["admission_id"], "ward": p["ward"] or "Day Care",
            "status": status,
        }
        schedule.append(row)
        surgeries.append({
            "id": sid, "admission_id": p["admission_id"], "patient_token": p["id"], "ward": row["ward"],
            "status": status, "created_at": iso(start - timedelta(days=2)), "surgery_name": name,
            "surgery_code": row["surgery_code"], "priority": pri, "surgery_type": pri,
        })
        if d_off == 0:
            for e, (ename, estat) in enumerate([("Laparoscopy tower", "reserved"), ("C-arm fluoroscope", "in_use"),
                                                ("Cardiac bypass machine", "reserved")][: 1 + n % 3]):
                equipment.append({
                    "id": uid("ot_equip", f"{n}:{e}"), "surgery_id": sid, "equipment_name": ename,
                    "equipment_code": f"EQ-{100 + e}", "status": "sterilizing" if n == 5 and e == 0 else estat,
                    "quantity": 1,
                })
    room_status = []
    for room in rooms:
        live = next((s for s in schedule if s["room_code"] == room["room_code"] and s["status"] == "In Progress"), None)
        nxt = next((s for s in schedule if s["room_code"] == room["room_code"] and s["status"] == "Scheduled"), None)
        room_status.append({
            "id": uid("ot_room_status", room["room_code"]), "room_id": room["id"], "room_code": room["room_code"],
            "room_name": room["room_name"], "status": room["status"],
            "surgery_status": "In Progress" if live else ("Turnover" if room["status"] == "Cleaning" else "Idle"),
            "current_surgery_id": live["surgery_id"] if live else None,
            "current_surgery_name": live["surgery_name"] if live else None,
            "scheduled_end_time": live["scheduled_end_time"] if live else None,
            "next_surgery_code": nxt["surgery_code"] if nxt else None,
            "last_cleaned_at": iso(ago(rnd.randint(20, 300))),
        })

    # ── laboratory ───────────────────────────────────────────────────────────
    analyzers = []
    for n, (name, model, mfr, status, load, backup, tests) in enumerate([
        ("Sysmex XN-1000 Hematology", "XN-1000", "Sysmex", "online", 78, False, ["718-7", "6690-2"]),
        ("Roche cobas c311 Chemistry", "c311", "Roche", "online", 91, False, ["2823-3", "2951-2", "2160-0", "2345-7", "1988-5"]),
        ("Abbott Architect i1000SR", "i1000SR", "Abbott", "online", 54, False, ["10839-9"]),
        ("Radiometer ABL90 Flex", "ABL90", "Radiometer", "maintenance", 0, False, ["2524-7", "2823-3", "2951-2"]),
        ("Sysmex CA-600 Coagulation", "CA-600", "Sysmex", "online", 22, True, ["6301-6"]),
    ], 1):
        analyzers.append({
            "id": uid("analyzer", n), "name": name, "model": model, "manufacturer": mfr, "status": status,
            "location_id": "dept-lab", "current_load_pct": load, "is_backup": backup, "validated_tests": tests,
            "next_maintenance_at": iso(now + timedelta(days=n * 3 - 2) if status != "maintenance" else now + timedelta(hours=3)),
        })
    lab_orders, lab_results, lab_samples = [], [], []
    order_specs = [  # patient idx, test code, priority, status, minutes ago, result value
        (0, "2823-3", "stat", "completed", 95, 6.8), (0, "2524-7", "stat", "active", 25, None),
        (1, "6690-2", "urgent", "completed", 300, 17.2), (1, "6301-6", "routine", "active", 140, None),
        (2, "10839-9", "stat", "completed", 70, 2.1), (2, "2160-0", "routine", "completed", 420, 1.9),
        (3, "718-7", "urgent", "active", 55, None), (3, "2345-7", "urgent", "completed", 180, 312),
        (4, "2951-2", "routine", "completed", 600, 131), (4, "1988-5", "routine", "active", 210, None),
        (5, "718-7", "routine", "completed", 380, 13.4), (6, "2160-0", "routine", "on-hold", 260, None),
        (7, "6690-2", "routine", "active", 90, None), (8, "2345-7", "routine", "completed", 500, 104),
        (9, "718-7", "routine", "active", 35, None), (11, "1988-5", "routine", "completed", 720, 4.0),
        (13, "6690-2", "urgent", "active", 160, None), (14, "2823-3", "routine", "on-hold", 300, None),
    ]
    for n, (pidx, code, pri, status, mins, value) in enumerate(order_specs, 1):
        p = patients[pidx]
        status = {"active": "In Progress" if n % 3 == 0 else "Pending", "on-hold": "On Hold",
                  "completed": "Completed"}[status]
        name, unit, low, high, clow, chigh, spec = LAB_TESTS[code]
        oid = uid("lab_order", n)
        ordered = ago(mins)
        lab_orders.append({
            "id": oid, "visit_id": visit_of[p["id"]], "patient_token": p["id"], "ordered_by": doctors[n % 8]["name"],
            "status": status, "priority": pri, "ordered_at": iso(ordered),
            "completed_at": iso(ordered + timedelta(minutes=45)) if status == "Completed" else None,
            "test_name": name, "test_code": code, "department": p["ward"] or "OPD",
        })
        if value is not None:
            if (chigh is not None and value >= chigh) or (clow is not None and value <= clow):
                flag = "Critical"
            elif value > high:
                flag = "High"
            elif value < low:
                flag = "Low"
            else:
                flag = "Normal"
            lab_results.append({
                "id": uid("lab_result", n), "order_id": oid, "patient_token": p["id"], "test_name": name,
                "test_code": code, "result_value": str(value), "flag": flag,
                "reference_range": f"{low}-{high} {unit}".strip(), "unit": unit,
                "reported_at": iso(ordered + timedelta(minutes=45)),
            })
        else:
            collected = status != "On Hold" and n % 4 != 3
            lab_samples.append({
                "id": uid("lab_sample", n), "order_id": oid, "patient_token": p["id"],
                "barcode": f"CDH{today:%y%m%d}{n:04d}", "type": spec,
                "status": "available" if collected else "unavailable",
                "collected_at": iso(ordered + timedelta(minutes=10)) if collected else None,
                "received_at": iso(ordered + timedelta(minutes=30)) if collected and n % 3 else None,
                "container_type": "EDTA tube" if spec == "Blood" else "SST tube",
                "collection_status": "collected" if collected else "pending",
                "transport_status": ("delivered" if n % 3 else "delayed") if collected else "not_dispatched",
                "lab_receipt_status": "received" if collected and n % 3 else "pending",
                "is_misplaced": n == 15, "department": p["ward"] or "OPD", "priority": pri,
            })
    qc_logs = []
    for n, a in enumerate(analyzers):
        for s, shift in enumerate(("Night", "Day")):
            dev = round(rnd.uniform(0.4, 2.5), 2) if not (n == 1 and shift == "Day") else 4.6
            qc_logs.append({
                "id": uid("qc", f"{n}:{s}"), "analyzer_id": a["id"], "analyzer_name": a["name"], "shift": shift,
                "qc_level": "L2", "deviation_pct": dev,
                "qc_status": "fail" if dev > 4 else ("warning" if dev > 2 else "pass"),
                "recalibration_triggered": dev > 4, "run_at": iso(ago(60 * (14 - s * 10))),
            })
    reflex_rules = [
        {"id": uid("reflex", 1), "trigger_test": "Troponin I", "trigger_code": "10839-9", "condition": "High or Critical",
         "recommended_test": "CK-MB + repeat Troponin in 3h", "requires_physician_approval": False},
        {"id": uid("reflex", 2), "trigger_test": "Potassium", "trigger_code": "2823-3", "condition": "Critical",
         "recommended_test": "12-lead ECG + repeat Potassium", "requires_physician_approval": False},
        {"id": uid("reflex", 3), "trigger_test": "WBC count", "trigger_code": "6690-2", "condition": "High",
         "recommended_test": "Blood culture + Procalcitonin", "requires_physician_approval": True},
        {"id": uid("reflex", 4), "trigger_test": "Glucose", "trigger_code": "2345-7", "condition": "High",
         "recommended_test": "HbA1c", "requires_physician_approval": False},
        {"id": uid("reflex", 5), "trigger_test": "Creatinine", "trigger_code": "2160-0", "condition": "High",
         "recommended_test": "eGFR + Urine albumin/creatinine ratio", "requires_physician_approval": True},
    ]
    validation_rules = [
        {"id": uid("validation", code), "test_code": code, "test_name": t[0], "min_normal": t[2], "max_normal": t[3],
         "critical_low": t[4], "critical_high": t[5], "delta_pct": 25, "auto_release_on_normal": True, "unit": t[1]}
        for code, t in LAB_TESTS.items()
    ]
    lab_capacity = []
    for d in range(30, 0, -1):
        day = today - timedelta(days=d)
        vol = rnd.randint(380, 520) - (90 if day.weekday() == 6 else 0)
        lab_capacity.append({"date": iso(day), "samples_received": vol, "tests_run": int(vol * 2.6),
                             "avg_tat_minutes": rnd.randint(70, 130), "stat_tat_minutes": rnd.randint(28, 55),
                             "staff_on_duty": rnd.randint(9, 13)})
    critical_escalations = []
    for n, r in enumerate(r for r in lab_results if r["flag"] == "Critical"):
        p = next(p for p in patients if p["id"] == r["patient_token"])
        critical_escalations.append({
            "id": uid("crit_esc", n), "result_id": r["id"], "order_id": r["order_id"], "patient_token": p["id"],
            "test_name": r["test_name"], "result_value": r["result_value"], "unit": r["unit"], "flag": "Critical",
            "ward": p["ward"], "is_icu_er_patient": p["ward"] in ("ICU", "Emergency"),
            "physician_notified": True, "physician_acknowledged_at": iso(ago(40)) if n == 1 else None,
            "escalation_level": "Routine" if n == 1 else "Urgent", "action_documented": n == 1,
            "reported_at": r["reported_at"], "closed_at": None,
        })

    # ── pharmacy ─────────────────────────────────────────────────────────────
    drugs = [  # name, generic, form, stock, reorder, location, controlled
        ("Paracetamol 500mg", "Paracetamol", "Tablet", 4200, 1000, "Main Pharmacy", False),
        ("Pantoprazole 40mg IV", "Pantoprazole", "Injection", 160, 80, "Main Pharmacy", False),
        ("Ceftriaxone 1g", "Ceftriaxone", "Injection", 210, 100, "Main Pharmacy", False),
        ("Piperacillin-Tazobactam 4.5g", "Piperacillin-Tazobactam", "Injection", 0, 60, "Main Pharmacy", False),
        ("Meropenem 1g", "Meropenem", "Injection", 18, 40, "ICU Satellite", False),
        ("Heparin 5000 IU", "Heparin", "Injection", 35, 80, "ICU Satellite", False),
        ("Enoxaparin 40mg", "Enoxaparin", "Injection", 140, 60, "Main Pharmacy", False),
        ("Insulin Glargine 100 IU/ml", "Insulin glargine", "Injection", 12, 30, "Main Pharmacy", False),
        ("Insulin Regular 100 IU/ml", "Insulin regular", "Injection", 48, 30, "ICU Satellite", False),
        ("Metformin 500mg", "Metformin", "Tablet", 3100, 800, "Main Pharmacy", False),
        ("Amoxicillin 500mg", "Amoxicillin", "Capsule", 900, 400, "Main Pharmacy", False),
        ("Atorvastatin 40mg", "Atorvastatin", "Tablet", 1500, 500, "Main Pharmacy", False),
        ("Aspirin 75mg", "Aspirin", "Tablet", 2600, 600, "Main Pharmacy", False),
        ("Clopidogrel 75mg", "Clopidogrel", "Tablet", 640, 300, "Main Pharmacy", False),
        ("Warfarin 5mg", "Warfarin", "Tablet", 220, 100, "Main Pharmacy", False),
        ("Furosemide 40mg IV", "Furosemide", "Injection", 95, 60, "ER Satellite", False),
        ("Potassium Chloride 15% IV", "Potassium chloride", "Injection", 70, 40, "ICU Satellite", False),
        ("Noradrenaline 4mg/4ml", "Norepinephrine", "Injection", 26, 30, "ICU Satellite", False),
        ("Ondansetron 4mg", "Ondansetron", "Injection", 300, 100, "ER Satellite", False),
        ("Morphine 10mg/ml", "Morphine", "Injection", 40, 20, "ICU Satellite", True),
        ("Fentanyl 50mcg/ml", "Fentanyl", "Injection", 30, 20, "ICU Satellite", True),
        ("Midazolam 5mg/ml", "Midazolam", "Injection", 22, 25, "ICU Satellite", True),
        ("Tramadol 50mg", "Tramadol", "Capsule", 300, 100, "Main Pharmacy", True),
        ("Salbutamol nebuliser 2.5mg", "Salbutamol", "Respule", 180, 80, "ER Satellite", False),
    ]
    inventory = []
    for n, (name, generic, form, stock, reorder, loc, ctrl) in enumerate(drugs):
        inventory.append({
            "id": uid("drug", name), "medication_name": name, "generic_name": generic, "form": form,
            "stock_quantity": stock, "reorder_level": reorder, "unit": form.lower(), "location": loc,
            "is_controlled": ctrl, "expiry_date": iso(today + timedelta(days=40 + n * 23)),
            "unit_cost": round(rnd.uniform(2, 900), 2),
            "stock_status": "out_of_stock" if stock == 0 else ("low" if stock < reorder else "ok"),
        })
    stock_of = {i["medication_name"]: i["stock_quantity"] for i in inventory}
    order_specs = [  # patient idx, drug, dosage, order type, status, minutes ago
        (0, "Potassium Chloride 15% IV", "20 mEq IV over 2h", "STAT", "pending", 30),
        (0, "Noradrenaline 4mg/4ml", "0.1 mcg/kg/min infusion", "STAT", "dispensing", 18),
        (0, "Fentanyl 50mcg/ml", "25 mcg/h infusion", "routine", "dispensed", 300),
        (1, "Piperacillin-Tazobactam 4.5g", "4.5 g IV q6h", "STAT", "pending", 50),
        (1, "Heparin 5000 IU", "5000 IU SC q12h", "routine", "pending", 120),
        (1, "Midazolam 5mg/ml", "2 mg/h infusion", "routine", "dispensed", 420),
        (2, "Aspirin 75mg", "75 mg PO OD", "routine", "dispensed", 360),
        (2, "Clopidogrel 75mg", "75 mg PO OD", "routine", "pending", 80),
        (2, "Warfarin 5mg", "5 mg PO OD", "routine", "on_hold", 200),
        (3, "Salbutamol nebuliser 2.5mg", "2.5 mg neb q4h", "STAT", "dispensed", 140),
        (3, "Ceftriaxone 1g", "1 g IV q12h", "routine", "pending", 65),
        (4, "Insulin Glargine 100 IU/ml", "18 IU SC at bedtime", "routine", "pending", 150),
        (4, "Metformin 500mg", "500 mg PO BD", "discharge", "pending", 240),
        (5, "Pantoprazole 40mg IV", "40 mg IV OD", "routine", "dispensed", 500),
        (5, "Enoxaparin 40mg", "40 mg SC OD", "routine", "pending", 95),
        (6, "Meropenem 1g", "1 g IV q8h", "STAT", "pending", 22),
        (6, "Morphine 10mg/ml", "2 mg IV PRN", "routine", "dispensed", 260),
        (7, "Paracetamol 500mg", "1 g PO q6h PRN", "discharge", "pending", 70),
        (7, "Amoxicillin 500mg", "500 mg PO TDS x5d", "discharge", "pending", 70),
        (8, "Atorvastatin 40mg", "40 mg PO HS", "discharge", "pending", 45),
        (8, "Furosemide 40mg IV", "40 mg IV BD", "routine", "dispensing", 35),
        (8, "Tramadol 50mg", "50 mg PO q8h PRN", "discharge", "pending", 45),
    ]
    pharmacy_orders = []
    for n, (pidx, drug, dose, otype, status, mins) in enumerate(order_specs, 1):
        p = patients[pidx]
        inv = next(i for i in inventory if i["medication_name"] == drug)
        created = ago(mins)
        verified = not (n in (4, 13))
        pharmacy_orders.append({
            "id": uid("rx", n), "patient_token": p["id"], "patient_name": full_name(p),
            "encounter_id": p["admission_id"], "admission_id": p["admission_id"],
            "prescriber_id": doctors[n % 8]["id"], "prescriber_name": doctors[n % 8]["name"],
            "medication": drug, "medication_name": drug, "generic_name": inv["generic_name"], "dosage": dose,
            "order_type": otype, "is_stat": otype == "STAT", "priority": "stat" if otype == "STAT" else "routine",
            "status": status, "intent": "order", "department": p["ward"],
            "prescribed_at": iso(created), "created_at": iso(created),
            "tat_minutes": mins if status in ("pending", "dispensing") else rnd.randint(15, 60),
            "stock_quantity": stock_of[drug], "is_controlled": inv["is_controlled"],
            "patient_verified": verified, "prescription_matched": n != 9,
            "verification_status": "verified" if verified and n != 9 else "flagged",
            "missing_fields": ["prescriber_signature"] if n == 13 else [],
        })
    dispensing_log = [
        {"id": uid("disp", o["id"]), "order_id": o["id"], "medication_name": o["medication_name"],
         "patient_token": o["patient_token"], "quantity": 1, "status": o["status"], "is_stat": o["is_stat"],
         "order_type": o["order_type"], "department": o["department"], "created_at": o["created_at"],
         "tat_minutes": o["tat_minutes"],
         "dispensed_by": "Pharm. Shalini R." if o["status"] == "dispensed" else None,
         "dispensed_at": iso(datetime.fromisoformat(o["prescribed_at"]) + timedelta(minutes=o["tat_minutes"]))
                         if o["status"] == "dispensed" else None,
         "patient_verified": o["patient_verified"], "prescription_matched": o["prescription_matched"],
         "verification_status": o["verification_status"]}
        for o in pharmacy_orders if o["status"] in ("pending", "dispensing", "dispensed")
    ]
    interactions = [
        {"id": uid("ddi", 1), "drug_a": "Warfarin", "drug_b": "Aspirin", "severity": "major",
         "action_required": "Avoid combination or monitor INR closely; bleeding risk"},
        {"id": uid("ddi", 2), "drug_a": "Clopidogrel", "drug_b": "Pantoprazole", "severity": "moderate",
         "action_required": "Consider H2 blocker; may reduce antiplatelet effect"},
        {"id": uid("ddi", 3), "drug_a": "Heparin", "drug_b": "Enoxaparin", "severity": "major",
         "action_required": "Duplicate anticoagulation — do not co-administer"},
        {"id": uid("ddi", 4), "drug_a": "Morphine", "drug_b": "Midazolam", "severity": "major",
         "action_required": "Respiratory depression risk; continuous SpO2 monitoring"},
        {"id": uid("ddi", 5), "drug_a": "Tramadol", "drug_b": "Ondansetron", "severity": "moderate",
         "action_required": "Serotonin syndrome risk; monitor"},
    ]
    substitutions = [
        {"id": uid("sub", 1), "original_drug": "Piperacillin-Tazobactam 4.5g", "substitute_drug": "Cefoperazone-Sulbactam 2g",
         "rule": "Out of stock — equivalent anti-pseudomonal beta-lactam", "requires_physician_approval": True},
        {"id": uid("sub", 2), "original_drug": "Meropenem 1g", "substitute_drug": "Imipenem-Cilastatin 500mg",
         "rule": "Carbapenem class substitution", "requires_physician_approval": True},
        {"id": uid("sub", 3), "original_drug": "Insulin Glargine 100 IU/ml", "substitute_drug": "Insulin Detemir 100 IU/ml",
         "rule": "Basal insulin — dose 1:1, review in 48h", "requires_physician_approval": True},
        {"id": uid("sub", 4), "original_drug": "Heparin 5000 IU", "substitute_drug": "Enoxaparin 40mg",
         "rule": "DVT prophylaxis — check renal function", "requires_physician_approval": True},
        {"id": uid("sub", 5), "original_drug": "Pantoprazole 40mg IV", "substitute_drug": "Esomeprazole 40mg IV",
         "rule": "PPI class substitution", "requires_physician_approval": False},
    ]
    controlled_log = []
    for n, (drug, dept, qty, waste, witness, docs) in enumerate([
        ("Morphine 10mg/ml", "ICU", 3, 0.5, "Sr. Nurse Asha K.", True),
        ("Fentanyl 50mcg/ml", "ICU", 4, 0.0, "Sr. Nurse Bindu M.", True),
        ("Midazolam 5mg/ml", "ICU", 5, 1.0, None, False),
        ("Tramadol 50mg", "General Ward B", 6, 0.0, "Nurse Chitra P.", True),
        ("Morphine 10mg/ml", "Emergency", 2, 0.5, "Nurse Deepa S.", True),
    ]):
        controlled_log.append({
            "id": uid("ctrl", n), "medication_name": drug, "department": dept, "quantity_dispensed": qty,
            "wastage_quantity": waste, "witness": witness, "documentation_complete": docs,
            "variance_detected": n == 2, "status": "open" if not docs else "closed", "is_controlled": True,
            "logged_at": iso(ago(60 * (2 + n * 3))),
        })
    pharmacy_capacity = []
    for d in range(30, 0, -1):
        day = today - timedelta(days=d)
        vol = rnd.randint(260, 340)
        pharmacy_capacity.append({"date": iso(day), "orders_received": vol, "orders_dispensed": vol - rnd.randint(0, 12),
                                  "avg_tat_minutes": rnd.randint(25, 55), "stat_tat_minutes": rnd.randint(9, 20)})

    return {
        "today": iso(today), "patients": patients, "doctors": doctors, "departments": dept_rows,
        "contracts": contracts, "contract_rates": contract_rates, "invoices": invoices,
        "invoice_line_items": invoice_lines, "payments": payments, "payment_entries": payment_entries,
        "refunds": refunds, "claims": claims, "claim_line_items": claim_lines, "claim_history": claim_history,
        "claim_queries": claim_queries, "collections": collections, "reconciliation": reconciliation,
        "doctor_slots": doctor_slots, "appointments": appointments, "waitlist": waitlist,
        "service_slots": service_slots, "staff_roster": roster, "staff": staff,
        "ot_rooms": rooms, "ot_room_status": room_status, "ot_schedule": schedule, "ot_surgeries": surgeries,
        "ot_equipment": equipment, "lab_orders": lab_orders, "lab_results": lab_results,
        "lab_samples": lab_samples, "lab_analyzers": analyzers, "lab_qc_logs": qc_logs,
        "lab_reflex_rules": reflex_rules, "lab_validation_rules": validation_rules,
        "lab_capacity": lab_capacity, "lab_critical_escalations": critical_escalations,
        "pharmacy_orders": pharmacy_orders, "pharmacy_inventory": inventory,
        "pharmacy_dispensing_log": dispensing_log, "pharmacy_interactions": interactions,
        "pharmacy_substitutions": substitutions, "pharmacy_controlled_log": controlled_log,
        "pharmacy_capacity": pharmacy_capacity,
    }


# ── FHIR resources (lab + patients), shaped for Fabric's R5 parsers ──────────
_LAB_CAT = {"coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "laboratory"}]}
_INTERP = {"Normal": "N", "Low": "L", "High": "H", "Critical": "HH"}
_SR_PRIORITY = {"routine": "routine", "urgent": "urgent", "stat": "stat"}
_SR_STATUS = {"Pending": "active", "In Progress": "active", "On Hold": "on-hold", "Completed": "completed"}


def fhir_resources(d: dict) -> dict[str, list[dict]]:
    out: dict[str, list[dict]] = {"Patient": [], "ServiceRequest": [], "Observation": [], "Specimen": [], "Device": []}
    for p in d["patients"]:
        out["Patient"].append({
            "resourceType": "Patient", "id": p["id"],
            "identifier": [{"system": "https://carer-demo.hospital/uhid", "value": p["uhid"]}],
            "name": [{"family": p["last_name"], "given": [p["first_name"]]}],
            "gender": p["gender"], "birthDate": p["dob"],
            "telecom": [{"system": "phone", "value": p["phone"]}],
        })
    for o in d["lab_orders"]:
        out["ServiceRequest"].append({
            "resourceType": "ServiceRequest", "id": o["id"], "status": _SR_STATUS[o["status"]], "intent": "order",
            "priority": _SR_PRIORITY[o["priority"]],
            "code": {"concept": {"coding": [{"system": "http://loinc.org", "code": o["test_code"],
                                             "display": o["test_name"]}], "text": o["test_name"]}},
            "subject": {"reference": f"Patient/{o['patient_token']}"}, "authoredOn": o["ordered_at"],
        })
    for r in d["lab_results"]:
        obs = {
            "resourceType": "Observation", "id": r["id"], "status": "final", "category": [_LAB_CAT],
            "code": {"coding": [{"system": "http://loinc.org", "code": r["test_code"], "display": r["test_name"]}],
                     "text": r["test_name"]},
            "subject": {"reference": f"Patient/{r['patient_token']}"}, "effectiveDateTime": r["reported_at"],
            "valueQuantity": {"value": float(r["result_value"]), "unit": r["unit"] or None},
            "interpretation": [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation",
                                            "code": _INTERP[r["flag"]]}]}],
            "referenceRange": [{"text": r["reference_range"]}],
        }
        if not r["unit"]:
            obs["valueQuantity"].pop("unit")
        out["Observation"].append(obs)
    for s in d["lab_samples"]:
        spec = {
            "resourceType": "Specimen", "id": s["id"], "identifier": [{"value": s["barcode"]}],
            "status": s["status"], "type": {"text": s["type"]},
            "subject": {"reference": f"Patient/{s['patient_token']}"},
            "request": [{"reference": f"ServiceRequest/{s['order_id']}"}],
        }
        if s["collected_at"]:
            spec["collection"] = {"collectedDateTime": s["collected_at"]}
        if s["received_at"]:
            spec["receivedTime"] = s["received_at"]
        out["Specimen"].append(spec)
    for a in d["lab_analyzers"]:
        out["Device"].append({
            "resourceType": "Device", "id": a["id"],
            "status": "inactive" if a["status"] == "maintenance" else "active",
            "name": [{"value": a["name"], "type": "registered-name"}],
            "modelNumber": a["model"], "manufacturer": a["manufacturer"],
            "location": {"reference": f"Location/{a['location_id']}"},
        })
    return out


# ── Postgres mirror (hospilot.* tables the agents query through Hasura) ──────
PG_TABLES = {  # table: (dataset key, columns)
    "patients": ("patients", ["id", "first_name", "last_name", "uhid"]),
    "insurance_contracts": ("contracts", ["id", "insurer_name", "tpa_name", "contract_type", "contract_number",
                                          "start_date", "end_date", "status", "branch_id", "total_claims",
                                          "approved_amount", "rejection_rate", "avg_settlement_days"]),
    "contract_service_rates": ("contract_rates", ["id", "contract_id", "service_id", "service_code", "service_name",
                                                  "contract_rate", "hospital_rate", "discount_percentage", "is_active"]),
    "invoices": ("invoices", ["id", "org_id", "invoice_number", "patient_id", "invoice_date", "due_date",
                              "invoice_type", "visit_id", "admission_id", "package_id", "insurance_contract_id",
                              "subtotal", "discount_amount", "discount_percentage", "gst_amount", "cgst_amount",
                              "sgst_amount", "igst_amount", "grand_total", "paid_amount", "balance", "status",
                              "payment_status", "is_inter_state", "notes", "branch_id", "created_at", "updated_at"]),
    "invoice_line_items": ("invoice_line_items", ["id", "invoice_id", "service_id", "service_code", "service_name",
                                                  "description", "quantity", "rate", "amount", "total", "gst_rate",
                                                  "gst_amount", "discount_amount", "source_type", "source_id"]),
    "payments": ("payments", ["id", "org_id", "receipt_number", "invoice_id", "patient_id", "payment_date",
                              "total_amount", "status", "received_by", "notes", "branch_id", "created_at", "updated_at"]),
    "payment_entries": ("payment_entries", ["id", "payment_id", "payment_mode", "amount", "transaction_reference",
                                            "bank_name", "card_last_four", "created_at"]),
    "refunds": ("refunds", ["id", "invoice_id", "payment_id", "refund_amount", "reason", "status", "refund_date",
                            "refund_mode", "refund_number", "created_at"]),
    "claims": ("claims", ["id", "patient_token", "visit_id", "tpa_id", "tpa_name", "claim_amount", "status",
                          "created_at", "submitted_date", "approved_amount", "denial_reason", "claim_number",
                          "payer_type", "risk_level", "risk_score", "stage", "compliance_status", "diagnosis_code",
                          "branch_id"]),
    "claim_line_items": ("claim_line_items", ["id", "claim_id", "service_code", "service_name", "description",
                                              "quantity", "rate", "amount", "approved_amount", "approved_quantity",
                                              "approved_rate", "status", "category", "unit", "rejection_reason"]),
    "claim_history": ("claim_history", ["id", "claim_id", "from_status", "to_status", "action", "changed_at",
                                        "changed_by", "remarks"]),
    "claim_queries": ("claim_queries", ["id", "claim_id", "query_type", "query_text", "status", "raised_at",
                                        "raised_by", "responded_by", "response_date", "response_text", "created_at"]),
    "daily_collections": ("collections", ["id", "org_id", "collection_date", "cash_total", "upi_total", "card_total",
                                          "bank_transfer_total", "cheque_total", "total_collection", "invoice_count",
                                          "payment_count", "is_reconciled", "variance", "created_at", "updated_at"]),
    "payment_reconciliation": ("reconciliation", ["id", "reconciliation_date", "total_expected", "total_actual",
                                                  "total_variance", "actual_cash", "actual_card", "actual_upi",
                                                  "actual_bank", "cash_variance", "card_variance", "upi_variance",
                                                  "bank_variance", "status", "created_at"]),
    "appointments": ("appointments", ["id", "patient_id", "provider_id", "department_id", "appointment_time",
                                      "status", "type", "patient_name", "phone", "email", "specialization",
                                      "department_name"]),
    "doctor_slots": ("doctor_slots", ["id", "provider_id", "slot_date", "slot_start", "slot_end", "slot_type",
                                      "status", "max_patients", "booked_count", "specialization"]),
    "waitlist": ("waitlist", ["id", "patient_id", "patient_name", "phone", "email", "specialization", "priority",
                              "requested_date", "status", "reason", "created_at"]),
    "service_slots": ("service_slots", ["id", "slot_type", "slot_date", "slot_start", "slot_end", "location",
                                        "specialization", "max_patients", "booked_count", "status"]),
    "staff_roster": ("staff_roster", ["id", "area", "area_label", "role", "shift", "headcount", "assigned_load",
                                      "load_per_staff", "branch_id"]),
    "lab_orders": ("lab_orders", ["id", "visit_id", "patient_token", "ordered_by", "status", "priority",
                                  "ordered_at", "completed_at"]),
    "lab_results": ("lab_results", ["id", "order_id", "patient_token", "test_name", "test_code", "result_value",
                                    "flag", "reference_range", "unit", "reported_at"]),
    "ot_surgeries": ("ot_surgeries", ["id", "admission_id", "patient_token", "ward", "status", "created_at"]),
}


def _sql_literal(v) -> str:
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def _pg_value(col: str, v):
    """Id columns are uuid-typed in Postgres; legacy string ids (adm-bed-...) become NULL."""
    if v is not None and (col == "id" or col.endswith("_id")):
        try:
            uuid.UUID(str(v))
        except ValueError:
            return None
    return v


def to_sql(d: dict) -> str:
    """Idempotent: delete-then-insert by id, so re-running refreshes relative dates."""
    out = ["BEGIN;"]
    for table, (key, cols) in PG_TABLES.items():
        rows = d[key] if isinstance(d[key], list) else [d[key]]
        if not rows:
            continue
        ids = ", ".join(_sql_literal(r["id"]) for r in rows)
        out.append(f"DELETE FROM hospilot.{table} WHERE id IN ({ids});")
        values = ",\n  ".join("(" + ", ".join(_sql_literal(_pg_value(c, r.get(c))) for c in cols) + ")"
                               for r in rows)
        out.append(f"INSERT INTO hospilot.{table} ({', '.join(cols)}) VALUES\n  {values};")
    out.append("COMMIT;")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    data = build()
    if "--sql" in sys.argv:
        sys.stdout.write(to_sql(data))
    else:
        print(json.dumps({k: len(v) if isinstance(v, list) else 1 for k, v in data.items() if k != "today"}, indent=1))
