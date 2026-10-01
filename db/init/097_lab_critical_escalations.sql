-- 097 · Lab critical-result escalation log
--
-- WHY THIS FILE EXISTS. `agents/lab/critical_result.py` (escalate_icu_er_critical,
-- log_critical_action) records escalations through `db/hasura.py::lab_upsert_escalation`,
-- an upsert into `hospilot_lab_critical_escalations` on constraint
-- `lab_critical_escalations_pkey`. That table was never part of this OSS cut, so the first
-- critical ICU/ER result made the task fail and the planner re-orchestrate in a loop
-- ("Pipeline configuration error detected — re-orchestrating…").
--
-- Columns are the ones the upsert sets (id, test_name NOT NULL, physician_notified,
-- physician_acknowledged_at, escalation_level, action_documented, closed_at) plus the
-- identifying fields the HIS escalation feed carries. Idempotent.
--
-- ⚠ After applying, track the table in Hasura (schema `hospilot`, source `default`).

CREATE TABLE IF NOT EXISTS hospilot.lab_critical_escalations (
    id                        uuid PRIMARY KEY,
    result_id                 uuid,
    order_id                  uuid,
    patient_token             text,
    test_name                 text NOT NULL,
    result_value              text,
    unit                      text,
    flag                      text,
    ward                      text,
    is_icu_er_patient         boolean DEFAULT false,
    physician_notified        boolean DEFAULT false,
    physician_acknowledged_at timestamptz,
    escalation_level          text,
    action_documented         boolean DEFAULT false,
    reported_at               timestamptz,
    closed_at                 timestamptz,
    created_at                timestamptz DEFAULT now(),
    synced_at                 timestamptz
);
