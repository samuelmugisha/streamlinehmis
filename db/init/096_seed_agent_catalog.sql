-- 096 · Seed the agent / subagent / task registry from the planner's own fallback catalog
--
-- WHY THIS FILE EXISTS. workflows/planner.py::fetch_registry() only falls back to its
-- hardcoded AVAILABLE_AGENTS / SUB_AGENTS catalog when the DB query RAISES -- not when it
-- succeeds and returns zero rows. 095_control_plane_bootstrap.sql creates
-- hospilot_app.agent_registry / subagent_registry / task_registry but leaves them empty,
-- so a fresh install boots fine but the planner has zero real agents to route any goal
-- to -- every session silently plans against nothing. This file seeds those three tables
-- with exactly the catalog already hardcoded in workflows/planner.py (AVAILABLE_AGENTS,
-- SUB_AGENTS), dumped directly from the running app rather than retyped by hand, so the
-- DB-backed and hardcoded-fallback catalogs cannot drift on day one.
--
-- Regenerate this file after editing planner.py's catalog:
--   docker exec <backend-container> python3 -c "..." (see the Hospilot 'run sample data'
--   walkthrough) and re-diff -- do not hand-edit rows below.
--
-- Idempotent: ON CONFLICT (id) DO UPDATE, so re-running after a planner.py catalog change
-- re-syncs existing rows instead of erroring on the primary key.

BEGIN;

-- ── agents ──────────────────────────────────────────────────────────────────────────────
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('bed_agent', 'Bed Management', 'owns finding/reserving a specific bed for a specific patient NOW; when ICU is full it also recovers dirty ICU beds (emergency cleaning -> mark ready)', '#3b82f6', true, 0)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('icu_agent', 'ICU Operations', 'owns ICU census, capacity, step-down (ICU->ward transfer; INTERNAL, patient stays in hospital), critical-patient escalation, escalation deferral', '#8b5cf6', true, 1)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('er_agent', 'ER Coordination', 'owns EMERGENCY DEPARTMENT flow for patients ARRIVING at the ED from outside the hospital: triage/CTAS scoring, acuity response, fast-track, admission selection, and ER boarding (patients admitted FROM the ED still awaiting an inpatient bed). Scope is NEW ED arrivals only. Do NOT use for in-hospital events involving patients who never came through the ED: an already-admitted inpatient''s fall or deterioration on a ward is a clinical-escalation event, not ER triage; and elective/scheduled or ward patients waiting for an inpatient bed belong to bed_agent -- ER triage/CTAS/boarding logic does not apply to them.', '#ef4444', true, 2)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('staff_agent', 'Staffing', 'owns nurse-to-patient ratios, shift coverage, float-pool deployment', '#f59e0b', true, 3)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('discharge_agent', 'Discharge Planning', 'owns getting patients OUT of the hospital entirely (home/SNF). NEVER use for ICU step-down -- step-down is icu_agent''s. discharge_agent only applies when patients are leaving the hospital, not moving between units.', '#10b981', true, 4)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('pharmacy_agent', 'Pharmacy', 'owns drug stock, dispensing queue, STAT orders, interactions, substitutions', '#06b6d4', true, 5)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('lab_agent', 'Lab Operations', 'owns lab order tracking, sample management, TAT, critical-result escalation, QC', '#06b6d4', true, 6)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('ot_agent', 'OT Scheduling', 'owns LIVE operating-theatre scheduling: today''s/upcoming surgical list, theatre capacity & turnaround, emergency case insertion, and post-op bed planning -- always read from the live/forward OT schedule. MAY run alongside financial agents when live surgical scheduling is genuinely part of the goal (e.g. an overrunning list plus its cost impact, or confirming pre-auth before booking tomorrow''s cases). The one thing it does NOT do is a RETROSPECTIVE look-back: a ''what happened'' audit of PAST surgical cases or denied claims (TPA / pre-auth / denial audit over closed encounters) reads historical records owned by revenue_agent or billing_agent -- do not add ot_agent for a look-back audit, because its live schedule holds none of that history.', '#7c3aed', true, 7)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('revenue_agent', 'Revenue', 'PREDICT & PREVENT revenue loss: hospital-wide billing-gap & leakage review, package/department profitability, resource utilization, AND insurance denial-risk PREDICTION & PREVENTION (pre-submission validation, payer rules, missing docs). Include when the goal is explicitly financial/analytical (billing review, leakage/profitability analysis, denial-risk review, financial health, daily/shift briefing, performance review). Do NOT add to acute clinical goals (triage, ICU, bed placement, staffing, pharmacy) -- it returns empty noise. Does NOT create bills or look up a single patient''s invoices -- that is billing_agent.', '#f97316', true, 8)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('billing_agent', 'Billing', 'EXECUTE billing operations: structural claim validation (discrepancies, eligibility, compliance), collections / payment recovery, single-patient invoice & claim LOOKUP, and BILL GENERATION. Include for explicit claims-quality / compliance / collection goals, OR to CREATE/RAISE/GENERATE a bill, OR to look up one named patient''s invoices/claims. task_type "initiate_billing" to create a bill for a resolved patient (lead with patient_verification_agent); "patient_billing" for a read-only invoice/claim lookup of one named patient; omit task_type for hospital-wide claims/collections review.', '#0ea5e9', true, 9)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('ambulance_agent', 'Ambulance Dispatch', 'owns ambulance dispatch / pre-arrival coordination (patient NOT in the building yet)', '#ef4444', true, 10)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.agent_registry (id, label, description, color, is_active, sort_order)
VALUES ('patient_verification_agent', 'Patient Verification', 'owns establishing patient IDENTITY (mobile -> patient_token + vitals). An INPUT PREREQUISITE that runs FIRST whenever the goal acts on ONE specific patient -- incoming (ER arrival, ICU admit, bed reservation) OR a specifically-named ADMITTED patient (discharge / billing-audit THE one named patient). NOT the goal owner. Omit for ward-wide/batch goals (discharge sweep, capacity, hospital-wide billing).', '#14b8a6', true, 11)
ON CONFLICT (id) DO UPDATE SET label = EXCLUDED.label, description = EXCLUDED.description,
    color = EXCLUDED.color, sort_order = EXCLUDED.sort_order;

-- ── subagents ───────────────────────────────────────────────────────────────────────────
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_bed_availability', 'bed_agent', 'Bed Availability', 'Identifies all available beds that are clean, unblocked, and ready for a patient', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_dirty_bed_recovery', 'bed_agent', 'Dirty Bed Recovery', 'Dispatches emergency housekeeping for dirty beds detected by availability check', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_bed_ranking', 'bed_agent', 'Bed Assignment', 'Uses clinical AI to recommend the best available bed based on the patient''s needs', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_bed_reservation', 'bed_agent', 'Bed Reservation', 'Reserves the selected bed and notifies the receiving ward after clinical approval', true, 3)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_escalation', 'bed_agent', 'Escalation', 'Escalates when no compliant bed can be found after a full search', true, 4)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_bed_pred_census', 'bed_agent', 'Capacity Census', 'Counts beds, ICU occupancy, discharge horizon, and ER pressure', true, 5)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_icu_census', 'icu_agent', 'ICU Census', 'Reviews current ICU occupancy, active admissions, and available beds (data only; step-down flagging belongs to the Step-Down Coordinator)', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_icu_transfer', 'icu_agent', 'ICU Admissions', 'Handles incoming ICU admissions: ranks pending admission requests by acuity, reserves a bed for the most critical patient, and triggers overflow evaluation when ICU is full. Transfers OUT of ICU (step-down) are handled by the Step-Down Coordinator.', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_icu_stepdown', 'icu_agent', 'Step-Down Coordinator', 'Confirms clinical criteria for STEP-DOWN -- an INTERNAL transfer of an ICU patient who is STAYING in the hospital to a lower-acuity bed (ward / HDU / progressive care) -- and arranges that transfer. Include ONLY when the task is an internal ICU-to-ward step-down. Do NOT use for a FULL HOSPITAL DISCHARGE (patient leaving the hospital -- that is discharge_agent), nor for a documentation / notes / records review (which is not a transfer at all).', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_er_triage', 'er_agent', 'Triage Monitor', 'Pulls the active ER queue and scores/persists CTAS triage for every patient; the always-run spine that emits the criticality counts every other ER sub-agent branches on', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_er_acuity_response', 'er_agent', 'Acuity Response', 'Reactive emergency handling for triaged patients — code-blue, SpO2 stabilization, sepsis/stroke/trauma protocols, specialist paging; runs ONLY when triage flags criticality', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_er_disposition', 'er_agent', 'Disposition Coordinator', 'Routes triaged patients to their next setting — fast-track/OPD for low acuity, admission selection with bed-type tagging for high acuity', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_er_boarding', 'er_agent', 'Boarding Monitor', 'Checks ER BOARDERS -- patients ALREADY ADMITTED who are physically still in the ED waiting for an inpatient bed -- and escalates bed-wait SLA breaches. Include ONLY when the concern is admitted patients boarding in the ED (bed-block / boarding SLA). Do NOT include for the not-yet-triaged / unattended active ER queue, general ER wait times, or ER understaffing -- that active-queue crisis belongs to the Triage Monitor, not boarding. Boarding tracks a different population (admitted, awaiting a bed) than the arrival/triage queue.', true, 3)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ratio_monitor', 'staff_agent', 'Ratio Monitor', 'Reviews nurse-to-patient ratios across all wards and flags understaffed areas', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_float_pool', 'staff_agent', 'Float Pool Dispatcher', 'Covers staffing shortfalls by identifying available float nurses and deploying them to understaffed wards', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ambulance_census', 'ambulance_agent', 'Fleet Census', 'Fetches the full ambulance fleet from the database and caches it in Redis for fast dispatch lookup', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ambulance_dispatch', 'ambulance_agent', 'Dispatch Coordinator', 'Assigns the best available unit by type and fuel level, surfaces ETA and crew from the DB record, and flags escalation for critical emergency types', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_discharge_ready', 'discharge_agent', 'Readiness Assessor', 'Reviews each admitted patient to determine if they are clinically ready for discharge — ONLY for active admissions and forward-looking readiness goals; exclude for retrospective, audit, or post-discharge review', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_discharge_retrospective', 'discharge_agent', 'Retrospective Discharge Reviewer', 'Reviews completed/closed discharge encounters for documentation and audit goals — ONLY for retrospective, historical, or post-discharge review; NOT for active admissions', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_discharge_barriers', 'discharge_agent', 'Discharge Approver', 'Awaits human approval then commits discharge-ready status and frees the bed', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_stock_monitor', 'pharmacy_agent', 'Stock Monitor', 'Reviews current medication stock levels and flags drugs running low', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_medication_prioritization', 'pharmacy_agent', 'Medication Prioritization Agent', 'Prioritizes STAT and critical patient medication orders; escalates unavailability', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_medication_fulfillment', 'pharmacy_agent', 'Medication Fulfillment Agent', 'Tracks prescription receipt, availability check, and dispensing lifecycle', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_drug_availability', 'pharmacy_agent', 'Drug Availability Agent', 'Monitors stock levels, searches alternate locations, reserves inventory', true, 3)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_prescription_validation', 'pharmacy_agent', 'Prescription Validation Agent', 'Validates completeness, dosage safety, and duplicate detection before dispensing', true, 4)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_clinical_interaction', 'pharmacy_agent', 'Clinical Interaction Agent', 'Runs drug-drug interaction and allergy conflict checks', true, 5)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_dispensing_validation', 'pharmacy_agent', 'Dispensing Validation Agent', 'Right patient / right drug / right dose validation before medication release', true, 6)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_medication_substitution', 'pharmacy_agent', 'Medication Substitution Agent', 'Recommends formulary alternatives and manages physician approval workflow', true, 7)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_pharmacy_queue', 'pharmacy_agent', 'Pharmacy Queue Optimization Agent', 'Monitors dispensing queue, identifies bottlenecks, prioritizes STAT workload', true, 8)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_controlled_drug_compliance', 'pharmacy_agent', 'Controlled Drug Compliance Agent', 'Audits controlled substance dispensing for authorization and inventory accuracy', true, 9)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_sample_prioritization', 'lab_agent', 'Sample Prioritization Agent', 'Prioritizes STAT/ICU/ER samples and escalates TAT-risk cases', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_sample_tracking', 'lab_agent', 'Sample Tracking Agent', 'Tracks collection, transport, and lab receipt status; triggers search for missing samples', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_tat_optimization', 'lab_agent', 'TAT Optimization Agent', 'Monitors turnaround time, identifies bottlenecks, escalates SLA breaches', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_analyzer_utilization', 'lab_agent', 'Analyzer Utilization Agent', 'Monitors analyzer load, triggers rebalancing and maintenance alerts', true, 3)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_analyzer_routing', 'lab_agent', 'Analyzer Routing Agent', 'Routes samples to alternate analyzers when primary is overloaded', true, 4)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_quality_control', 'lab_agent', 'Quality Control Agent', 'Validates QC pass/fail per shift, triggers recalibration, raises compliance alerts', true, 5)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_test_validation', 'lab_agent', 'Test Validation Agent', 'Auto-validates results against rules, delta checks, critical value flags', true, 6)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_critical_result_escalation', 'lab_agent', 'Critical Result Escalation Agent', 'Detects critical lab values and escalates to physician / ICU-ER team', true, 7)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_test_recommendation', 'lab_agent', 'Test Recommendation Agent', 'Detects abnormal results, applies reflex rules, recommends add-on tests', true, 8)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ot_census', 'ot_agent', 'OT Census', 'Reviews today''s surgical list, theatre status, equipment, and available post-operative (ICU/HDU) beds', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ot_turnaround', 'ot_agent', 'OT Turnaround Agent', 'Reduces OT idle time — coordinates theatre cleaning, validates instrument readiness, predicts delays, and dispatches preparation tasks', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ot_scheduling', 'ot_agent', 'OT Scheduling Agent', 'Owns the surgical plan AND surgical (re)scheduling: detects room/surgeon conflicts, checks resources, balances theatre load, and -- when a surgery is cancelled or must be moved -- finds an open theatre slot and stages an executable reschedule. This is the owner of moving/rescheduling a theatre case (never the OPD appointment agent).', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ot_emergency', 'ot_agent', 'OT Emergency Response', 'Acuity-reactive -- detects non-elective/emergency surgical cases and plans immediate theatre assignment for them. The handling step runs only when emergency cases are present.', true, 3)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_ot_analysis', 'ot_agent', 'OT Analysis', 'Terminal synthesis — scores OT efficiency, produces per-case proceed/delay/escalate recommendations, AND (executable) defers the delay-flagged electives to later slots to free capacity', true, 4)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_rev_optimization', 'revenue_agent', 'Revenue Optimization', 'Identifies revenue leakage and optimizes utilization across hospital resources', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_rev_denial_prevention', 'revenue_agent', 'Denial Prevention', 'Pre-submission claims safeguards: predicts insurance denial risk and validates claims against payer rules and require documentation before a claim is submitted to the payer. Belongs to admission / pre-authorization / claim-submission flows where claims are being prepared. Not a billing lookup or completeness check — to retrieve or verify an existing patient''s billing record (e.g. at discharge), use Patient Billing Lookup.', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_claim_validation', 'billing_agent', 'Claim Validation', 'Detects duplicate claims, missing invoice linkages, and amount mismatches', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_billing_optimization', 'billing_agent', 'Billing Optimization', 'Tracks overdue invoices, detects revenue leakage, and generates billing recommendations', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_rev_patient_billing', 'billing_agent', 'Patient Billing Lookup', 'Fetches all invoices and claims for a specific patient', true, 2)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_rev_initiate_billing', 'billing_agent', 'Initiate Billing', 'Creates a bill-generation request for the resolved patient(s); the DB side turns it into an actual bill when the session is committed', true, 3)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_patient_identification', 'patient_verification_agent', 'Patient Identification', 'Resolves incoming patient(s) by mobile -> token + vitals; flags unknown/provisional patients', true, 0)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.subagent_registry (id, agent_id, label, description, is_active, sort_order)
VALUES ('sa_patient_registration', 'patient_verification_agent', 'Patient Registration', 'Registers an incoming patient that has no DB record yet -- sends a registration request to Fabric (forwarded to the DB side, created manually by hospital staff) and pauses the flow until the new record is reported back, then rebinds the patient. Runs only when identification finds an unknown patient.', true, 1)
ON CONFLICT (id) DO UPDATE SET agent_id = EXCLUDED.agent_id, label = EXCLUDED.label,
    description = EXCLUDED.description, sort_order = EXCLUDED.sort_order;

-- ── tasks ───────────────────────────────────────────────────────────────────────────────
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_query_beds', 'sa_bed_availability', 'Query all available beds — always include; returns counts by type (icu_count, hdu_count, general_count, ventilator_count, isolation_count)', '["candidate_count", "icu_count", "hdu_count", "general_count", "ventilator_count", "isolation_count", "candidates"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_dirty_icu_beds', 'sa_bed_availability', 'Fallback when ICU has no clean beds — ONLY when patient requires an ICU bed; condition: ta_query_beds.icu_count == 0', '["dirty_count", "dirty_beds"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_dirty_soon_to_release', 'sa_bed_availability', 'Fallback when no beds found at all — condition: ta_query_beds.candidate_count == 0', '["beds"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_overflow_candidates', 'sa_bed_availability', 'Fallback when no beds found at all — condition: ta_query_beds.candidate_count == 0', '["candidates"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_temporary_overflow_beds', 'sa_bed_availability', 'Emergency fallback when no beds found at all — condition: ta_query_beds.candidate_count == 0', '["candidates"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_clean_vacated_beds', 'sa_dirty_bed_recovery', 'Dispatch standard housekeeping for recently discharged beds — always include for bed_cleaning task type', '["dispatched"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_emergency_cleaning_task', 'sa_dirty_bed_recovery', 'Create priority cleaning job for urgently needed bed — condition: ta_check_dirty_icu_beds.dirty_count > 0', '["bed_ids", "created"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_dispatch_housekeeping_fast_track', 'sa_dirty_bed_recovery', 'Dispatch fast-track housekeeping with response target < 10 minutes — condition: ta_check_dirty_icu_beds.dirty_count > 0', '["dispatched", "within_sla"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_to_floor_supervisor', 'sa_dirty_bed_recovery', 'Escalate to floor supervisor when housekeeping cannot respond in time — condition: ta_dispatch_housekeeping_fast_track.within_sla == 0', '["escalated"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_sanitization', 'sa_dirty_bed_recovery', 'Validate sanitization completed after housekeeping dispatch — condition: ta_dispatch_housekeeping_fast_track.within_sla > 0', '["passed"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_mark_bed_ready', 'sa_dirty_bed_recovery', 'Mark bed clean and available after sanitization passes — condition: ta_validate_sanitization.passed > 0', '["bed_id"]'::jsonb, false, true, 5)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_room_readiness', 'sa_dirty_bed_recovery', 'Check overall room cleanliness and readiness status', '["ready", "issues"]'::jsonb, false, true, 6)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_oxygen_readiness', 'sa_dirty_bed_recovery', 'Validate O2 pipeline is functional for a bed', '["functional"]'::jsonb, false, true, 7)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_monitor_readiness', 'sa_dirty_bed_recovery', 'Check that bedside monitor is connected and functional', '["functional"]'::jsonb, false, true, 8)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_notify_biomedical_team', 'sa_dirty_bed_recovery', 'Alert biomedical engineering about an equipment fault', '["notified"]'::jsonb, false, true, 9)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_sync_ready_status', 'sa_dirty_bed_recovery', 'Sync bed-ready status to the Bed Assignment Agent', '["synced"]'::jsonb, false, true, 10)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_equipment_task', 'sa_dirty_bed_recovery', 'Create an equipment setup or repair task', '["task_id"]'::jsonb, false, true, 11)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_rank_beds', 'sa_bed_ranking', 'Rank candidate beds for this patient — always include when reserving', '["ranked_beds", "recommendation"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_filter_ventilator_beds', 'sa_bed_ranking', 'ONLY when patient requires mechanical ventilation — condition: ta_query_beds.ventilator_count > 0', '["candidates"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_filter_isolation_beds', 'sa_bed_ranking', 'ONLY when patient requires infection isolation — condition: ta_query_beds.isolation_count > 0', '["candidates"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_apply_gender_filter', 'sa_bed_ranking', 'ONLY when gender-bay policy explicitly applies to this admission — condition: ta_query_beds.candidate_count > 0', '["candidates"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_apply_isolation_room_filter', 'sa_bed_ranking', 'ONLY when patient requires negative-pressure isolation (TB, airborne precautions) — condition: ta_query_beds.isolation_count > 0', '["candidates"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_trigger_alternate_ward_search', 'sa_bed_ranking', 'ONLY when primary ward candidates are exhausted after filtering — condition: ta_query_beds.candidate_count > 0', '["candidates"]'::jsonb, false, true, 5)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_recommend_transfer_allocation', 'sa_bed_ranking', 'ONLY when no bed available in-hospital — condition: ta_query_beds.candidate_count == 0', '["recommendation"]'::jsonb, false, true, 6)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_recommend_icu_to_ward_transfer', 'sa_bed_ranking', 'ONLY when ICU bed is needed but ICU is full — condition: ta_query_beds.icu_count == 0', '["recommendation"]'::jsonb, false, true, 7)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_allocate_overflow_bed', 'sa_bed_ranking', 'ONLY when no standard bed available, last resort, AND patient is NOT ventilator-dependent or monitoring-dependent — for vent/monitoring-dependent patients external transfer is the correct last resort, not overflow bed allocation', '["bed_id"]'::jsonb, false, true, 8)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_approval', 'sa_bed_reservation', 'Lock bed and create approval task — always include when reserving', '["approval_id", "bed_id"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_confirm_reservation', 'sa_bed_reservation', 'Confirm reservation post-approval — always include when reserving', '["bed_id", "status"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_sync_bed_status', 'sa_bed_reservation', 'Sync bed status with HIS after reservation — always include when reserving', '["synced"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_hold_bed_temporarily', 'sa_bed_reservation', 'Soft-hold a bed for a patient explicitly en route but not yet arrived — ONLY when goal mentions patient en route', '["held"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_to_command_center', 'sa_escalation', 'Broadcast a full escalation alert via WebSocket', '["escalated"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_allocation_conflict', 'sa_escalation', 'Escalate when no compliant bed can be found after full search', '["escalated"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_capacity_snapshot', 'sa_bed_pred_census', 'Count beds, ICU occupancy, discharge horizon, and ER pressure', '["total_beds", "available", "icu_occupancy_pct", "overflow_risk"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_icu_census', 'sa_icu_census', 'Query ICU occupancy, current admissions, and available beds from Redis', '["icu_available", "available_beds", "icu_admissions", "non_icu_admissions"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_rank_icu_requests', 'sa_icu_transfer', 'Rank incoming ICU admission requests by clinical acuity — always run when ICU requests are active', '["ranked_requests", "ventilator_dependent_count", "deterioration_risk_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_prioritize_ventilator_bed', 'sa_icu_transfer', 'Prioritize ventilator ICU bed for ventilator-dependent patients — condition: ta_rank_icu_requests.ventilator_dependent_count > 0', '["ventilator_priority_count", "ranked_requests"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_reserve_icu_admission', 'sa_icu_transfer', 'Reserve ICU admission for top-ranked patient when beds available — condition: ta_get_icu_census.icu_available > 0', '["approval_id", "patient_token"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_trigger_overflow_evaluation', 'sa_icu_transfer', 'Trigger overflow evaluation when ICU full — condition: ta_get_icu_census.icu_available == 0', '["overflow_triggered", "patients_pending"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_deterioration', 'sa_icu_transfer', 'Escalate priority for patients with high deterioration risk — condition: ta_rank_icu_requests.deterioration_risk_count > 0', '["escalated"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_icu_status', 'sa_icu_stepdown', 'Analyse step-down and escalation eligibility with Claude', '["step_down_candidates", "escalation_candidates", "summary", "critical_vital_ids", "transfer_candidate_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_icu_approval', 'sa_icu_stepdown', 'Create ICU transfer approval task in Hasura — condition: ta_analyze_icu_status.transfer_candidate_count > 0', '["created"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_confirm_icu_actions', 'sa_icu_stepdown', 'Execute confirmed step-down transfers', '["critical_vitals_flagged", "transfers_staged"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_er_visits', 'sa_er_triage', 'Query the active ER visit queue from Redis — always include; the data spine every downstream ER sub-agent reads from', '["visits"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_triage_patients', 'sa_er_triage', 'Score and triage ER patients with Claude — always include when ER visits exist; emits the criticality counts downstream tasks branch on', '["triaged", "ctas1", "ctas2", "critical", "spo2_critical_count", "protocol_flags_count", "specialist_needed_count", "fasttrack_count", "admission_candidate_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_save_triage_scores', 'sa_er_triage', 'Persist triage scores to Redis — always include after triage', '["saved"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_cardiac_arrest', 'sa_er_acuity_response', 'Trigger code-blue workflow when cardiac arrest is suspected — condition: ta_triage_patients.ctas1 > 0', '["cardiac_arrest_suspected", "code_blue_triggered"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_spo2_critical', 'sa_er_acuity_response', 'Escalate stabilization protocol when SpO2 is critically low — condition: ta_triage_patients.spo2_critical_count > 0', '["spo2_critical", "escalated"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_clinical_protocol', 'sa_er_acuity_response', 'Activate sepsis/stroke/trauma protocol pathway — condition: ta_triage_patients.protocol_flags_count > 0', '["protocol_count", "protocol_activated", "protocols"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_notify_specialist', 'sa_er_acuity_response', 'Notify relevant specialist team based on detected condition — condition: ta_triage_patients.specialist_needed_count > 0', '["notified", "specialists_notified"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_route_fasttrack', 'sa_er_disposition', 'Route low-acuity patients (CTAS 4-5) to fast-track / OPD diversion — condition: ta_triage_patients.fasttrack_count > 0', '["fasttrack_candidates"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_select_critical', 'sa_er_disposition', 'Select critical patients (CTAS 1-3) for admission and tag bed_type_needed for the Bed Agent — condition: ta_triage_patients.admission_candidate_count > 0', '["critical_patients"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_er_boarders', 'sa_er_boarding', 'Check ER boarders and escalate SLA breaches', '["boarders", "escalated"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_ward_workload', 'sa_ratio_monitor', 'Aggregate patients and incomplete/overdue task load per ward (from admissions + clinical tasks)', '["workload"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_hourly_workload', 'sa_ratio_monitor', 'Bucket ward task-load by hour of day; flag peak / understaffed hours', '["by_hour", "peak_hours", "understaffed_hours", "total_tasks"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_area_staffing', 'sa_ratio_monitor', 'Assess staffing for a specific area (front desk, OPD, phlebotomy, OT, recovery/PACU, lab, inpatient nursing); flag understaffed areas', '["shift", "areas_assessed", "areas", "understaffed_areas"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_documentation_gaps', 'sa_ratio_monitor', 'Detect staffing documentation gaps (missing / overdue care notes, charting, unsigned records) by ward — ONLY for administrative/audit/compliance goals; exclude during live emergency, real-time staffing, or float-pool dispatch', '["documentation_tasks_pending", "documentation_tasks_overdue", "by_ward", "flagged_wards", "has_gaps"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_staff_workload', 'sa_ratio_monitor', 'Analyse ward workload; flag high-pressure wards and recommend same-type staff moves (Claude)', '["recommendations", "high_pressure_wards", "summary"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_staff_approval', 'sa_float_pool', 'Create float pool deployment approval', '["created"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_confirm_staff_recommendation', 'sa_float_pool', 'Confirm and dispatch float nurses — condition: ta_create_staff_approval.created == true', '["status", "recommendations"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_available_ambulances', 'sa_ambulance_census', 'Fetch ambulance fleet data', '["ambulances"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_assign_ambulance', 'sa_ambulance_dispatch', 'Assign best available unit, surface ETA and crew, flag escalation', '["assigned_vehicle_no", "eta_mins", "escalate"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_ambulance_approval', 'sa_ambulance_dispatch', 'Create dispatch approval task — condition: ta_assign_ambulance.assigned_vehicle_no != null', '["approval_id"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_confirm_ambulance_dispatch', 'sa_ambulance_dispatch', 'Confirm ambulance dispatch — condition: ta_create_ambulance_approval.approval_id != null', '["confirmed"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_discharge_candidates', 'sa_discharge_ready', 'Fetch active admissions and discharge checklists', '["candidates", "count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_batch_assess_discharges', 'sa_discharge_ready', 'Assess discharge readiness for each patient', '["assessed", "ready", "blocked"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_notes_completeness', 'sa_discharge_ready', 'Check all clinical notes are present for discharge-ready patients — condition: ta_batch_assess_discharges.ready > 0', '["notes_incomplete", "incomplete_admissions"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_request_missing_docs', 'sa_discharge_ready', 'Request missing documentation — condition: ta_check_notes_completeness.notes_incomplete > 0', '["requested"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_pending_results', 'sa_discharge_ready', 'Check for pending lab/imaging results before finalizing summary — condition: ta_batch_assess_discharges.ready > 0', '["results_pending", "admissions_with_pending"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_generate_summaries', 'sa_discharge_ready', 'Generate AI discharge summaries — always include when discharge-ready patients exist; marks any pending lab/imaging results in the draft rather than blocking on them', '["summaries_generated"]'::jsonb, false, true, 5)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_discharge_records', 'sa_discharge_retrospective', 'Fetch recently discharged / closed encounters — ONLY for retrospective, audit, or post-discharge review goals; exclude for active admission readiness assessment', '["records", "count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_generate_summaries', 'sa_discharge_retrospective', 'Generate AI discharge summaries — always include when discharge-ready patients exist; marks any pending lab/imaging results in the draft rather than blocking on them', '["summaries_generated"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_discharge_approval', 'sa_discharge_barriers', 'Create discharge approval task in Hasura', '["approval_id"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_confirm_discharge_updates', 'sa_discharge_barriers', 'Execute confirmed discharge updates', '["confirmed"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_discharge_patients', 'sa_stock_monitor', 'Fetch discharge-ready patients for med reconciliation', '["patients"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_medication_reconciliation', 'sa_stock_monitor', 'Check medication reconciliation gaps', '["gaps", "stock_hours_remaining"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_save_pharmacy_report', 'sa_stock_monitor', 'Persist pharmacy report to Hasura', '["saved"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_stat_medication_orders', 'sa_medication_prioritization', 'Check for STAT medication orders', '["stat_count", "stat_orders"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_apply_critical_patient_priority', 'sa_medication_prioritization', 'Apply highest priority for critical and ICU/ER patients', '["critical_patient_count", "prioritized_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_stat_availability', 'sa_medication_prioritization', 'Check if STAT medications are in stock', '["stat_available_count", "stat_unavailable_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_stat_shortage', 'sa_medication_prioritization', 'Escalate when STAT medication is unavailable', '["escalated"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_prescription_received', 'sa_medication_fulfillment', 'Check if prescriptions have been received for pending orders', '["prescription_count", "pending_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_medication_availability', 'sa_medication_fulfillment', 'Verify medication is available in inventory', '["available_count", "unavailable_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_track_dispensing_progress', 'sa_medication_fulfillment', 'Track in-progress dispensing orders', '["dispensing_count", "delayed_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_close_fulfilled_orders', 'sa_medication_fulfillment', 'Mark completed medication orders as closed', '["closed_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_stock_levels', 'sa_drug_availability', 'Check current medication stock vs reorder levels', '["low_stock_count", "out_of_stock_count", "adequate_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_search_alternate_location', 'sa_drug_availability', 'Search satellite pharmacy and ICU cart for alternative stock', '["alternate_found", "alternate_location"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_reserve_inventory', 'sa_drug_availability', 'Reserve available inventory for STAT and critical orders', '["reserved_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_critical_shortage', 'sa_drug_availability', 'Escalate shortage impacting patient care to pharmacy lead', '["escalated", "shortage_medications"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_prescription_completeness', 'sa_prescription_validation', 'Check prescriptions are complete with all required fields', '["complete_count", "incomplete_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_dosage_range', 'sa_prescription_validation', 'Validate dose is within therapeutic safe range', '["safe_count", "unsafe_dose_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_duplicate_medications', 'sa_prescription_validation', 'Detect duplicate medication orders for same patient', '["duplicate_count", "duplicates"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_approve_or_hold_prescription', 'sa_prescription_validation', 'Release prescription for dispensing or hold for review', '["approved_count", "held_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_polypharmacy', 'sa_clinical_interaction', 'Check patients prescribed multiple concurrent medications', '["polypharmacy_count", "patient_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_run_interaction_check', 'sa_clinical_interaction', 'Run drug-drug interaction check against known rules', '["major_interaction_count", "total_interactions"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_allergy_conflict', 'sa_clinical_interaction', 'Check for allergy conflicts in pending orders', '["allergy_conflict_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_approve_safe_dispense', 'sa_clinical_interaction', 'Approve or hold medication based on interaction findings', '["approved_count", "held_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_verify_patient_identity', 'sa_dispensing_validation', 'Verify patient identity before medication dispensing', '["verified_count", "unverified_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_match_medication_prescription', 'sa_dispensing_validation', 'Match dispensed medication to prescription', '["match_failed_count", "matched_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_dispensing_dosage', 'sa_dispensing_validation', 'Validate correct dosage before medication release', '["dose_mismatch_count", "dose_correct_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_release_or_hold_dispensing', 'sa_dispensing_validation', 'Release verified medication or hold discrepancy for review', '["released_count", "held_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_unavailable_medications', 'sa_medication_substitution', 'Identify prescribed medications that are unavailable', '["unavailable_count", "unavailable_drugs"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_search_formulary_alternatives', 'sa_medication_substitution', 'Search formulary for therapeutic substitutes', '["substitute_available", "alternatives_found"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_request_physician_approval', 'sa_medication_substitution', 'Send substitution approval request to prescribing physician', '["approval_sent", "approved_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_update_substitution_order', 'sa_medication_substitution', 'Update order with approved substitute medication', '["orders_updated"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_queue_length', 'sa_pharmacy_queue', 'Check current dispensing queue length and STAT backlog', '["queue_length", "stat_waiting_count", "queue_above_threshold"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_queue_bottleneck', 'sa_pharmacy_queue', 'Identify bottleneck causing queue buildup', '["bottleneck_stage", "bottleneck_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_prioritize_stat_medications', 'sa_pharmacy_queue', 'Reprioritize queue for pending STAT medication orders', '["reprioritized_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_tat_breach', 'sa_pharmacy_queue', 'Escalate to pharmacy supervisor when TAT SLA is breached', '["escalated", "breach_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_identify_controlled_orders', 'sa_controlled_drug_compliance', 'Identify controlled substance orders requiring audit', '["controlled_count", "controlled_orders"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_verify_controlled_authorization', 'sa_controlled_drug_compliance', 'Verify authorization and witness documentation', '["authorized_count", "missing_auth_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_inventory_variance', 'sa_controlled_drug_compliance', 'Check for controlled drug inventory discrepancies', '["variance_detected", "variance_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_compliance_issue', 'sa_controlled_drug_compliance', 'Escalate to compliance officer for investigation', '["escalated"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_stat_status', 'sa_sample_prioritization', 'Check if any STAT samples are pending', '["stat_count", "stat_samples"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_apply_icu_er_priority', 'sa_sample_prioritization', 'Apply highest priority for ICU/ER samples', '["prioritized_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_analyzer_available', 'sa_sample_prioritization', 'Check if target analyzer is available', '["available_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_tat_risk', 'sa_sample_prioritization', 'Escalate to supervisor if TAT target is at risk', '["escalated"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_sample_collection', 'sa_sample_tracking', 'Check which samples are collected vs pending', '["collected_count", "pending_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_sample_transport', 'sa_sample_tracking', 'Check transport status for collected samples', '["in_transit", "delayed_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_verify_sample_receipt', 'sa_sample_tracking', 'Verify sample received at lab', '["received_count", "missing_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_trigger_sample_search', 'sa_sample_tracking', 'Trigger search for misplaced samples', '["search_triggered"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_tat_threshold', 'sa_tat_optimization', 'Check if current TAT exceeds SLA threshold', '["overdue_count", "tat_exceeded"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_tat_bottleneck', 'sa_tat_optimization', 'Identify the processing bottleneck stage', '["bottleneck_stage", "bottleneck_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_prioritize_stat_queue', 'sa_tat_optimization', 'Reprioritize queue for pending STAT samples', '["reprioritized_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_tat_supervisor', 'sa_tat_optimization', 'Escalate to Lab Supervisor when TAT is not restored', '["escalated"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_analyzer_utilization', 'sa_analyzer_utilization', 'Check if any analyzer load exceeds 90%', '["overloaded_count", "max_utilization"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_identify_alternate_analyzer', 'sa_analyzer_utilization', 'Identify available backup analyzer', '["alternate_available", "alternate_id"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_rebalance_analyzer_workload', 'sa_analyzer_utilization', 'Rebalance workload to backup analyzer', '["rebalanced"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_trigger_maintenance_alert', 'sa_analyzer_utilization', 'Alert maintenance team for predicted downtime', '["alerted"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_analyzer_overload', 'sa_analyzer_routing', 'Check if primary analyzer is overloaded', '["overloaded", "load_pct"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_alternate_analyzer', 'sa_analyzer_routing', 'Validate backup analyzer is certified for the test', '["validated", "alternate_id"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_execute_sample_routing', 'sa_analyzer_routing', 'Route samples to alternate analyzer', '["routed_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_restore_routing_capacity', 'sa_analyzer_routing', 'Close routing workflow when capacity is normalized', '["restored"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_qc_status', 'sa_quality_control', 'Check QC pass/fail for active analyzers this shift', '["failed_count", "qc_failed"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_trigger_recalibration', 'sa_quality_control', 'Stop result release and trigger recalibration', '["recalibration_triggered"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_repeat_qc_check', 'sa_quality_control', 'Rerun QC after calibration', '["passed", "repeat_passed"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_compliance_alert', 'sa_quality_control', 'Generate compliance alert if accreditation is impacted', '["alerted"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_result_rules', 'sa_test_validation', 'Check result against auto-validation rules', '["auto_released", "flagged_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_delta_flag', 'sa_test_validation', 'Run delta check against prior result', '["delta_failed_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_critical_value_flag', 'sa_test_validation', 'Check for critical value requiring escalation', '["critical_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_release_validated_report', 'sa_test_validation', 'Release auto-validated reports', '["released_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_critical_results', 'sa_critical_result_escalation', 'Detect critical lab values requiring immediate action', '["critical_count", "critical_results"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_notify_physician_critical', 'sa_critical_result_escalation', 'Alert physician for critical result', '["notified_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalate_icu_er_critical', 'sa_critical_result_escalation', 'Trigger urgent escalation for ICU/ER patients', '["escalated_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_log_critical_action', 'sa_critical_result_escalation', 'Log physician acknowledgment and close workflow', '["logged"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_abnormal_result', 'sa_test_recommendation', 'Detect abnormal results triggering reflex rules', '["abnormal_count", "abnormal_results"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_evaluate_reflex_rules', 'sa_test_recommendation', 'Apply reflex/add-on rules to abnormal results', '["recommended_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_recommend_additional_test', 'sa_test_recommendation', 'Send recommendation to physician', '["sent_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_reflex_order', 'sa_test_recommendation', 'Auto-create order per protocol if no approval needed', '["orders_created"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_ot_census', 'sa_ot_census', 'Fetch OT schedule, rooms, room status, today''s equipment, and available post-op (ICU/HDU) beds from cache — always include', '["schedule", "rooms", "room_status", "upcoming_surgeries", "upcoming_count", "post_op_beds_available", "icu_available", "hdu_available"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_check_cleaning', 'sa_ot_turnaround', 'OT cleaning coordination — check which theatres need cleaning before next case — always include', '["cleaning_count", "rooms_to_clean"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_check_instruments', 'sa_ot_turnaround', 'Instrument readiness validation — validate equipment availability for upcoming surgeries — condition: ta_get_ot_census.upcoming_count > 0', '["gap_count", "ready_count", "gaps"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_track_turnaround', 'sa_ot_turnaround', 'OT turnaround tracking — track theatre utilisation and active surgeries — always include', '["rooms_active", "active_count", "utilisation_pct"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_predict_delays', 'sa_ot_turnaround', 'Delay prediction — predict on-time start risks per theatre — always include', '["delay_risks", "high_risk_count"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_coordinate_staff', 'sa_ot_turnaround', 'Staff coordination — assign staff actions to address delay risks and gaps — condition: ta_ot_predict_delays.high_risk_count > 0', '["staff_actions"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_detect_conflicts', 'sa_ot_scheduling', 'Conflict detection — detect room double-bookings and surgeon overlaps — always include', '["conflict_count", "has_conflicts", "room_conflicts", "surgeon_conflicts"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_check_resources', 'sa_ot_scheduling', 'Resource-aware scheduling — assess room availability and case load per theatre — always include', '["available_rooms", "utilisation_pct", "under_resourced"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_optimise_slots', 'sa_ot_scheduling', 'Surgery slot optimisation — recommend slot swaps to resolve conflicts — condition: ta_ot_detect_conflicts.has_conflicts == true', '["slot_optimizations"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_balance_load', 'sa_ot_scheduling', 'OT load balancing — balance case load across available theatres — always include', '["load_balance", "summary"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_find_theatre_slots', 'sa_ot_scheduling', 'Find open theatre slots — derive bookable OT time-windows (by room type + duration) for (re)scheduling a surgery — include when a surgery must be scheduled or rescheduled into a slot', '["open_slots", "open_slot_count"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_reschedule_surgery', 'sa_ot_scheduling', 'Reschedule a cancelled surgery to the earliest open theatre slot; stages an executable move for commit — ONLY when a surgery is cancelled / must be moved to a new slot', '["rescheduled", "proposals", "status"]'::jsonb, false, true, 5)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_find_emergencies', 'sa_ot_emergency', 'Emergency detection -- identify non-elective and emergency cases in the schedule -- always include', '["emergency_count", "emergency_cases"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_handle_emergencies', 'sa_ot_emergency', 'Emergency OT handling -- plan immediate actions for emergency cases -- condition: ta_ot_find_emergencies.emergency_count > 0', '["emergency_actions"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_score_efficiency', 'sa_ot_analysis', 'OT efficiency optimisation — calculate overall OT efficiency score from delays, instrument gaps, and conflicts — always include', '["efficiency_score"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_ot_capacity', 'sa_ot_analysis', 'Per-case disposition — recommend proceed/delay/escalate for each case from conflicts, emergencies, and capacity — always include', '["case_recommendations", "recommendation_count", "escalate_count", "delay_count", "proceed_count", "summary"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_ot_defer_electives', 'sa_ot_analysis', 'Reprioritisation (executable) — move the electives flagged delay to a later open theatre slot to free capacity for higher-acuity cases; stages the moves for commit — include when electives must yield to a non-elective/emergency or a conflict', '["deferred", "proposals", "status"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_identify_revenue_leakage', 'sa_rev_optimization', 'Identify revenue leakage across departments and workflows — always include', '["leakage_detected", "leakage_amount", "unbilled_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_optimize_package_utilization', 'sa_rev_optimization', 'Optimize treatment and insurance package utilization — ONLY when goal involves package billing or package optimization', '["packages_reviewed", "savings_identified", "recommendations"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_resource_utilization', 'sa_rev_optimization', 'Analyze utilization efficiency across hospital resources — always include', '["utilization_score", "idle_equipment_count", "bottlenecks"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_analyze_dept_profitability', 'sa_rev_optimization', 'Analyze profitability across departments and specialties — ONLY when goal involves department performance or profitability analysis', '["dept_count", "below_target_count", "recommendations"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_predict_denial_risk_rev', 'sa_rev_denial_prevention', 'Predict insurance claim denial risk before submission — always include', '["high_risk_count", "medium_risk_count", "denial_probability"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_presubmission_validation_rev', 'sa_rev_denial_prevention', 'Validate claims before payer submission — ONLY when goal is NOT a snapshot, report, or dashboard; condition: ta_predict_denial_risk_rev.high_risk_count > 0', '["validation_passed", "issues_found", "missing_fields_count"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_payer_rule_compliance_rev', 'sa_rev_denial_prevention', 'Validate claims against payer-specific policies — always include', '["compliance_issues", "non_covered_count", "auth_missing_count"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_missing_docs_rev', 'sa_rev_denial_prevention', 'Detect incomplete documentation before claim submission — always include', '["missing_docs_count", "missing_summaries", "missing_signatures"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_escalation_recommendations_rev', 'sa_rev_denial_prevention', 'Recommend escalation actions for high-risk revenue cases — condition: ta_predict_denial_risk_rev.high_risk_count > 0', '["escalated", "escalation_count"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_claim_discrepancies', 'sa_claim_validation', 'Detect duplicate claims, missing invoice linkages, and amount mismatches', '["discrepancy_count", "missing_invoice", "duplicate_claims"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_validate_insurance_eligibility', 'sa_claim_validation', 'Check all pending claims for missing TPA linkage and unverified insurance', '["eligibility_issues", "no_tpa_pending_count", "unverified_amount"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_check_billing_compliance', 'sa_claim_validation', 'Flag claims and invoices missing required fields or violating coding rules', '["total_compliance_issues", "claim_compliance_issues", "invoice_compliance_issues"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_track_pending_payments', 'sa_billing_optimization', 'Bucket overdue invoices by SLA and flag high-value accounts for follow-up', '["overdue_count", "overdue_amount", "high_value_count"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_detect_revenue_leakage', 'sa_billing_optimization', 'Find claims without invoices and low-value IPD billing gaps', '["unlinked_claims_count", "estimated_leakage", "leakage_detected"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_generate_billing_recommendations', 'sa_billing_optimization', 'Synthesises billing state into prioritised optimisation recommendations', '["recommendation_count", "recommendations"]'::jsonb, false, true, 2)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_prioritize_payments', 'sa_billing_optimization', 'Rank outstanding invoices by value × aging for targeted collection', '["prioritized_count", "total_recoverable", "top_priority"]'::jsonb, false, true, 3)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_trigger_payment_reminder', 'sa_billing_optimization', 'Send payment reminders for overdue invoices — condition: ta_track_pending_payments.overdue_count > 0', '["reminders_sent"]'::jsonb, false, true, 4)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_notify_followup_team', 'sa_billing_optimization', 'Notify follow-up team about claims awaiting payer response — condition: ta_validate_insurance_eligibility.no_tpa_pending_count > 0', '["notified"]'::jsonb, false, true, 5)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_get_patient_invoices', 'sa_rev_patient_billing', 'Fetch all invoices and claims for a specific patient', '["invoices", "claims"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_create_billing_request', 'sa_rev_initiate_billing', 'Create a bill-generation request for the resolved patient(s) -- always include when the goal is to initiate/generate/raise a bill or invoice for a patient', '["billing_requests", "patient_count", "status"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_identify_patients', 'sa_patient_identification', 'Identify incoming patient(s) by mobile and resolve token + vitals -- always include', '["verified_count", "unknown_count", "patients"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_flag_unknown_patients', 'sa_patient_identification', 'Flag incoming patient(s) with no record -- condition: ta_identify_patients.unknown_count > 0', '["flagged"]'::jsonb, false, true, 1)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;
INSERT INTO hospilot_app.task_registry (id, subagent_id, label, outputs, is_dynamic, is_active, sort_order)
VALUES ('ta_register_patient', 'sa_patient_registration', 'Request registration of the unknown incoming patient(s) and pause until created', '["requested", "registered", "still_unknown", "patients"]'::jsonb, false, true, 0)
ON CONFLICT (id) DO UPDATE SET subagent_id = EXCLUDED.subagent_id, label = EXCLUDED.label,
    outputs = EXCLUDED.outputs, sort_order = EXCLUDED.sort_order;

COMMIT;
