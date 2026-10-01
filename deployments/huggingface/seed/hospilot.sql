--
-- PostgreSQL database dump
--

\restrict kLqhQU9m1axgv3E38qMnLapNwtipI1UpBUGwVxZCr5nwR0PQIVTcdcCZjIzVCZe

-- Dumped from database version 15.19
-- Dumped by pg_dump version 15.19

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: allocation; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA allocation;


--
-- Name: hospilot; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA hospilot;


--
-- Name: hospilot_app; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA hospilot_app;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: set_current_timestamp_updated_at(); Type: FUNCTION; Schema: hospilot_app; Owner: -
--

CREATE FUNCTION hospilot_app.set_current_timestamp_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agent_budget; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.agent_budget (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agent text NOT NULL,
    shift_id text NOT NULL,
    shift_start timestamp with time zone NOT NULL,
    shift_end timestamp with time zone NOT NULL,
    base numeric(10,3) NOT NULL,
    demand_factor numeric(5,3) NOT NULL,
    criticality_factor numeric(5,3) DEFAULT 1.000 NOT NULL,
    fairness_factor numeric(5,3) NOT NULL,
    scarcity_factor numeric(5,3) NOT NULL,
    factor_sources jsonb DEFAULT '{}'::jsonb NOT NULL,
    budget_total numeric(10,3) NOT NULL,
    budget_remaining numeric(10,3) NOT NULL,
    spent_this_shift numeric(10,3) DEFAULT 0 NOT NULL,
    recovered_this_shift numeric(10,3) DEFAULT 0 NOT NULL,
    source text NOT NULL,
    n_win smallint,
    n_req smallint,
    cost_per_win numeric(8,3),
    cost_per_loss numeric(8,3),
    caps_version text NOT NULL,
    config_version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT budget_remaining_sane CHECK ((budget_remaining <= budget_total)),
    CONSTRAINT budget_source_valid CHECK ((source = ANY (ARRAY['seed'::text, 'computed'::text])))
);


--
-- Name: auction; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.auction (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auction_key text NOT NULL,
    resource_type text NOT NULL,
    resource_id text NOT NULL,
    mode text DEFAULT 'live'::text NOT NULL,
    trigger_source text NOT NULL,
    predicted_free_at timestamp with time zone NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    max_rounds smallint NOT NULL,
    rounds_run smallint DEFAULT 0 NOT NULL,
    reserve_price numeric(8,3),
    winning_agent text,
    winning_candidate_id text,
    winning_bid numeric(8,3),
    outcome text,
    caps_version text NOT NULL,
    config_version text NOT NULL,
    unsigned_rules jsonb DEFAULT '{}'::jsonb NOT NULL,
    participants jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT auction_mode_valid CHECK ((mode = ANY (ARRAY['live'::text, 'simulation'::text, 'advisory'::text, 'replay'::text]))),
    CONSTRAINT auction_outcome_valid CHECK (((outcome IS NULL) OR (outcome = ANY (ARRAY['awarded'::text, 'no_award'::text, 'aborted'::text]))))
);


--
-- Name: auction_bid; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.auction_bid (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auction_id uuid NOT NULL,
    round_index smallint NOT NULL,
    agent text NOT NULL,
    candidate_id text NOT NULL,
    patient_token text,
    action text NOT NULL,
    amount numeric(8,3) NOT NULL,
    utility numeric(8,3) NOT NULL,
    ceiling numeric(8,3) NOT NULL,
    alpha numeric(5,4),
    contention numeric(5,3),
    outcome_factor numeric(4,3),
    cost numeric(8,3),
    component_points jsonb DEFAULT '{}'::jsonb NOT NULL,
    component_coverage jsonb DEFAULT '{}'::jsonb NOT NULL,
    policy_name text,
    q_action text,
    plan jsonb DEFAULT '{}'::jsonb NOT NULL,
    q_values jsonb DEFAULT '{}'::jsonb NOT NULL,
    feasible_actions text[] DEFAULT '{}'::text[] NOT NULL,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT bid_action_valid CHECK ((action = ANY (ARRAY['withdraw'::text, 'hold'::text, 'increase_bid'::text]))),
    CONSTRAINT bid_arranged_exit_has_plan CHECK (((q_action IS DISTINCT FROM 'withdraw_alternative'::text) OR (plan ? 'target_unit'::text))),
    CONSTRAINT bid_await_exit_has_forecast CHECK (((q_action IS DISTINCT FROM 'await_next_resource'::text) OR ((plan ? 'expected_release_at'::text) AND (plan ? 'release_probability'::text)))),
    CONSTRAINT bid_q_action_matches_action CHECK (((q_action IS NULL) OR ((q_action = ANY (ARRAY['win_now'::text, 'continue'::text])) AND (action = ANY (ARRAY['increase_bid'::text, 'hold'::text]))) OR ((q_action = ANY (ARRAY['withdraw_alternative'::text, 'await_next_resource'::text, 're_enter_later'::text, 'withdraw_unplanned'::text])) AND (action = 'withdraw'::text)))),
    CONSTRAINT bid_q_action_valid CHECK (((q_action IS NULL) OR (q_action = ANY (ARRAY['win_now'::text, 'continue'::text, 'withdraw_alternative'::text, 'await_next_resource'::text, 're_enter_later'::text, 'withdraw_unplanned'::text])))),
    CONSTRAINT bid_reenter_exit_has_trigger CHECK (((q_action IS DISTINCT FROM 're_enter_later'::text) OR (plan ? 'reentry_expires_at'::text))),
    CONSTRAINT bid_unplanned_exit_has_no_plan CHECK (((q_action IS DISTINCT FROM 'withdraw_unplanned'::text) OR (plan = '{}'::jsonb))),
    CONSTRAINT bid_within_ceiling CHECK (((action = 'withdraw'::text) OR (amount <= ceiling)))
);


--
-- Name: auction_outcome; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.auction_outcome (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auction_id uuid NOT NULL,
    observed_at timestamp with time zone DEFAULT now() NOT NULL,
    horizon_hours numeric(5,2) NOT NULL,
    terms jsonb NOT NULL,
    reward_total numeric(8,3) NOT NULL,
    mortality_observed boolean,
    mortality_source text,
    complete boolean DEFAULT false NOT NULL,
    missing_terms text[] DEFAULT '{}'::text[] NOT NULL
);


--
-- Name: forecast_history; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.forecast_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    endpoint text NOT NULL,
    scope text NOT NULL,
    horizon text NOT NULL,
    forecast_for timestamp with time zone NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL,
    value numeric(12,4) NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    raw_response jsonb,
    actual_value numeric(12,4),
    actual_recorded_at timestamp with time zone
);


--
-- Name: forecast_median_30d; Type: VIEW; Schema: allocation; Owner: -
--

CREATE VIEW allocation.forecast_median_30d AS
 SELECT forecast_history.endpoint,
    forecast_history.scope,
    forecast_history.horizon,
    percentile_cont((0.5)::double precision) WITHIN GROUP (ORDER BY ((forecast_history.value)::double precision)) AS median_value,
    count(*) AS sample_count,
    min(forecast_history.computed_at) AS window_start
   FROM allocation.forecast_history
  WHERE (forecast_history.computed_at >= (now() - '30 days'::interval))
  GROUP BY forecast_history.endpoint, forecast_history.scope, forecast_history.horizon;


--
-- Name: pending_observation; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.pending_observation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auction_id uuid NOT NULL,
    closed_at timestamp with time zone NOT NULL,
    horizon_hours numeric(5,2) NOT NULL,
    due_at timestamp with time zone NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts smallint DEFAULT 0 NOT NULL,
    last_attempt_at timestamp with time zone,
    last_error text,
    observed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pending_obs_status_valid CHECK ((status = ANY (ARRAY['pending'::text, 'observed'::text, 'abandoned'::text])))
);


--
-- Name: utility_snapshot; Type: TABLE; Schema: allocation; Owner: -
--

CREATE TABLE allocation.utility_snapshot (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auction_id uuid NOT NULL,
    round_index smallint NOT NULL,
    taken_at timestamp with time zone NOT NULL,
    hospital_state jsonb NOT NULL,
    patient_data jsonb NOT NULL,
    factor_signals jsonb NOT NULL,
    caps_version text NOT NULL,
    config_version text NOT NULL
);


--
-- Name: appointments; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.appointments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id uuid,
    provider_id uuid,
    department_id uuid,
    appointment_time timestamp without time zone,
    status character varying(50),
    type character varying(100),
    patient_name text,
    phone text,
    email text,
    specialization text,
    department_name text,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: beds; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.beds (
    id uuid NOT NULL,
    branch_id uuid,
    ward text,
    bed_number text,
    room_type text,
    status text NOT NULL,
    is_active boolean NOT NULL,
    synced_at timestamp with time zone NOT NULL,
    ventilation text,
    room_sharing text,
    proximity integer,
    floor integer,
    wing text,
    natural_light boolean,
    noise_level text,
    features text[]
);


--
-- Name: checkpoint_blobs; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.checkpoint_blobs (
    thread_id text NOT NULL,
    checkpoint_ns text DEFAULT ''::text NOT NULL,
    channel text NOT NULL,
    version text NOT NULL,
    type text NOT NULL,
    blob bytea
);


--
-- Name: checkpoint_migrations; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.checkpoint_migrations (
    v integer NOT NULL
);


--
-- Name: checkpoint_writes; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.checkpoint_writes (
    thread_id text NOT NULL,
    checkpoint_ns text DEFAULT ''::text NOT NULL,
    checkpoint_id text NOT NULL,
    task_id text NOT NULL,
    idx integer NOT NULL,
    channel text NOT NULL,
    type text,
    blob bytea NOT NULL,
    task_path text DEFAULT ''::text NOT NULL
);


--
-- Name: checkpoints; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.checkpoints (
    thread_id text NOT NULL,
    checkpoint_ns text DEFAULT ''::text NOT NULL,
    checkpoint_id text NOT NULL,
    parent_checkpoint_id text,
    type text,
    checkpoint jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: claim_history; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.claim_history (
    id uuid NOT NULL,
    claim_id uuid,
    from_status text,
    to_status text,
    action text,
    changed_at timestamp with time zone,
    changed_by text,
    remarks text,
    synced_at timestamp with time zone
);


--
-- Name: claim_line_items; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.claim_line_items (
    id uuid NOT NULL,
    claim_id uuid,
    service_code text,
    service_name text,
    description text,
    quantity numeric,
    rate numeric,
    amount numeric,
    approved_amount numeric,
    approved_quantity numeric,
    approved_rate numeric,
    status text,
    category text,
    unit text,
    rejection_reason text,
    synced_at timestamp with time zone
);


--
-- Name: claim_queries; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.claim_queries (
    id uuid NOT NULL,
    claim_id uuid,
    query_type text,
    query_text text,
    status text,
    raised_at timestamp with time zone,
    raised_by text,
    responded_by text,
    response_date timestamp with time zone,
    response_text text,
    created_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: claims; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.claims (
    id uuid NOT NULL,
    patient_token text,
    visit_id text,
    tpa_id text,
    tpa_name text,
    claim_amount numeric,
    status text,
    created_at timestamp with time zone,
    submitted_date timestamp with time zone,
    approved_amount numeric,
    denial_reason text,
    claim_number text,
    payer_type text,
    risk_level text,
    risk_score numeric,
    stage text,
    compliance_status text,
    diagnosis_code text,
    branch_id uuid,
    synced_at timestamp with time zone
);


--
-- Name: contract_service_rates; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.contract_service_rates (
    id uuid NOT NULL,
    contract_id uuid,
    service_id uuid,
    service_code text,
    service_name text,
    contract_rate numeric,
    hospital_rate numeric,
    discount_percentage numeric,
    is_active boolean,
    synced_at timestamp with time zone
);


--
-- Name: daily_collections; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.daily_collections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid,
    collection_date date NOT NULL,
    cash_total numeric DEFAULT 0,
    upi_total numeric DEFAULT 0,
    card_total numeric DEFAULT 0,
    bank_transfer_total numeric DEFAULT 0,
    cheque_total numeric DEFAULT 0,
    total_collection numeric DEFAULT 0,
    invoice_count integer DEFAULT 0,
    payment_count integer DEFAULT 0,
    is_reconciled boolean DEFAULT false,
    reconciled_by uuid,
    reconciled_at timestamp with time zone,
    variance numeric DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: departments; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.departments (
    id uuid NOT NULL,
    name text NOT NULL,
    type text,
    synced_at timestamp with time zone NOT NULL,
    capacity integer,
    target_occupancy_pct integer
);


--
-- Name: discharge_summaries; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.discharge_summaries (
    id uuid NOT NULL,
    admission_id uuid,
    summary_text text,
    created_at timestamp with time zone,
    synced_at timestamp with time zone NOT NULL,
    ai_generated_note text
);


--
-- Name: doctor_slots; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.doctor_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_id uuid,
    slot_date date,
    slot_start time without time zone,
    slot_end time without time zone,
    slot_type character varying(50),
    status character varying(50),
    max_patients integer,
    booked_count integer,
    specialization text,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: hospilot_agent_registry; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.hospilot_agent_registry (
    id text NOT NULL,
    label text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    emoji text DEFAULT '🤖'::text NOT NULL,
    color text DEFAULT '#94a3b8'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hospilot_subagent_registry; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.hospilot_subagent_registry (
    id text NOT NULL,
    agent_id text NOT NULL,
    label text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    capabilities jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_prefetch_eligible boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hospilot_task_registry; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.hospilot_task_registry (
    id text NOT NULL,
    subagent_id text NOT NULL,
    label text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    outputs jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: infection_cases; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.infection_cases (
    id uuid NOT NULL,
    patient_token text,
    admission_id uuid,
    ward text,
    pathogen text,
    severity text,
    isolation_required boolean,
    isolation_confirmed boolean,
    isolation_room text,
    status text,
    reported_at timestamp with time zone,
    notes text,
    synced_at timestamp with time zone
);


--
-- Name: insurance_contracts; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.insurance_contracts (
    id uuid NOT NULL,
    insurer_name text,
    tpa_name text,
    contract_type text,
    contract_number text,
    start_date date,
    end_date date,
    status text,
    branch_id uuid,
    total_claims integer,
    approved_amount numeric,
    rejection_rate numeric,
    avg_settlement_days numeric,
    synced_at timestamp with time zone
);


--
-- Name: invoice_line_items; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.invoice_line_items (
    id uuid NOT NULL,
    invoice_id uuid,
    service_id uuid,
    service_code text,
    service_name text,
    description text,
    quantity numeric,
    rate numeric,
    amount numeric,
    total numeric,
    gst_rate numeric,
    gst_amount numeric,
    discount_amount numeric,
    source_type text,
    source_id uuid,
    synced_at timestamp with time zone
);


--
-- Name: invoices; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.invoices (
    id uuid NOT NULL,
    org_id uuid,
    invoice_number character varying(50),
    patient_id uuid,
    invoice_date timestamp with time zone,
    due_date timestamp with time zone,
    invoice_type character varying(20),
    visit_id uuid,
    admission_id uuid,
    package_id uuid,
    insurance_contract_id uuid,
    subtotal numeric DEFAULT 0,
    discount_amount numeric DEFAULT 0,
    discount_percentage numeric DEFAULT 0,
    gst_amount numeric DEFAULT 0,
    cgst_amount numeric DEFAULT 0,
    sgst_amount numeric DEFAULT 0,
    igst_amount numeric DEFAULT 0,
    grand_total numeric,
    paid_amount numeric DEFAULT 0,
    balance numeric,
    status character varying(20) DEFAULT 'Draft'::character varying,
    payment_status character varying(20) DEFAULT 'Unpaid'::character varying,
    is_inter_state boolean DEFAULT false,
    notes text,
    created_by uuid,
    updated_by uuid,
    cancelled_by uuid,
    cancelled_at timestamp with time zone,
    cancellation_reason text,
    branch_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: ipd_admissions; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.ipd_admissions (
    id uuid NOT NULL,
    patient_token text,
    bed_id uuid,
    department_id uuid,
    admitted_at timestamp with time zone,
    expected_discharge_at timestamp with time zone,
    status text,
    synced_at timestamp with time zone NOT NULL,
    discharge_ready boolean,
    discharge_blocked_reason text,
    transfer_pending boolean NOT NULL
);


--
-- Name: lab_orders; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.lab_orders (
    id uuid NOT NULL,
    visit_id uuid,
    patient_token text,
    ordered_by text,
    status text,
    priority text,
    ordered_at timestamp with time zone,
    completed_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: lab_results; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.lab_results (
    id uuid NOT NULL,
    order_id uuid,
    patient_token text,
    test_name text,
    test_code text,
    result_value text,
    flag text,
    reference_range text,
    unit text,
    reported_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: nursing_tasks; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.nursing_tasks (
    id uuid NOT NULL,
    admission_id uuid,
    task text NOT NULL,
    completed boolean,
    due_at timestamp with time zone,
    assigned_to text,
    synced_at timestamp with time zone NOT NULL
);


--
-- Name: ot_surgeries; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.ot_surgeries (
    id uuid NOT NULL,
    admission_id uuid,
    patient_token text,
    ward text,
    status text,
    created_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: patients; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.patients (
    id uuid NOT NULL,
    first_name text,
    last_name text,
    uhid text,
    synced_at timestamp with time zone
);


--
-- Name: payment_entries; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.payment_entries (
    id uuid NOT NULL,
    payment_id uuid,
    payment_mode text,
    amount numeric,
    transaction_reference text,
    bank_name text,
    card_last_four text,
    created_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: payment_reconciliation; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.payment_reconciliation (
    id uuid NOT NULL,
    reconciliation_date date NOT NULL,
    total_expected numeric,
    total_actual numeric,
    total_variance numeric,
    actual_cash numeric,
    actual_card numeric,
    actual_upi numeric,
    actual_bank numeric,
    cash_variance numeric,
    card_variance numeric,
    upi_variance numeric,
    bank_variance numeric,
    status text,
    created_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: payments; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.payments (
    id uuid NOT NULL,
    org_id uuid,
    receipt_number character varying(50),
    invoice_id uuid,
    patient_id uuid,
    payment_date timestamp with time zone,
    total_amount numeric,
    status character varying(20) DEFAULT 'Completed'::character varying,
    received_by uuid,
    notes text,
    branch_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: purchase_orders; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.purchase_orders (
    id uuid NOT NULL,
    po_number text,
    vendor_id uuid,
    status text,
    total numeric,
    order_date date,
    expected_delivery date,
    created_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: refunds; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.refunds (
    id uuid NOT NULL,
    invoice_id uuid,
    payment_id uuid,
    refund_amount numeric,
    reason text,
    status text,
    refund_date date,
    refund_mode text,
    refund_number text,
    created_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: service_slots; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.service_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slot_type character varying(50),
    slot_date date,
    slot_start time without time zone,
    slot_end time without time zone,
    location text,
    specialization text,
    max_patients integer DEFAULT 1,
    booked_count integer DEFAULT 0,
    status character varying(50) DEFAULT 'open'::character varying,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: staff_roster; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.staff_roster (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    area character varying(50),
    area_label text,
    role character varying(50),
    shift character varying(20),
    headcount integer DEFAULT 0,
    assigned_load integer DEFAULT 0,
    load_per_staff integer DEFAULT 1,
    branch_id uuid,
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: supplies; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.supplies (
    id uuid NOT NULL,
    item_code text,
    item_name text,
    category text,
    current_stock numeric,
    min_stock numeric,
    unit text,
    unit_cost numeric,
    last_ordered_at timestamp with time zone,
    last_received_at timestamp with time zone,
    synced_at timestamp with time zone
);


--
-- Name: visits; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.visits (
    id uuid NOT NULL,
    patient_token text,
    department_id uuid,
    arrived_at timestamp with time zone,
    status text,
    chief_complaint text,
    synced_at timestamp with time zone NOT NULL,
    triage_score integer,
    visit_type text,
    appointment_id uuid
);


--
-- Name: vitals; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.vitals (
    id uuid NOT NULL,
    patient_token text,
    admission_id uuid,
    recorded_at timestamp with time zone NOT NULL,
    temperature numeric,
    pulse integer,
    bp_systolic integer,
    bp_diastolic integer,
    spo2 integer,
    respiratory_rate integer,
    gcs integer,
    synced_at timestamp with time zone NOT NULL,
    is_critical boolean
);


--
-- Name: waitlist; Type: TABLE; Schema: hospilot; Owner: -
--

CREATE TABLE hospilot.waitlist (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    patient_id uuid,
    patient_name text,
    phone text,
    email text,
    specialization text,
    priority character varying(20) DEFAULT 'medium'::character varying,
    requested_date date,
    status character varying(50) DEFAULT 'waitlisted'::character varying,
    reason text,
    created_at timestamp with time zone DEFAULT now(),
    synced_at timestamp with time zone DEFAULT now()
);


--
-- Name: advisories; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.advisories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_key text NOT NULL,
    topic text NOT NULL,
    severity text DEFAULT 'warning'::text NOT NULL,
    title text NOT NULL,
    detail text,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    suggested_action text,
    status text DEFAULT 'active'::text NOT NULL,
    acknowledged_by uuid,
    acknowledged_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT advisories_status_check CHECK ((status = ANY (ARRAY['active'::text, 'acknowledged'::text, 'resolved'::text])))
);


--
-- Name: advisory_rules; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.advisory_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    rule_key text NOT NULL,
    topic text NOT NULL,
    label text NOT NULL,
    condition_description text NOT NULL,
    suggested_action text NOT NULL,
    severity text DEFAULT 'warning'::text NOT NULL,
    definition jsonb DEFAULT '{}'::jsonb NOT NULL,
    trigger_entities jsonb DEFAULT '[]'::jsonb NOT NULL,
    check_interval_seconds integer,
    cooldown_seconds integer DEFAULT 3600 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    next_check_at timestamp with time zone DEFAULT now(),
    last_checked_at timestamp with time zone,
    last_fired_at timestamp with time zone,
    fire_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT advisory_rules_cooldown_nonneg CHECK ((cooldown_seconds >= 0)),
    CONSTRAINT advisory_rules_has_trigger CHECK (((jsonb_array_length(trigger_entities) > 0) OR (check_interval_seconds IS NOT NULL))),
    CONSTRAINT advisory_rules_interval_positive CHECK (((check_interval_seconds IS NULL) OR (check_interval_seconds > 0))),
    CONSTRAINT advisory_rules_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text])))
);


--
-- Name: agent_registry; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.agent_registry (
    id text NOT NULL,
    label text NOT NULL,
    description text,
    emoji text,
    color text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: approval_tasks; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.approval_tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    agent_id text NOT NULL,
    action_type text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    kind text DEFAULT 'approval'::text NOT NULL,
    decision text,
    approver_id text,
    decided_at timestamp with time zone,
    escalation_level integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT approval_tasks_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'resolved'::text, 'cancelled'::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    agent_id text NOT NULL,
    event_type text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: organizations; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    db_name text,
    hasura_source text DEFAULT 'default'::text NOT NULL,
    root_prefix text DEFAULT ''::text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rag_conversation; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.rag_conversation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    title text,
    running_summary text,
    summary_through_seq integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rag_memory; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.rag_memory (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    kind text DEFAULT 'semantic'::text NOT NULL,
    content jsonb DEFAULT '{}'::jsonb NOT NULL,
    salience real DEFAULT 0 NOT NULL,
    embedding jsonb,
    embedding_model text,
    embedding_dim integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rag_memory_kind_check CHECK ((kind = ANY (ARRAY['semantic'::text, 'episodic'::text, 'procedural'::text])))
);


--
-- Name: rag_message; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.rag_message (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    seq integer NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    sql text,
    mode text,
    row_count integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rag_message_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text])))
);


--
-- Name: scheduled_queries; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.scheduled_queries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text,
    goal text NOT NULL,
    constraints text,
    schedule_kind text DEFAULT 'interval'::text NOT NULL,
    interval_seconds integer,
    cron_expr text,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    autonomous boolean DEFAULT true NOT NULL,
    next_run_at timestamp with time zone NOT NULL,
    last_run_at timestamp with time zone,
    last_session_id uuid,
    run_count integer DEFAULT 0 NOT NULL,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT scheduled_queries_interval_positive CHECK (((interval_seconds IS NULL) OR (interval_seconds > 0))),
    CONSTRAINT scheduled_queries_kind_check CHECK ((schedule_kind = ANY (ARRAY['interval'::text, 'cron'::text])))
);


--
-- Name: session_agent_overrides; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.session_agent_overrides (
    session_id uuid NOT NULL,
    agent_id text NOT NULL,
    tasks jsonb NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.sessions (
    id uuid NOT NULL,
    goal text NOT NULL,
    constraints text,
    status text DEFAULT 'pending'::text NOT NULL,
    priority text,
    pipeline jsonb DEFAULT '{}'::jsonb NOT NULL,
    pipeline_snapshot jsonb,
    synthesis_result jsonb,
    user_id uuid,
    autonomous boolean DEFAULT false NOT NULL,
    name text,
    scheduled_query_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT sessions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'completed'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: subagent_registry; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.subagent_registry (
    id text NOT NULL,
    agent_id text NOT NULL,
    label text NOT NULL,
    description text,
    capabilities jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_prefetch_eligible boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: task_registry; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.task_registry (
    id text NOT NULL,
    subagent_id text NOT NULL,
    label text NOT NULL,
    description text,
    outputs jsonb DEFAULT '[]'::jsonb NOT NULL,
    function_code text,
    is_dynamic boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: hospilot_app; Owner: -
--

CREATE TABLE hospilot_app.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    display_name text NOT NULL,
    role text DEFAULT 'doctor'::text NOT NULL,
    org_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    approved_by uuid,
    approved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: checkpoint_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkpoint_blobs (
    thread_id text NOT NULL,
    checkpoint_ns text DEFAULT ''::text NOT NULL,
    channel text NOT NULL,
    version text NOT NULL,
    type text NOT NULL,
    blob bytea
);


--
-- Name: checkpoint_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkpoint_migrations (
    v integer NOT NULL
);


--
-- Name: checkpoint_writes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkpoint_writes (
    thread_id text NOT NULL,
    checkpoint_ns text DEFAULT ''::text NOT NULL,
    checkpoint_id text NOT NULL,
    task_id text NOT NULL,
    idx integer NOT NULL,
    channel text NOT NULL,
    type text,
    blob bytea NOT NULL,
    task_path text DEFAULT ''::text NOT NULL
);


--
-- Name: checkpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkpoints (
    thread_id text NOT NULL,
    checkpoint_ns text DEFAULT ''::text NOT NULL,
    checkpoint_id text NOT NULL,
    parent_checkpoint_id text,
    type text,
    checkpoint jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Data for Name: agent_budget; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.agent_budget (id, agent, shift_id, shift_start, shift_end, base, demand_factor, criticality_factor, fairness_factor, scarcity_factor, factor_sources, budget_total, budget_remaining, spent_this_shift, recovered_this_shift, source, n_win, n_req, cost_per_win, cost_per_loss, caps_version, config_version, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: auction; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.auction (id, auction_key, resource_type, resource_id, mode, trigger_source, predicted_free_at, opened_at, closed_at, max_rounds, rounds_run, reserve_price, winning_agent, winning_candidate_id, winning_bid, outcome, caps_version, config_version, unsigned_rules, participants, created_at) FROM stdin;
\.


--
-- Data for Name: auction_bid; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.auction_bid (id, auction_id, round_index, agent, candidate_id, patient_token, action, amount, utility, ceiling, alpha, contention, outcome_factor, cost, component_points, component_coverage, policy_name, q_action, plan, q_values, feasible_actions, decided_at) FROM stdin;
\.


--
-- Data for Name: auction_outcome; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.auction_outcome (id, auction_id, observed_at, horizon_hours, terms, reward_total, mortality_observed, mortality_source, complete, missing_terms) FROM stdin;
\.


--
-- Data for Name: forecast_history; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.forecast_history (id, endpoint, scope, horizon, forecast_for, computed_at, value, payload, raw_response, actual_value, actual_recorded_at) FROM stdin;
\.


--
-- Data for Name: pending_observation; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.pending_observation (id, auction_id, closed_at, horizon_hours, due_at, status, attempts, last_attempt_at, last_error, observed_at, created_at) FROM stdin;
\.


--
-- Data for Name: utility_snapshot; Type: TABLE DATA; Schema: allocation; Owner: -
--

COPY allocation.utility_snapshot (id, auction_id, round_index, taken_at, hospital_state, patient_data, factor_signals, caps_version, config_version) FROM stdin;
\.


--
-- Data for Name: appointments; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.appointments (id, patient_id, provider_id, department_id, appointment_time, status, type, patient_name, phone, email, specialization, department_name, synced_at) FROM stdin;
\.


--
-- Data for Name: beds; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.beds (id, branch_id, ward, bed_number, room_type, status, is_active, synced_at, ventilation, room_sharing, proximity, floor, wing, natural_light, noise_level, features) FROM stdin;
\.


--
-- Data for Name: checkpoint_migrations; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.checkpoint_migrations (v) FROM stdin;
0
1
2
3
4
5
6
7
8
9
\.


--
-- Data for Name: claim_history; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.claim_history (id, claim_id, from_status, to_status, action, changed_at, changed_by, remarks, synced_at) FROM stdin;
\.


--
-- Data for Name: claim_line_items; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.claim_line_items (id, claim_id, service_code, service_name, description, quantity, rate, amount, approved_amount, approved_quantity, approved_rate, status, category, unit, rejection_reason, synced_at) FROM stdin;
\.


--
-- Data for Name: claim_queries; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.claim_queries (id, claim_id, query_type, query_text, status, raised_at, raised_by, responded_by, response_date, response_text, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: claims; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.claims (id, patient_token, visit_id, tpa_id, tpa_name, claim_amount, status, created_at, submitted_date, approved_amount, denial_reason, claim_number, payer_type, risk_level, risk_score, stage, compliance_status, diagnosis_code, branch_id, synced_at) FROM stdin;
\.


--
-- Data for Name: contract_service_rates; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.contract_service_rates (id, contract_id, service_id, service_code, service_name, contract_rate, hospital_rate, discount_percentage, is_active, synced_at) FROM stdin;
\.


--
-- Data for Name: daily_collections; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.daily_collections (id, org_id, collection_date, cash_total, upi_total, card_total, bank_transfer_total, cheque_total, total_collection, invoice_count, payment_count, is_reconciled, reconciled_by, reconciled_at, variance, created_at, updated_at, synced_at) FROM stdin;
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.departments (id, name, type, synced_at, capacity, target_occupancy_pct) FROM stdin;
\.


--
-- Data for Name: discharge_summaries; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.discharge_summaries (id, admission_id, summary_text, created_at, synced_at, ai_generated_note) FROM stdin;
\.


--
-- Data for Name: doctor_slots; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.doctor_slots (id, provider_id, slot_date, slot_start, slot_end, slot_type, status, max_patients, booked_count, specialization, synced_at) FROM stdin;
\.


--
-- Data for Name: hospilot_agent_registry; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.hospilot_agent_registry (id, label, description, emoji, color, is_active, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: hospilot_subagent_registry; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.hospilot_subagent_registry (id, agent_id, label, description, capabilities, is_active, is_prefetch_eligible, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: hospilot_task_registry; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.hospilot_task_registry (id, subagent_id, label, description, outputs, is_active, sort_order, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: infection_cases; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.infection_cases (id, patient_token, admission_id, ward, pathogen, severity, isolation_required, isolation_confirmed, isolation_room, status, reported_at, notes, synced_at) FROM stdin;
\.


--
-- Data for Name: insurance_contracts; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.insurance_contracts (id, insurer_name, tpa_name, contract_type, contract_number, start_date, end_date, status, branch_id, total_claims, approved_amount, rejection_rate, avg_settlement_days, synced_at) FROM stdin;
\.


--
-- Data for Name: invoice_line_items; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.invoice_line_items (id, invoice_id, service_id, service_code, service_name, description, quantity, rate, amount, total, gst_rate, gst_amount, discount_amount, source_type, source_id, synced_at) FROM stdin;
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.invoices (id, org_id, invoice_number, patient_id, invoice_date, due_date, invoice_type, visit_id, admission_id, package_id, insurance_contract_id, subtotal, discount_amount, discount_percentage, gst_amount, cgst_amount, sgst_amount, igst_amount, grand_total, paid_amount, balance, status, payment_status, is_inter_state, notes, created_by, updated_by, cancelled_by, cancelled_at, cancellation_reason, branch_id, created_at, updated_at, synced_at) FROM stdin;
\.


--
-- Data for Name: ipd_admissions; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.ipd_admissions (id, patient_token, bed_id, department_id, admitted_at, expected_discharge_at, status, synced_at, discharge_ready, discharge_blocked_reason, transfer_pending) FROM stdin;
\.


--
-- Data for Name: lab_orders; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.lab_orders (id, visit_id, patient_token, ordered_by, status, priority, ordered_at, completed_at, synced_at) FROM stdin;
\.


--
-- Data for Name: lab_results; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.lab_results (id, order_id, patient_token, test_name, test_code, result_value, flag, reference_range, unit, reported_at, synced_at) FROM stdin;
\.


--
-- Data for Name: nursing_tasks; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.nursing_tasks (id, admission_id, task, completed, due_at, assigned_to, synced_at) FROM stdin;
\.


--
-- Data for Name: ot_surgeries; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.ot_surgeries (id, admission_id, patient_token, ward, status, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: patients; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.patients (id, first_name, last_name, uhid, synced_at) FROM stdin;
\.


--
-- Data for Name: payment_entries; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.payment_entries (id, payment_id, payment_mode, amount, transaction_reference, bank_name, card_last_four, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: payment_reconciliation; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.payment_reconciliation (id, reconciliation_date, total_expected, total_actual, total_variance, actual_cash, actual_card, actual_upi, actual_bank, cash_variance, card_variance, upi_variance, bank_variance, status, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.payments (id, org_id, receipt_number, invoice_id, patient_id, payment_date, total_amount, status, received_by, notes, branch_id, created_at, updated_at, synced_at) FROM stdin;
\.


--
-- Data for Name: purchase_orders; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.purchase_orders (id, po_number, vendor_id, status, total, order_date, expected_delivery, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: refunds; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.refunds (id, invoice_id, payment_id, refund_amount, reason, status, refund_date, refund_mode, refund_number, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: service_slots; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.service_slots (id, slot_type, slot_date, slot_start, slot_end, location, specialization, max_patients, booked_count, status, synced_at) FROM stdin;
\.


--
-- Data for Name: staff_roster; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.staff_roster (id, area, area_label, role, shift, headcount, assigned_load, load_per_staff, branch_id, synced_at) FROM stdin;
\.


--
-- Data for Name: supplies; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.supplies (id, item_code, item_name, category, current_stock, min_stock, unit, unit_cost, last_ordered_at, last_received_at, synced_at) FROM stdin;
\.


--
-- Data for Name: visits; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.visits (id, patient_token, department_id, arrived_at, status, chief_complaint, synced_at, triage_score, visit_type, appointment_id) FROM stdin;
\.


--
-- Data for Name: vitals; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.vitals (id, patient_token, admission_id, recorded_at, temperature, pulse, bp_systolic, bp_diastolic, spo2, respiratory_rate, gcs, synced_at, is_critical) FROM stdin;
\.


--
-- Data for Name: waitlist; Type: TABLE DATA; Schema: hospilot; Owner: -
--

COPY hospilot.waitlist (id, patient_id, patient_name, phone, email, specialization, priority, requested_date, status, reason, created_at, synced_at) FROM stdin;
\.


--
-- Data for Name: advisories; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.advisories (id, rule_key, topic, severity, title, detail, data, suggested_action, status, acknowledged_by, acknowledged_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: advisory_rules; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.advisory_rules (id, rule_key, topic, label, condition_description, suggested_action, severity, definition, trigger_entities, check_interval_seconds, cooldown_seconds, enabled, next_check_at, last_checked_at, last_fired_at, fire_count, created_at, updated_at) FROM stdin;
c2b901ce-f276-49c9-aebd-a91fb3894ba7	rc_billing_backlog	Revenue Cycle	Billing backlog	Billing backlog	Redistribute billing workload	warning	{"condition": {"params": {"max_draft_invoices": 15}, "handler": "rc_billing_backlog"}}	[]	1800	14400	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
e2ae54ce-5e22-4303-a8d5-9c57498b2b18	bed_occupancy_high	Bed Management	High bed occupancy	Bed occupancy > 90%	Prioritize discharge-ready patients and optimize bed allocation	warning	{"condition": {"kind": "dict", "field": "occupancy_pct", "source": "beds_summary", "operator": ">", "threshold": 90, "detail_template": "Bed occupancy is {occupancy_pct:.0f}% ({occupied_beds}/{total_beds} beds), threshold {threshold:.0f}%"}}	["bed", "admission"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.032126+00
821cf8d5-ea54-4b19-86de-ce03fa1660da	bed_occupancy_forecast_critical	Bed Management	Occupancy forecast critical	Bed occupancy predicted >95% in next 6 hours	Run capacity simulation and notify operations command center	critical	{"condition": {"params": {"horizon_hours": 6, "predicted_occupancy_pct_threshold": 95}, "handler": "bed_occupancy_forecast_critical"}}	[]	900	7200	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
77c3f600-8827-4f7d-9bf6-31504b21db93	icu_stepdown_pending	Bed Management	ICU step-down candidates	ICU step-down patients identified	Initiate transfer workflow to ward	info	{"condition": {"filter": [{"op": "truthy", "field": "discharge_ready"}], "source": "icu_admissions", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} ICU patient(s) ready for step-down to ward"}}	["admission", "discharge_ready"]	900	14400	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.034933+00
174e6bc3-f114-456b-a382-8676e4330fc6	er_boarding_pressure	Bed Management	ER boarding pressure	ER boarding patients > threshold	Reserve next available inpatient beds automatically	warning	{"condition": {"params": {"max_boarders": 5}, "handler": "er_boarding_pressure"}}	["visit"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
4b7bc560-fd4d-41a6-a83b-4292e9c78cea	er_triage_queue_high	Emergency	Triage queue increasing	Untriaged ER patients exceed the backlog threshold	Assign a triage nurse and fast-track waiting patients	warning	{"condition": {"source": "untriaged", "operator": ">", "aggregate": "count", "threshold": 5, "detail_template": "{value} patient(s) awaiting triage (threshold {threshold:.0f})"}}	["visit"]	300	1800	t	2026-09-09 19:01:34.005665+00	\N	\N	0	2026-09-09 19:01:34.005665+00	2026-09-09 19:01:34.037243+00
f9533fa0-dd0b-4f38-ab11-8cba064a4023	er_ambulance_arrivals_high	Emergency	Ambulance arrivals increasing	Inbound ambulances exceed the threshold	Prepare resuscitation bays and pre-stage triage staff for incoming patients	info	{"condition": {"filter": [{"op": "in", "field": "status", "value": ["En Route", "En-Route", "Enroute", "Dispatched", "Incoming"]}], "source": "ambulances", "operator": ">", "aggregate": "count", "threshold": 3, "detail_template": "{value} ambulance(s) inbound (threshold {threshold:.0f})"}}	["ambulance"]	300	1800	t	2026-09-09 19:01:34.005665+00	\N	\N	0	2026-09-09 19:01:34.005665+00	2026-09-09 19:01:34.040108+00
4674c07e-01e1-4d10-8d17-ddb2b58abd2b	er_boarding_patients_high	Emergency	Boarding patients increasing	Patients awaiting inpatient admission (boarding) exceed the threshold	Coordinate with bed management to expedite inpatient bed assignment	warning	{"condition": {"kind": "dict", "field": "est_admissions", "source": "er_pressure", "operator": ">", "threshold": 20, "detail_template": "{value:.0f} patient(s) awaiting admission/boarding (threshold {threshold:.0f})"}}	["visit", "admission"]	300	3600	t	2026-09-09 19:01:34.005665+00	\N	\N	0	2026-09-09 19:01:34.005665+00	2026-09-09 19:01:34.042952+00
04a4a09b-4d06-49dd-8fa6-0dc6fa78234f	icu_occupancy_high	ICU	High ICU occupancy	ICU occupancy > 90%	Expedite step-down transfers and review pending ICU admissions	warning	{"condition": {"kind": "dict", "field": "icu_pct", "source": "beds_summary", "operator": ">", "threshold": 90, "detail_template": "ICU occupancy is {icu_pct:.0f}% ({icu_occupied}/{icu_total} beds), threshold {threshold:.0f}%", "require_positive": ["icu_total"]}}	["bed", "admission"]	300	3600	t	2026-09-09 19:01:34.018132+00	\N	\N	0	2026-09-09 19:01:34.018132+00	2026-09-09 19:01:34.044207+00
d412c412-6392-4b0e-8838-892ddb7ea3c6	lab_analyzer_down	Laboratory	Analyzer down	Analyzer downtime	Redirect samples to alternate analyzer	warning	{"condition": {"params": {"min_down": 1, "up_statuses": ["Online"]}, "handler": "lab_analyzer_down"}}	["lab_analyzer"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
d4d0eba0-519c-4362-9a86-ef854ee5d5ee	icu_ventilator_utilization_high	ICU	Ventilator utilization high	In-use ventilators > 85% of operational units	Audit weaning candidates and check maintenance-held ventilators	warning	{"condition": {"source": "ventilators", "operator": ">", "aggregate": "ratio", "threshold": 85, "detail_template": "Ventilator utilization {value:.0f}% ({numerator}/{denominator} in use), threshold {threshold:.0f}%", "numerator_filter": [{"op": "contains_any", "field": "status", "value": ["use"]}], "denominator_filter": [{"op": "contains_any", "field": "status", "value": ["use", "avail"]}]}}	["ventilator"]	300	3600	t	2026-09-09 19:01:34.018132+00	\N	\N	0	2026-09-09 19:01:34.018132+00	2026-09-09 19:01:34.048853+00
ed0c79fc-bfa2-4157-8152-77c8e0cb868b	ambulance_eta_exceeds_sla	Ambulance	ETA exceeds SLA	A dispatched ambulance ETA exceeds the SLA	Notify ER and suggest alternate ambulance	warning	{"condition": {"filter": [{"op": "not_null", "field": "eta_mins"}, {"op": ">", "field": "eta_mins", "value": 15}], "labels": {"sla": 15}, "source": "ambulances", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} ambulance(s) with ETA over {sla:g} min SLA (alert at {threshold:.0f}+)"}}	["ambulance"]	120	900	t	2026-09-09 19:01:34.021435+00	\N	\N	0	2026-09-09 19:01:34.021435+00	2026-09-09 19:01:34.051548+00
fa7569d3-ff33-44cb-99dd-d6598da5a79b	ambulance_maintenance_overdue	Ambulance	Ambulance maintenance overdue	One or more ambulances are overdue for maintenance	Remove vehicle from active fleet	info	{"condition": {"filter": [{"any": [{"op": "in", "field": "status", "value": ["maintenance", "out of service", "overdue"]}, {"op": "age_gt_minutes", "field": "next_maintenance", "value": 0}, {"op": "age_gt_minutes", "field": "maintenance_due", "value": 0}, {"op": "age_gt_minutes", "field": "next_service", "value": 0}]}], "source": "ambulances", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} ambulance(s) overdue for maintenance (alert at {threshold:.0f}+)"}}	["ambulance"]	3600	86400	t	2026-09-09 19:01:34.021435+00	\N	\N	0	2026-09-09 19:01:34.021435+00	2026-09-09 19:01:34.054565+00
32584a98-2f55-4bfd-8912-a7be790e20dc	pharmacy_queue_increasing	Pharmacy	Pharmacy queue increasing	Undispensed pharmacy orders exceed the queue threshold	Open additional dispensing counter	warning	{"condition": {"filter": [{"op": "is_null", "field": "dispensed_at"}, {"op": "in", "field": "status", "value": ["pending", "on_hold", "dispensing", "ordered"]}], "source": "pharmacy_orders", "operator": ">", "aggregate": "count", "threshold": 5, "detail_template": "{value} order(s) in the dispensing queue (threshold {threshold:.0f})"}}	["pharmacy_order"]	300	1800	t	2026-09-09 19:01:34.023023+00	\N	\N	0	2026-09-09 19:01:34.023023+00	2026-09-09 19:01:34.061137+00
aa2c6155-39dc-4d2c-97d4-901495f6c940	pharmacy_inventory_below_reorder	Pharmacy	Inventory below reorder level	Inventory items at or below their reorder level	Create procurement request	warning	{"condition": {"filter": [{"op": "le_field", "field": "stock_quantity", "value": "reorder_level"}], "source": "pharmacy_inventory", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} item(s) at/below reorder level (alert at {threshold:.0f}+)"}}	["pharmacy_inventory"]	600	3600	t	2026-09-09 19:01:34.023023+00	\N	\N	0	2026-09-09 19:01:34.023023+00	2026-09-09 19:01:34.065355+00
6e24e035-afa2-4831-b245-a27ec14b2c4a	staffing_shortage_detected	Staffing	Staff shortage detected	On-duty staff below the required minimum	Call in on-call staff and redistribute workload across departments	warning	{"condition": {"filter": [{"op": "in", "field": "on_duty_status", "value": ["on_duty", "on-duty", "present", "available", "working", "active", "duty"]}], "source": "staff", "operator": "<", "aggregate": "count", "threshold": 40, "detail_template": "{value} staff on duty (minimum {threshold:.0f}) of {total} total", "require_source_nonempty": true}}	["staff"]	600	3600	t	2026-09-09 19:01:34.019918+00	\N	\N	0	2026-09-09 19:01:34.019918+00	2026-09-09 19:01:34.075689+00
79dad7ca-297e-4833-a8e4-3e00fd93a95f	icu_predicted_full	ICU	ICU predicted full	ML forecast projects ICU census to reach capacity within 24h	Pre-plan overnight ICU beds and anaesthetist/intensivist cover	warning	{"condition": {"params": {}, "handler": "icu_predicted_full"}}	[]	900	3600	t	2026-09-09 19:01:34.018132+00	\N	\N	0	2026-09-09 19:01:34.018132+00	2026-09-09 19:01:34.078686+00
603ab7d8-628d-41f8-b26d-956cc302ed6a	icu_nurse_ratio_below_policy	ICU	ICU nurse ratio below policy	ICU nurse-to-patient load exceeds policy	Reallocate nursing staff or call in additional ICU nurses	warning	{"condition": {"params": {"roster_area": "icu", "max_patients_per_nurse": 2}, "handler": "icu_nurse_ratio_below_policy"}}	["staff_roster", "admission"]	600	3600	t	2026-09-09 19:01:34.018132+00	\N	\N	0	2026-09-09 19:01:34.018132+00	2026-09-09 19:01:34.078686+00
beea776d-e155-412b-b260-5b7bbf209f07	dirty_beds_backlog	Bed Management	Housekeeping backlog	Beds awaiting cleaning > 10	Create housekeeping tasks and reprioritize cleaning staff	warning	{"condition": {"source": "dirty_beds", "operator": ">", "aggregate": "count", "threshold": 10, "detail_template": "{value} beds awaiting cleaning (threshold {threshold:.0f})"}}	["bed"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.033753+00
5924aef3-dc0a-4cc8-8fde-250d6940eaa4	er_wait_time_high	Emergency	ER wait time exceeded	ER patients waiting longer than 30 minutes	Review the ER triage queue and allocate staff to reduce wait times	warning	{"condition": {"args": {"minutes": 30}, "labels": {"minutes": 30}, "source": "er_long_wait", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} ER patient(s) waiting over {minutes:g} min (alert at {threshold:.0f}+)"}}	["visit"]	300	1800	t	2026-09-09 19:01:34.005665+00	\N	\N	0	2026-09-09 19:01:34.005665+00	2026-09-09 19:01:34.036217+00
775fecaa-4acf-49a4-a145-107fd81f981a	er_critical_patient_waiting	Emergency	Critical patient waiting	One or more critical patients are awaiting care in the ER	Escalate to the on-call physician and prioritize critical patients immediately	critical	{"condition": {"filter": [{"op": "truthy", "field": "is_critical"}], "source": "critical_vitals", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} critical patient(s) awaiting care (alert at {threshold:.0f}+)"}}	["visit"]	180	900	t	2026-09-09 19:01:34.005665+00	\N	\N	0	2026-09-09 19:01:34.005665+00	2026-09-09 19:01:34.038891+00
50d93f31-dc1a-4bca-9def-00d9949115ac	er_occupancy_high	Emergency	ER occupancy critical	ER occupancy above 95% of capacity	Open surge capacity and expedite admissions/discharges out of the ER	critical	{"condition": {"labels": {"capacity": 50}, "source": "active_er", "operator": ">", "aggregate": "pct_of", "threshold": 95, "denominator": 50, "detail_template": "ER occupancy is {value:.0f}% ({count}/{capacity} capacity), threshold {threshold:.0f}%", "require_source_nonempty": true}}	["visit"]	300	1800	t	2026-09-09 19:01:34.005665+00	\N	\N	0	2026-09-09 19:01:34.005665+00	2026-09-09 19:01:34.041528+00
2dfb126f-267f-431c-a0fe-59d874f8cbdd	icu_step_down_eligible	ICU	Step-down eligible patients	ICU patients flagged ready for step-down / discharge	Coordinate step-down transfers to free ICU capacity	info	{"condition": {"filter": [{"op": "truthy", "field": "discharge_ready"}], "source": "icu_admissions", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} ICU patient(s) eligible for step-down (alert at {threshold:.0f}+)"}}	["admission", "discharge_ready"]	300	3600	t	2026-09-09 19:01:34.018132+00	\N	\N	0	2026-09-09 19:01:34.018132+00	2026-09-09 19:01:34.046012+00
582ac361-81bd-456d-a2e8-b4436397adcf	icu_admission_pending	ICU	ICU admission pending	ICU has no free beds -- incoming admissions will queue	Trigger overflow protocol and expedite discharges out of ICU	critical	{"condition": {"kind": "dict", "field": "icu_available", "source": "beds_summary", "operator": "<=", "threshold": 0, "detail_template": "ICU has {icu_available} free bed(s) of {icu_total} -- incoming admissions will queue", "require_positive": ["icu_total"]}}	["bed", "admission"]	300	1800	t	2026-09-09 19:01:34.018132+00	\N	\N	0	2026-09-09 19:01:34.018132+00	2026-09-09 19:01:34.047438+00
59380fef-ed0a-4946-a4e6-a6717c74740b	ambulance_none_available	Ambulance	No ambulance available	No ambulance available in the active fleet	Dispatch nearest available ambulance	critical	{"condition": {"filter": [{"op": "==", "field": "status", "value": "available"}], "source": "ambulances", "operator": "<", "aggregate": "count", "threshold": 1, "detail_template": "{value} ambulance(s) available (minimum {threshold:.0f}) of {total} fleet", "require_source_nonempty": true}}	["ambulance"]	120	900	t	2026-09-09 19:01:34.021435+00	\N	\N	0	2026-09-09 19:01:34.021435+00	2026-09-09 19:01:34.050162+00
7634236f-9695-41aa-ba32-65274a9ef343	ambulance_multiple_emergency_calls	Ambulance	Multiple emergency calls	Multiple concurrent emergency calls in progress	Prioritize cases based on severity	warning	{"condition": {"filter": [{"op": "not_null", "field": "emergency_type"}], "source": "ambulances", "operator": ">", "aggregate": "count", "threshold": 3, "detail_template": "{value} active emergency call(s) in progress (threshold {threshold:.0f})"}}	["ambulance"]	120	900	t	2026-09-09 19:01:34.021435+00	\N	\N	0	2026-09-09 19:01:34.021435+00	2026-09-09 19:01:34.052972+00
bc347518-7c12-4144-82a0-65897aaa425a	pharmacy_drug_out_of_stock	Pharmacy	Drug out of stock	One or more drugs have zero stock on hand	Recommend substitute medication and notify procurement	critical	{"condition": {"filter": [{"op": "<=", "field": "stock_quantity", "value": 0}], "source": "pharmacy_inventory", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} drug(s) out of stock (alert at {threshold:.0f}+)"}}	["pharmacy_inventory"]	600	3600	t	2026-09-09 19:01:34.023023+00	\N	\N	0	2026-09-09 19:01:34.023023+00	2026-09-09 19:01:34.058337+00
f30457cd-b16e-49bd-a619-cf2600d3c20d	patient_transfer_pending	Patient Flow	Transfer pending	One or more patient transfers are pending	Initiate patient transfer workflow	warning	{"condition": {"filter": [{"op": "truthy", "field": "transfer_pending"}], "source": "admissions_with_wards", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} patient transfer(s) pending (alert at {threshold:.0f}+)"}}	["admission"]	300	1800	t	2026-09-09 19:01:34.024743+00	\N	\N	0	2026-09-09 19:01:34.024743+00	2026-09-09 19:01:34.069442+00
5e2a84a4-50a0-4a45-a6a0-ae24a42a2583	patient_referral_pending	Patient Flow	Referral pending	Patients awaiting a specialty referral/consult (heuristic)	Notify specialty department	info	{"condition": {"filter": [{"op": "contains_any", "field": "discharge_blocked_reason", "value": ["referral", "consult", "specialist", "specialty", "needs_review", "review"]}], "source": "admissions_with_wards", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} patient(s) with a pending referral/specialty review (alert at {threshold:.0f}+)"}}	["admission"]	600	3600	t	2026-09-09 19:01:34.024743+00	\N	\N	0	2026-09-09 19:01:34.024743+00	2026-09-09 19:01:34.072321+00
2f3cfd3a-8d56-4de8-b8c6-45387b1d0773	patient_readmission_risk	Patient Flow	Readmission risk identified	Patients discharged then readmitted (readmission-risk proxy)	Schedule care coordination follow-up	warning	{"condition": {"params": {"min_readmissions": 1}, "handler": "patient_readmission_risk"}}	["admission", "discharge_ready"]	600	3600	t	2026-09-09 19:01:34.024743+00	\N	\N	0	2026-09-09 19:01:34.024743+00	2026-09-09 19:01:34.078686+00
4d1c698a-fa95-4861-b658-d48a02613f9e	pharmacy_delivery_delayed	Pharmacy	Medication delivery delayed	Medication orders undispensed beyond the delivery SLA	Prioritize discharge medications	warning	{"condition": {"filter": [{"op": "is_null", "field": "dispensed_at"}, {"op": "age_gt_minutes", "field": "prescribed_at", "value": 120}], "labels": {"delay": 120}, "source": "pharmacy_orders", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} medication order(s) delayed over {delay:g} min (alert at {threshold:.0f}+)"}}	["pharmacy_order"]	300	1800	t	2026-09-09 19:01:34.023023+00	\N	\N	0	2026-09-09 19:01:34.023023+00	2026-09-09 19:01:34.063483+00
efeabf9f-cc3f-41e4-b654-2870db605114	pharmacy_controlled_discrepancy	Pharmacy	Controlled drug discrepancy	Controlled-drug log shows a count variance or incomplete documentation	Trigger compliance audit	critical	{"condition": {"args": {"hours": 24}, "filter": [{"any": [{"op": "truthy", "field": "variance_detected"}, {"op": "falsy", "field": "documentation_complete"}]}], "labels": {"hours": 24}, "source": "pharmacy_controlled_logs", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} controlled-drug discrepancy/documentation issue(s) in {hours}h (alert at {threshold:.0f}+)"}}	["pharmacy_order"]	600	1800	t	2026-09-09 19:01:34.023023+00	\N	\N	0	2026-09-09 19:01:34.023023+00	2026-09-09 19:01:34.066699+00
9ebde39b-756a-46af-b26b-e7381d4a173b	patient_admission_waiting	Patient Flow	Admission waiting >30 min	Admitted patients awaiting bed assignment longer than 30 minutes	Optimize bed assignment	warning	{"condition": {"filter": [{"op": "is_null", "field": "bed_id"}, {"op": "age_gt_minutes", "field": "admitted_at", "value": 30}], "labels": {"minutes": 30}, "source": "admissions_with_wards", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} admission(s) awaiting bed assignment over {minutes:g} min (alert at {threshold:.0f}+)"}}	["admission", "bed"]	300	1800	t	2026-09-09 19:01:34.024743+00	\N	\N	0	2026-09-09 19:01:34.024743+00	2026-09-09 19:01:34.068183+00
42842002-66c0-41cb-b38b-a23c065f35d1	patient_diagnostic_delay_discharge	Patient Flow	Diagnostic delay affecting discharge	Discharge blocked by pending diagnostics/investigations	Escalate pending investigations	warning	{"condition": {"filter": [{"op": "falsy", "field": "discharge_ready"}, {"op": "contains_any", "field": "discharge_blocked_reason", "value": ["pending_tasks", "lab", "diagnostic", "investigation", "imaging", "result", "test"]}], "source": "admissions_with_wards", "operator": ">=", "aggregate": "count", "threshold": 1, "detail_template": "{value} discharge(s) delayed by pending investigations (alert at {threshold:.0f}+)"}}	["admission", "lab_result", "lab_order"]	600	1800	t	2026-09-09 19:01:34.024743+00	\N	\N	0	2026-09-09 19:01:34.024743+00	2026-09-09 19:01:34.070765+00
a73e86f2-5faa-4695-9399-6ce38f9c31b4	staffing_high_absenteeism	Staffing	High absenteeism	Share of staff off duty exceeds the absenteeism threshold	Activate absence-cover roster and confirm shift backfills	warning	{"condition": {"filter": [{"op": "not_in", "field": "on_duty_status", "value": ["on_duty", "on-duty", "present", "available", "working", "active", "duty"]}], "source": "staff", "operator": ">", "aggregate": "pct", "threshold": 15, "detail_template": "Absenteeism {value:.0f}% ({count}/{total} staff off duty), threshold {threshold:.0f}%", "require_source_nonempty": true}}	["staff"]	600	3600	t	2026-09-09 19:01:34.019918+00	\N	\N	0	2026-09-09 19:01:34.019918+00	2026-09-09 19:01:34.077238+00
434a9370-1352-40c0-b760-4b75db28f79b	isolation_beds_full	Bed Management	Isolation capacity exhausted	Isolation beds full	Identify suitable isolation candidates and trigger escalation	critical	{"condition": {"params": {"min_available_isolation_beds": 1}, "handler": "isolation_beds_full"}}	["bed"]	600	7200	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
ee7b4023-7617-42d1-a7dd-800c74ec37d4	discharged_bed_blocked	Bed Management	Discharged patient still in bed	Discharged patient still occupying bed	Notify ward, billing, pharmacy, and housekeeping teams	warning	{"condition": {"params": {"min_blocked_beds": 1}, "handler": "discharged_bed_blocked"}}	["bed", "admission", "discharge_ready"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
56c96ad9-95e8-4975-ac4e-05be625e18ef	bed_turnaround_sla	Bed Management	Bed turnaround SLA breach	Bed turnaround time exceeds SLA	Escalate housekeeping and monitor completion	warning	{"condition": {"params": {"sla_minutes": 90}, "handler": "bed_turnaround_sla"}}	[]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
a8782b30-0f41-40a4-8109-312cf90b75a8	ot_first_case_delayed	OT	First surgery delayed	First surgery delayed	Notify OT coordinator and adjust downstream schedule	warning	{"condition": {"params": {"delay_minutes": 15}, "handler": "ot_first_case_delayed"}}	["ot_surgery", "ot_schedule"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
009fae88-a346-4078-81b2-5730e275c423	ot_surgery_overrun	OT	Surgery overrun	Surgery overrun >30 min	Recalculate OT schedule and notify affected teams	warning	{"condition": {"params": {"overrun_minutes": 30}, "handler": "ot_surgery_overrun"}}	["ot_surgery"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
5dc71230-d38d-4447-953c-a30607e258ba	ot_room_idle	OT	Theatre idle with pending cases	OT idle >1 hour	Suggest advancing next surgery	info	{"condition": {"params": {"idle_minutes": 60}, "handler": "ot_room_idle"}}	["ot_room_status"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
976fefaa-ad7b-4418-9894-c72296fe0e64	ot_emergency_waiting	OT	Emergency surgery waiting	Emergency surgery waiting	Reprioritize OT schedule automatically	critical	{"condition": {"params": {"min_waiting": 1, "emergency_priorities": ["Emergency", "Urgent"]}, "handler": "ot_emergency_waiting"}}	["ot_surgery", "ot_schedule"]	300	1800	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
4065ff92-5a1a-4870-8d18-d89a990441ec	ot_icu_capacity_post_surgery	OT	ICU capacity short for surgery	ICU bed unavailable after surgery	Delay elective case or reserve ICU capacity	critical	{"condition": {"params": {"lookahead_hours": 4, "icu_surgery_types": ["Cardiac", "Neuro", "Transplant"], "min_free_icu_beds": 1}, "handler": "ot_icu_capacity_post_surgery"}}	["ot_surgery", "bed"]	600	7200	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
60f0a76f-e757-4605-bbef-902f5e38e571	ot_equipment_unavailable	OT	Theatre equipment unavailable	Equipment unavailable	Notify biomedical team and suggest alternate OT	warning	{"condition": {"params": {"min_affected": 1}, "handler": "ot_equipment_unavailable"}}	["ot_room_status", "ot_room"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
dbd5e008-3179-49d2-9e00-0c6fcb2bc3dc	discharge_fit_pending	Discharge	Medically fit, discharge pending	Patient medically fit but pending discharge	Launch discharge completion workflow	warning	{"condition": {"params": {"min_pending": 1, "grace_minutes": 60}, "handler": "discharge_fit_pending"}}	["admission", "discharge_ready"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
0c365aad-d16b-4006-b231-e82707c581d7	discharge_billing_pending	Discharge	Billing blocking discharge	Billing pending	Trigger Billing Agent for immediate processing	warning	{"condition": {"params": {"min_pending": 1}, "handler": "discharge_billing_pending"}}	["admission", "discharge_ready"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
04004a2f-eace-4a62-b237-c7b65d7eed4a	discharge_pharmacy_pending	Discharge	Discharge medication not ready	Pharmacy pending	Prioritize discharge medication preparation	warning	{"condition": {"params": {"min_pending": 1, "pending_statuses": ["pending", "on_hold"]}, "handler": "discharge_pharmacy_pending"}}	["admission", "discharge_ready", "pharmacy_order"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
ae2b4731-17ff-4136-bdd5-db505a148768	discharge_summary_pending	Discharge	Discharge summary missing	Discharge summary pending	Notify treating physician automatically	warning	{"condition": {"params": {"min_pending": 1}, "handler": "discharge_summary_pending"}}	["admission", "discharge_ready", "discharge_summary"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
b8cd6849-c2fe-4267-99bb-2f2d5be2152c	discharge_insurance_pending	Discharge	Insurance approval stuck	Insurance approval pending	Escalate to insurance desk	info	{"condition": {"params": {"min_pending": 1, "pending_hours": 4}, "handler": "discharge_insurance_pending"}}	["admission", "discharge_ready"]	900	7200	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
d07e86d3-d531-4387-8a6e-30c938a46947	discharge_delayed	Discharge	Discharge delayed	Delayed discharge >2 hours	Notify operations manager and department head	warning	{"condition": {"params": {"delay_hours": 2, "min_pending": 1}, "handler": "discharge_delayed"}}	["admission", "discharge_ready"]	600	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
2703c885-a816-46f2-87ed-7e6a3fec0666	lab_tat_sla	Laboratory	Lab turnaround SLA breach	Lab TAT exceeds SLA	Prioritize pending samples	warning	{"condition": {"params": {"sla_minutes": 120, "stat_priorities": ["stat", "urgent", "asap"], "stat_sla_minutes": 60}, "handler": "lab_tat_sla"}}	["lab_order", "lab_result"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
8678aeba-74fb-4a79-91b3-9ad0a68e7936	lab_critical_result	Laboratory	Critical result uncommunicated	Critical result pending communication	Notify treating physician immediately	critical	{"condition": {"params": {"min_pending": 1, "max_age_hours": 24, "critical_flags": ["critical", "critical high", "critical low", "panic"], "pending_minutes": 15}, "handler": "lab_critical_result"}}	["lab_result"]	120	900	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
f6300d4e-b128-415e-bd1e-13bcc3c60a31	lab_collection_delayed	Laboratory	Sample collection delayed	Sample collection delayed	Notify nursing staff	warning	{"condition": {"params": {"min_pending": 1, "delay_minutes": 60}, "handler": "lab_collection_delayed"}}	["lab_order", "lab_sample"]	300	3600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
06fdc5ba-7d1c-49e7-8425-53095a077e5a	lab_sample_rejections	Laboratory	Sample rejections rising	Sample rejection increasing	Alert lab supervisor	warning	{"condition": {"params": {"window_hours": 24, "max_rejections": 3, "rejected_statuses": ["Rejected", "Missing"]}, "handler": "lab_sample_rejections"}}	["lab_sample"]	600	7200	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
3eb57837-2fe0-486e-9071-f26c913b0ab9	rc_claims_pending	Revenue Cycle	Claims pending high	Claims pending > threshold	Prioritize claim submission	warning	{"condition": {"params": {"max_pending": 10, "pending_statuses": ["Submitted", "Query"]}, "handler": "rc_claims_pending"}}	[]	1800	14400	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
59abf7bb-9577-498b-88a1-a4ac26126124	rc_claim_denial_spike	Revenue Cycle	Claim denial spike	Claim rejection spike	Launch denial management workflow	warning	{"condition": {"params": {"max_denials": 3, "window_days": 7}, "handler": "rc_claim_denial_spike"}}	[]	1800	14400	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
5d60c7ec-7d62-4685-8e33-3c8817e46667	rc_collections_overdue	Revenue Cycle	Collections below target	Collections below target	Notify finance team with recovery list	warning	{"condition": {"params": {"max_overdue_amount": 100000, "overdue_grace_days": 7}, "handler": "rc_collections_overdue"}}	[]	3600	28800	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
af909c2c-b2f3-4eb8-bec1-2a196961d788	rc_revenue_leakage	Revenue Cycle	Revenue leakage detected	Revenue leakage detected	Trigger billing audit	warning	{"condition": {"params": {"window_days": 30, "settled_statuses": ["Paid", "Approved"], "min_leakage_amount": 50000}, "handler": "rc_revenue_leakage"}}	[]	3600	28800	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
cc1361c2-b8f3-4876-8b84-970b0e1070a0	exec_stress_index	Executive	Hospital stress index high	Hospital Stress Index high	Launch hospital-wide optimization workflow	critical	{"condition": {"params": {"weights": {"lab_tat": 0.10, "ot_backlog": 0.15, "er_boarding": 0.25, "bed_occupancy": 0.35, "discharge_delays": 0.15}, "component_norms": {"lab_tat": 5, "ot_backlog": 2, "er_boarding": 5, "bed_occupancy": 90, "discharge_delays": 5}, "stress_index_threshold": 70}, "handler": "exec_stress_index"}}	[]	1800	21600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
b6fc7a2d-5bea-4ded-b443-f70a702421da	exec_sla_breaches	Executive	Multiple SLA breaches	Multiple SLA breaches	Escalate to command center dashboard	warning	{"condition": {"params": {"min_breaches": 3, "window_hours": 4, "sla_rule_keys": ["bed_turnaround_sla", "lab_tat_sla", "lab_collection_delayed", "ot_first_case_delayed", "discharge_delayed"]}, "handler": "exec_sla_breaches"}}	[]	900	14400	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
6e4b5191-ad7a-4406-9e67-ee5415241874	exec_capacity_forecast	Executive	Capacity forecast critical	Capacity forecast critical	Recommend surge capacity plan	critical	{"condition": {"params": {"horizon_hours": 24, "min_ward_beds": 5, "min_wards_critical": 2, "predicted_occupancy_pct": 90}, "handler": "exec_capacity_forecast"}}	[]	3600	21600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
2b87bfe2-0355-496f-b8a9-e40e4e24fdea	exec_kpi_deteriorating	Executive	Operational KPI deteriorating	Operational KPI deteriorating	Generate executive action plan	warning	{"condition": {"params": {"window_hours": 24, "baseline_days": 7, "min_baseline_fires": 5, "min_pct_deterioration": 25}, "handler": "exec_kpi_deteriorating"}}	[]	3600	86400	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
912a958c-392b-4bca-b110-9eb3e02b672b	exec_utilization_imbalance	Executive	Resource utilization imbalance	Resource utilization imbalance	Rebalance beds, staff, and operational resources automatically	warning	{"condition": {"params": {"min_wards": 2, "min_ward_beds": 5, "max_occupancy_spread_pct": 30}, "handler": "exec_utilization_imbalance"}}	[]	3600	21600	t	2026-09-09 19:01:33.999463+00	\N	\N	0	2026-09-09 19:01:33.999463+00	2026-09-09 19:01:34.078686+00
32cea1f9-8fe1-4d8c-b29f-b51497f07762	staffing_nurse_ratio_below_threshold	Staffing	Nurse ratio below threshold	A nursing area exceeds the patients-per-nurse threshold	Reallocate nurses to the affected area or call in float-pool nurses	warning	{"condition": {"params": {"max_patients_per_nurse": 6}, "handler": "staffing_nurse_ratio_below_threshold"}}	["staff_roster"]	600	3600	t	2026-09-09 19:01:34.019918+00	\N	\N	0	2026-09-09 19:01:34.019918+00	2026-09-09 19:01:34.078686+00
df5cf915-e8ce-4099-b2ae-13213c74544d	staffing_overtime_above_limit	Staffing	Overtime above limit	Staff recorded overtime hours above the per-staff limit	Rotate rest, backfill shifts and review overtime spend	info	{"condition": {"params": {"min_staff_over": 1, "overtime_hours_limit": 12}, "handler": "staffing_overtime_above_limit"}}	["staff"]	900	3600	t	2026-09-09 19:01:34.019918+00	\N	\N	0	2026-09-09 19:01:34.019918+00	2026-09-09 19:01:34.078686+00
2bcc835a-303e-49af-9071-9e18cb70e2e8	staffing_icu_shortage	Staffing	ICU staffing shortage	ICU nurse-to-patient load exceeds policy	Assign additional ICU-certified nurses or trigger critical-care cover	critical	{"condition": {"params": {"roster_area": "icu", "max_patients_per_nurse": 2}, "handler": "staffing_icu_shortage"}}	["staff_roster", "admission"]	600	1800	t	2026-09-09 19:01:34.019918+00	\N	\N	0	2026-09-09 19:01:34.019918+00	2026-09-09 19:01:34.078686+00
f3f885fc-6485-4c2c-a6b8-f3cbe555b07a	ambulance_demand_surge_predicted	Ambulance	Demand surge predicted	ML forecast predicts an emergency-demand surge	Position ambulances strategically	info	{"condition": {"params": {}, "handler": "ambulance_demand_surge_predicted"}}	["ambulance"]	900	3600	t	2026-09-09 19:01:34.021435+00	\N	\N	0	2026-09-09 19:01:34.021435+00	2026-09-09 19:01:34.078686+00
\.


--
-- Data for Name: agent_registry; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.agent_registry (id, label, description, emoji, color, is_active, sort_order) FROM stdin;
bed_agent	Bed Management	owns finding/reserving a specific bed for a specific patient NOW; when ICU is full it also recovers dirty ICU beds (emergency cleaning -> mark ready)	\N	#3b82f6	t	0
icu_agent	ICU Operations	owns ICU census, capacity, step-down (ICU->ward transfer; INTERNAL, patient stays in hospital), critical-patient escalation, escalation deferral	\N	#8b5cf6	t	1
er_agent	ER Coordination	owns EMERGENCY DEPARTMENT flow for patients ARRIVING at the ED from outside the hospital: triage/CTAS scoring, acuity response, fast-track, admission selection, and ER boarding (patients admitted FROM the ED still awaiting an inpatient bed). Scope is NEW ED arrivals only. Do NOT use for in-hospital events involving patients who never came through the ED: an already-admitted inpatient's fall or deterioration on a ward is a clinical-escalation event, not ER triage; and elective/scheduled or ward patients waiting for an inpatient bed belong to bed_agent -- ER triage/CTAS/boarding logic does not apply to them.	\N	#ef4444	t	2
staff_agent	Staffing	owns nurse-to-patient ratios, shift coverage, float-pool deployment	\N	#f59e0b	t	3
discharge_agent	Discharge Planning	owns getting patients OUT of the hospital entirely (home/SNF). NEVER use for ICU step-down -- step-down is icu_agent's. discharge_agent only applies when patients are leaving the hospital, not moving between units.	\N	#10b981	t	4
pharmacy_agent	Pharmacy	owns drug stock, dispensing queue, STAT orders, interactions, substitutions	\N	#06b6d4	t	5
lab_agent	Lab Operations	owns lab order tracking, sample management, TAT, critical-result escalation, QC	\N	#06b6d4	t	6
ot_agent	OT Scheduling	owns LIVE operating-theatre scheduling: today's/upcoming surgical list, theatre capacity & turnaround, emergency case insertion, and post-op bed planning -- always read from the live/forward OT schedule. MAY run alongside financial agents when live surgical scheduling is genuinely part of the goal (e.g. an overrunning list plus its cost impact, or confirming pre-auth before booking tomorrow's cases). The one thing it does NOT do is a RETROSPECTIVE look-back: a 'what happened' audit of PAST surgical cases or denied claims (TPA / pre-auth / denial audit over closed encounters) reads historical records owned by revenue_agent or billing_agent -- do not add ot_agent for a look-back audit, because its live schedule holds none of that history.	\N	#7c3aed	t	7
revenue_agent	Revenue	PREDICT & PREVENT revenue loss: hospital-wide billing-gap & leakage review, package/department profitability, resource utilization, AND insurance denial-risk PREDICTION & PREVENTION (pre-submission validation, payer rules, missing docs). Include when the goal is explicitly financial/analytical (billing review, leakage/profitability analysis, denial-risk review, financial health, daily/shift briefing, performance review). Do NOT add to acute clinical goals (triage, ICU, bed placement, staffing, pharmacy) -- it returns empty noise. Does NOT create bills or look up a single patient's invoices -- that is billing_agent.	\N	#f97316	t	8
billing_agent	Billing	EXECUTE billing operations: structural claim validation (discrepancies, eligibility, compliance), collections / payment recovery, single-patient invoice & claim LOOKUP, and BILL GENERATION. Include for explicit claims-quality / compliance / collection goals, OR to CREATE/RAISE/GENERATE a bill, OR to look up one named patient's invoices/claims. task_type "initiate_billing" to create a bill for a resolved patient (lead with patient_verification_agent); "patient_billing" for a read-only invoice/claim lookup of one named patient; omit task_type for hospital-wide claims/collections review.	\N	#0ea5e9	t	9
ambulance_agent	Ambulance Dispatch	owns ambulance dispatch / pre-arrival coordination (patient NOT in the building yet)	\N	#ef4444	t	10
patient_verification_agent	Patient Verification	owns establishing patient IDENTITY (mobile -> patient_token + vitals). An INPUT PREREQUISITE that runs FIRST whenever the goal acts on ONE specific patient -- incoming (ER arrival, ICU admit, bed reservation) OR a specifically-named ADMITTED patient (discharge / billing-audit THE one named patient). NOT the goal owner. Omit for ward-wide/batch goals (discharge sweep, capacity, hospital-wide billing).	\N	#14b8a6	t	11
\.


--
-- Data for Name: organizations; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.organizations (id, name, slug, status, db_name, hasura_source, root_prefix, created_by, created_at) FROM stdin;
cc72cc05-a57b-4dd9-86ee-1b8f88c3d31c	Carer Demo Hospital	carer-demo	active	\N	default		11fd2037-f7a3-4778-93c9-000a5e95c257	2026-09-09 19:29:33.597107+00
\.


--
-- Data for Name: rag_conversation; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.rag_conversation (id, user_id, title, running_summary, summary_through_seq, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: rag_memory; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.rag_memory (id, user_id, kind, content, salience, embedding, embedding_model, embedding_dim, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: rag_message; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.rag_message (id, conversation_id, seq, role, content, sql, mode, row_count, created_at) FROM stdin;
\.


--
-- Data for Name: scheduled_queries; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.scheduled_queries (id, name, goal, constraints, schedule_kind, interval_seconds, cron_expr, timezone, enabled, autonomous, next_run_at, last_run_at, last_session_id, run_count, user_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: subagent_registry; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.subagent_registry (id, agent_id, label, description, capabilities, is_prefetch_eligible, is_active, sort_order) FROM stdin;
sa_bed_availability	bed_agent	Bed Availability	Identifies all available beds that are clean, unblocked, and ready for a patient	[]	f	t	0
sa_dirty_bed_recovery	bed_agent	Dirty Bed Recovery	Dispatches emergency housekeeping for dirty beds detected by availability check	[]	f	t	1
sa_bed_ranking	bed_agent	Bed Assignment	Uses clinical AI to recommend the best available bed based on the patient's needs	[]	f	t	2
sa_bed_reservation	bed_agent	Bed Reservation	Reserves the selected bed and notifies the receiving ward after clinical approval	[]	f	t	3
sa_escalation	bed_agent	Escalation	Escalates when no compliant bed can be found after a full search	[]	f	t	4
sa_bed_pred_census	bed_agent	Capacity Census	Counts beds, ICU occupancy, discharge horizon, and ER pressure	[]	f	t	5
sa_icu_census	icu_agent	ICU Census	Reviews current ICU occupancy, active admissions, and available beds (data only; step-down flagging belongs to the Step-Down Coordinator)	[]	f	t	0
sa_icu_transfer	icu_agent	ICU Admissions	Handles incoming ICU admissions: ranks pending admission requests by acuity, reserves a bed for the most critical patient, and triggers overflow evaluation when ICU is full. Transfers OUT of ICU (step-down) are handled by the Step-Down Coordinator.	[]	f	t	1
sa_icu_stepdown	icu_agent	Step-Down Coordinator	Confirms clinical criteria for STEP-DOWN -- an INTERNAL transfer of an ICU patient who is STAYING in the hospital to a lower-acuity bed (ward / HDU / progressive care) -- and arranges that transfer. Include ONLY when the task is an internal ICU-to-ward step-down. Do NOT use for a FULL HOSPITAL DISCHARGE (patient leaving the hospital -- that is discharge_agent), nor for a documentation / notes / records review (which is not a transfer at all).	[]	f	t	2
sa_er_triage	er_agent	Triage Monitor	Pulls the active ER queue and scores/persists CTAS triage for every patient; the always-run spine that emits the criticality counts every other ER sub-agent branches on	[]	f	t	0
sa_er_acuity_response	er_agent	Acuity Response	Reactive emergency handling for triaged patients — code-blue, SpO2 stabilization, sepsis/stroke/trauma protocols, specialist paging; runs ONLY when triage flags criticality	[]	f	t	1
sa_er_disposition	er_agent	Disposition Coordinator	Routes triaged patients to their next setting — fast-track/OPD for low acuity, admission selection with bed-type tagging for high acuity	[]	f	t	2
sa_er_boarding	er_agent	Boarding Monitor	Checks ER BOARDERS -- patients ALREADY ADMITTED who are physically still in the ED waiting for an inpatient bed -- and escalates bed-wait SLA breaches. Include ONLY when the concern is admitted patients boarding in the ED (bed-block / boarding SLA). Do NOT include for the not-yet-triaged / unattended active ER queue, general ER wait times, or ER understaffing -- that active-queue crisis belongs to the Triage Monitor, not boarding. Boarding tracks a different population (admitted, awaiting a bed) than the arrival/triage queue.	[]	f	t	3
sa_ratio_monitor	staff_agent	Ratio Monitor	Reviews nurse-to-patient ratios across all wards and flags understaffed areas	[]	f	t	0
sa_float_pool	staff_agent	Float Pool Dispatcher	Covers staffing shortfalls by identifying available float nurses and deploying them to understaffed wards	[]	f	t	1
sa_ambulance_census	ambulance_agent	Fleet Census	Fetches the full ambulance fleet from the database and caches it in Redis for fast dispatch lookup	[]	f	t	0
sa_ambulance_dispatch	ambulance_agent	Dispatch Coordinator	Assigns the best available unit by type and fuel level, surfaces ETA and crew from the DB record, and flags escalation for critical emergency types	[]	f	t	1
sa_discharge_ready	discharge_agent	Readiness Assessor	Reviews each admitted patient to determine if they are clinically ready for discharge — ONLY for active admissions and forward-looking readiness goals; exclude for retrospective, audit, or post-discharge review	[]	f	t	0
sa_discharge_retrospective	discharge_agent	Retrospective Discharge Reviewer	Reviews completed/closed discharge encounters for documentation and audit goals — ONLY for retrospective, historical, or post-discharge review; NOT for active admissions	[]	f	t	1
sa_discharge_barriers	discharge_agent	Discharge Approver	Awaits human approval then commits discharge-ready status and frees the bed	[]	f	t	2
sa_stock_monitor	pharmacy_agent	Stock Monitor	Reviews current medication stock levels and flags drugs running low	[]	f	t	0
sa_medication_prioritization	pharmacy_agent	Medication Prioritization Agent	Prioritizes STAT and critical patient medication orders; escalates unavailability	[]	f	t	1
sa_medication_fulfillment	pharmacy_agent	Medication Fulfillment Agent	Tracks prescription receipt, availability check, and dispensing lifecycle	[]	f	t	2
sa_drug_availability	pharmacy_agent	Drug Availability Agent	Monitors stock levels, searches alternate locations, reserves inventory	[]	f	t	3
sa_prescription_validation	pharmacy_agent	Prescription Validation Agent	Validates completeness, dosage safety, and duplicate detection before dispensing	[]	f	t	4
sa_clinical_interaction	pharmacy_agent	Clinical Interaction Agent	Runs drug-drug interaction and allergy conflict checks	[]	f	t	5
sa_dispensing_validation	pharmacy_agent	Dispensing Validation Agent	Right patient / right drug / right dose validation before medication release	[]	f	t	6
sa_medication_substitution	pharmacy_agent	Medication Substitution Agent	Recommends formulary alternatives and manages physician approval workflow	[]	f	t	7
sa_pharmacy_queue	pharmacy_agent	Pharmacy Queue Optimization Agent	Monitors dispensing queue, identifies bottlenecks, prioritizes STAT workload	[]	f	t	8
sa_controlled_drug_compliance	pharmacy_agent	Controlled Drug Compliance Agent	Audits controlled substance dispensing for authorization and inventory accuracy	[]	f	t	9
sa_sample_prioritization	lab_agent	Sample Prioritization Agent	Prioritizes STAT/ICU/ER samples and escalates TAT-risk cases	[]	f	t	0
sa_sample_tracking	lab_agent	Sample Tracking Agent	Tracks collection, transport, and lab receipt status; triggers search for missing samples	[]	f	t	1
sa_tat_optimization	lab_agent	TAT Optimization Agent	Monitors turnaround time, identifies bottlenecks, escalates SLA breaches	[]	f	t	2
sa_analyzer_utilization	lab_agent	Analyzer Utilization Agent	Monitors analyzer load, triggers rebalancing and maintenance alerts	[]	f	t	3
sa_analyzer_routing	lab_agent	Analyzer Routing Agent	Routes samples to alternate analyzers when primary is overloaded	[]	f	t	4
sa_quality_control	lab_agent	Quality Control Agent	Validates QC pass/fail per shift, triggers recalibration, raises compliance alerts	[]	f	t	5
sa_test_validation	lab_agent	Test Validation Agent	Auto-validates results against rules, delta checks, critical value flags	[]	f	t	6
sa_critical_result_escalation	lab_agent	Critical Result Escalation Agent	Detects critical lab values and escalates to physician / ICU-ER team	[]	f	t	7
sa_test_recommendation	lab_agent	Test Recommendation Agent	Detects abnormal results, applies reflex rules, recommends add-on tests	[]	f	t	8
sa_ot_census	ot_agent	OT Census	Reviews today's surgical list, theatre status, equipment, and available post-operative (ICU/HDU) beds	[]	f	t	0
sa_ot_turnaround	ot_agent	OT Turnaround Agent	Reduces OT idle time — coordinates theatre cleaning, validates instrument readiness, predicts delays, and dispatches preparation tasks	[]	f	t	1
sa_ot_scheduling	ot_agent	OT Scheduling Agent	Owns the surgical plan AND surgical (re)scheduling: detects room/surgeon conflicts, checks resources, balances theatre load, and -- when a surgery is cancelled or must be moved -- finds an open theatre slot and stages an executable reschedule. This is the owner of moving/rescheduling a theatre case (never the OPD appointment agent).	[]	f	t	2
sa_ot_emergency	ot_agent	OT Emergency Response	Acuity-reactive -- detects non-elective/emergency surgical cases and plans immediate theatre assignment for them. The handling step runs only when emergency cases are present.	[]	f	t	3
sa_ot_analysis	ot_agent	OT Analysis	Terminal synthesis — scores OT efficiency, produces per-case proceed/delay/escalate recommendations, AND (executable) defers the delay-flagged electives to later slots to free capacity	[]	f	t	4
sa_rev_optimization	revenue_agent	Revenue Optimization	Identifies revenue leakage and optimizes utilization across hospital resources	[]	f	t	0
sa_rev_denial_prevention	revenue_agent	Denial Prevention	Pre-submission claims safeguards: predicts insurance denial risk and validates claims against payer rules and require documentation before a claim is submitted to the payer. Belongs to admission / pre-authorization / claim-submission flows where claims are being prepared. Not a billing lookup or completeness check — to retrieve or verify an existing patient's billing record (e.g. at discharge), use Patient Billing Lookup.	[]	f	t	1
sa_claim_validation	billing_agent	Claim Validation	Detects duplicate claims, missing invoice linkages, and amount mismatches	[]	f	t	0
sa_billing_optimization	billing_agent	Billing Optimization	Tracks overdue invoices, detects revenue leakage, and generates billing recommendations	[]	f	t	1
sa_rev_patient_billing	billing_agent	Patient Billing Lookup	Fetches all invoices and claims for a specific patient	[]	f	t	2
sa_rev_initiate_billing	billing_agent	Initiate Billing	Creates a bill-generation request for the resolved patient(s); the DB side turns it into an actual bill when the session is committed	[]	f	t	3
sa_patient_identification	patient_verification_agent	Patient Identification	Resolves incoming patient(s) by mobile -> token + vitals; flags unknown/provisional patients	[]	f	t	0
sa_patient_registration	patient_verification_agent	Patient Registration	Registers an incoming patient that has no DB record yet -- sends a registration request to Fabric (forwarded to the DB side, created manually by hospital staff) and pauses the flow until the new record is reported back, then rebinds the patient. Runs only when identification finds an unknown patient.	[]	f	t	1
\.


--
-- Data for Name: task_registry; Type: TABLE DATA; Schema: hospilot_app; Owner: -
--

COPY hospilot_app.task_registry (id, subagent_id, label, description, outputs, function_code, is_dynamic, is_active, sort_order) FROM stdin;
ta_query_beds	sa_bed_availability	Query all available beds — always include; returns counts by type (icu_count, hdu_count, general_count, ventilator_count, isolation_count)	\N	["candidate_count", "icu_count", "hdu_count", "general_count", "ventilator_count", "isolation_count", "candidates"]	\N	f	t	0
ta_check_dirty_icu_beds	sa_bed_availability	Fallback when ICU has no clean beds — ONLY when patient requires an ICU bed; condition: ta_query_beds.icu_count == 0	\N	["dirty_count", "dirty_beds"]	\N	f	t	1
ta_check_dirty_soon_to_release	sa_bed_availability	Fallback when no beds found at all — condition: ta_query_beds.candidate_count == 0	\N	["beds"]	\N	f	t	2
ta_check_overflow_candidates	sa_bed_availability	Fallback when no beds found at all — condition: ta_query_beds.candidate_count == 0	\N	["candidates"]	\N	f	t	3
ta_check_temporary_overflow_beds	sa_bed_availability	Emergency fallback when no beds found at all — condition: ta_query_beds.candidate_count == 0	\N	["candidates"]	\N	f	t	4
ta_clean_vacated_beds	sa_dirty_bed_recovery	Dispatch standard housekeeping for recently discharged beds — always include for bed_cleaning task type	\N	["dispatched"]	\N	f	t	0
ta_create_emergency_cleaning_task	sa_dirty_bed_recovery	Create priority cleaning job for urgently needed bed — condition: ta_check_dirty_icu_beds.dirty_count > 0	\N	["bed_ids", "created"]	\N	f	t	1
ta_dispatch_housekeeping_fast_track	sa_dirty_bed_recovery	Dispatch fast-track housekeeping with response target < 10 minutes — condition: ta_check_dirty_icu_beds.dirty_count > 0	\N	["dispatched", "within_sla"]	\N	f	t	2
ta_escalate_to_floor_supervisor	sa_dirty_bed_recovery	Escalate to floor supervisor when housekeeping cannot respond in time — condition: ta_dispatch_housekeeping_fast_track.within_sla == 0	\N	["escalated"]	\N	f	t	3
ta_validate_sanitization	sa_dirty_bed_recovery	Validate sanitization completed after housekeeping dispatch — condition: ta_dispatch_housekeeping_fast_track.within_sla > 0	\N	["passed"]	\N	f	t	4
ta_mark_bed_ready	sa_dirty_bed_recovery	Mark bed clean and available after sanitization passes — condition: ta_validate_sanitization.passed > 0	\N	["bed_id"]	\N	f	t	5
ta_check_room_readiness	sa_dirty_bed_recovery	Check overall room cleanliness and readiness status	\N	["ready", "issues"]	\N	f	t	6
ta_validate_oxygen_readiness	sa_dirty_bed_recovery	Validate O2 pipeline is functional for a bed	\N	["functional"]	\N	f	t	7
ta_check_monitor_readiness	sa_dirty_bed_recovery	Check that bedside monitor is connected and functional	\N	["functional"]	\N	f	t	8
ta_notify_biomedical_team	sa_dirty_bed_recovery	Alert biomedical engineering about an equipment fault	\N	["notified"]	\N	f	t	9
ta_sync_ready_status	sa_dirty_bed_recovery	Sync bed-ready status to the Bed Assignment Agent	\N	["synced"]	\N	f	t	10
ta_create_equipment_task	sa_dirty_bed_recovery	Create an equipment setup or repair task	\N	["task_id"]	\N	f	t	11
ta_rank_beds	sa_bed_ranking	Rank candidate beds for this patient — always include when reserving	\N	["ranked_beds", "recommendation"]	\N	f	t	0
ta_filter_ventilator_beds	sa_bed_ranking	ONLY when patient requires mechanical ventilation — condition: ta_query_beds.ventilator_count > 0	\N	["candidates"]	\N	f	t	1
ta_filter_isolation_beds	sa_bed_ranking	ONLY when patient requires infection isolation — condition: ta_query_beds.isolation_count > 0	\N	["candidates"]	\N	f	t	2
ta_apply_gender_filter	sa_bed_ranking	ONLY when gender-bay policy explicitly applies to this admission — condition: ta_query_beds.candidate_count > 0	\N	["candidates"]	\N	f	t	3
ta_apply_isolation_room_filter	sa_bed_ranking	ONLY when patient requires negative-pressure isolation (TB, airborne precautions) — condition: ta_query_beds.isolation_count > 0	\N	["candidates"]	\N	f	t	4
ta_trigger_alternate_ward_search	sa_bed_ranking	ONLY when primary ward candidates are exhausted after filtering — condition: ta_query_beds.candidate_count > 0	\N	["candidates"]	\N	f	t	5
ta_recommend_transfer_allocation	sa_bed_ranking	ONLY when no bed available in-hospital — condition: ta_query_beds.candidate_count == 0	\N	["recommendation"]	\N	f	t	6
ta_recommend_icu_to_ward_transfer	sa_bed_ranking	ONLY when ICU bed is needed but ICU is full — condition: ta_query_beds.icu_count == 0	\N	["recommendation"]	\N	f	t	7
ta_allocate_overflow_bed	sa_bed_ranking	ONLY when no standard bed available, last resort, AND patient is NOT ventilator-dependent or monitoring-dependent — for vent/monitoring-dependent patients external transfer is the correct last resort, not overflow bed allocation	\N	["bed_id"]	\N	f	t	8
ta_create_approval	sa_bed_reservation	Lock bed and create approval task — always include when reserving	\N	["approval_id", "bed_id"]	\N	f	t	0
ta_confirm_reservation	sa_bed_reservation	Confirm reservation post-approval — always include when reserving	\N	["bed_id", "status"]	\N	f	t	1
ta_sync_bed_status	sa_bed_reservation	Sync bed status with HIS after reservation — always include when reserving	\N	["synced"]	\N	f	t	2
ta_hold_bed_temporarily	sa_bed_reservation	Soft-hold a bed for a patient explicitly en route but not yet arrived — ONLY when goal mentions patient en route	\N	["held"]	\N	f	t	3
ta_escalate_to_command_center	sa_escalation	Broadcast a full escalation alert via WebSocket	\N	["escalated"]	\N	f	t	0
ta_escalate_allocation_conflict	sa_escalation	Escalate when no compliant bed can be found after full search	\N	["escalated"]	\N	f	t	1
ta_get_capacity_snapshot	sa_bed_pred_census	Count beds, ICU occupancy, discharge horizon, and ER pressure	\N	["total_beds", "available", "icu_occupancy_pct", "overflow_risk"]	\N	f	t	0
ta_get_icu_census	sa_icu_census	Query ICU occupancy, current admissions, and available beds from Redis	\N	["icu_available", "available_beds", "icu_admissions", "non_icu_admissions"]	\N	f	t	0
ta_rank_icu_requests	sa_icu_transfer	Rank incoming ICU admission requests by clinical acuity — always run when ICU requests are active	\N	["ranked_requests", "ventilator_dependent_count", "deterioration_risk_count"]	\N	f	t	0
ta_prioritize_ventilator_bed	sa_icu_transfer	Prioritize ventilator ICU bed for ventilator-dependent patients — condition: ta_rank_icu_requests.ventilator_dependent_count > 0	\N	["ventilator_priority_count", "ranked_requests"]	\N	f	t	1
ta_reserve_icu_admission	sa_icu_transfer	Reserve ICU admission for top-ranked patient when beds available — condition: ta_get_icu_census.icu_available > 0	\N	["approval_id", "patient_token"]	\N	f	t	2
ta_trigger_overflow_evaluation	sa_icu_transfer	Trigger overflow evaluation when ICU full — condition: ta_get_icu_census.icu_available == 0	\N	["overflow_triggered", "patients_pending"]	\N	f	t	3
ta_escalate_deterioration	sa_icu_transfer	Escalate priority for patients with high deterioration risk — condition: ta_rank_icu_requests.deterioration_risk_count > 0	\N	["escalated"]	\N	f	t	4
ta_analyze_icu_status	sa_icu_stepdown	Analyse step-down and escalation eligibility with Claude	\N	["step_down_candidates", "escalation_candidates", "summary", "critical_vital_ids", "transfer_candidate_count"]	\N	f	t	0
ta_create_icu_approval	sa_icu_stepdown	Create ICU transfer approval task in Hasura — condition: ta_analyze_icu_status.transfer_candidate_count > 0	\N	["created"]	\N	f	t	1
ta_confirm_icu_actions	sa_icu_stepdown	Execute confirmed step-down transfers	\N	["critical_vitals_flagged", "transfers_staged"]	\N	f	t	2
ta_get_er_visits	sa_er_triage	Query the active ER visit queue from Redis — always include; the data spine every downstream ER sub-agent reads from	\N	["visits"]	\N	f	t	0
ta_triage_patients	sa_er_triage	Score and triage ER patients with Claude — always include when ER visits exist; emits the criticality counts downstream tasks branch on	\N	["triaged", "ctas1", "ctas2", "critical", "spo2_critical_count", "protocol_flags_count", "specialist_needed_count", "fasttrack_count", "admission_candidate_count"]	\N	f	t	1
ta_save_triage_scores	sa_er_triage	Persist triage scores to Redis — always include after triage	\N	["saved"]	\N	f	t	2
ta_detect_cardiac_arrest	sa_er_acuity_response	Trigger code-blue workflow when cardiac arrest is suspected — condition: ta_triage_patients.ctas1 > 0	\N	["cardiac_arrest_suspected", "code_blue_triggered"]	\N	f	t	0
ta_check_spo2_critical	sa_er_acuity_response	Escalate stabilization protocol when SpO2 is critically low — condition: ta_triage_patients.spo2_critical_count > 0	\N	["spo2_critical", "escalated"]	\N	f	t	1
ta_detect_clinical_protocol	sa_er_acuity_response	Activate sepsis/stroke/trauma protocol pathway — condition: ta_triage_patients.protocol_flags_count > 0	\N	["protocol_count", "protocol_activated", "protocols"]	\N	f	t	2
ta_notify_specialist	sa_er_acuity_response	Notify relevant specialist team based on detected condition — condition: ta_triage_patients.specialist_needed_count > 0	\N	["notified", "specialists_notified"]	\N	f	t	3
ta_route_fasttrack	sa_er_disposition	Route low-acuity patients (CTAS 4-5) to fast-track / OPD diversion — condition: ta_triage_patients.fasttrack_count > 0	\N	["fasttrack_candidates"]	\N	f	t	0
ta_select_critical	sa_er_disposition	Select critical patients (CTAS 1-3) for admission and tag bed_type_needed for the Bed Agent — condition: ta_triage_patients.admission_candidate_count > 0	\N	["critical_patients"]	\N	f	t	1
ta_check_er_boarders	sa_er_boarding	Check ER boarders and escalate SLA breaches	\N	["boarders", "escalated"]	\N	f	t	0
ta_get_ward_workload	sa_ratio_monitor	Aggregate patients and incomplete/overdue task load per ward (from admissions + clinical tasks)	\N	["workload"]	\N	f	t	0
ta_get_hourly_workload	sa_ratio_monitor	Bucket ward task-load by hour of day; flag peak / understaffed hours	\N	["by_hour", "peak_hours", "understaffed_hours", "total_tasks"]	\N	f	t	1
ta_get_area_staffing	sa_ratio_monitor	Assess staffing for a specific area (front desk, OPD, phlebotomy, OT, recovery/PACU, lab, inpatient nursing); flag understaffed areas	\N	["shift", "areas_assessed", "areas", "understaffed_areas"]	\N	f	t	2
ta_check_documentation_gaps	sa_ratio_monitor	Detect staffing documentation gaps (missing / overdue care notes, charting, unsigned records) by ward — ONLY for administrative/audit/compliance goals; exclude during live emergency, real-time staffing, or float-pool dispatch	\N	["documentation_tasks_pending", "documentation_tasks_overdue", "by_ward", "flagged_wards", "has_gaps"]	\N	f	t	3
ta_analyze_staff_workload	sa_ratio_monitor	Analyse ward workload; flag high-pressure wards and recommend same-type staff moves (Claude)	\N	["recommendations", "high_pressure_wards", "summary"]	\N	f	t	4
ta_create_staff_approval	sa_float_pool	Create float pool deployment approval	\N	["created"]	\N	f	t	0
ta_confirm_staff_recommendation	sa_float_pool	Confirm and dispatch float nurses — condition: ta_create_staff_approval.created == true	\N	["status", "recommendations"]	\N	f	t	1
ta_get_available_ambulances	sa_ambulance_census	Fetch ambulance fleet data	\N	["ambulances"]	\N	f	t	0
ta_assign_ambulance	sa_ambulance_dispatch	Assign best available unit, surface ETA and crew, flag escalation	\N	["assigned_vehicle_no", "eta_mins", "escalate"]	\N	f	t	0
ta_create_ambulance_approval	sa_ambulance_dispatch	Create dispatch approval task — condition: ta_assign_ambulance.assigned_vehicle_no != null	\N	["approval_id"]	\N	f	t	1
ta_confirm_ambulance_dispatch	sa_ambulance_dispatch	Confirm ambulance dispatch — condition: ta_create_ambulance_approval.approval_id != null	\N	["confirmed"]	\N	f	t	2
ta_get_discharge_candidates	sa_discharge_ready	Fetch active admissions and discharge checklists	\N	["candidates", "count"]	\N	f	t	0
ta_batch_assess_discharges	sa_discharge_ready	Assess discharge readiness for each patient	\N	["assessed", "ready", "blocked"]	\N	f	t	1
ta_check_notes_completeness	sa_discharge_ready	Check all clinical notes are present for discharge-ready patients — condition: ta_batch_assess_discharges.ready > 0	\N	["notes_incomplete", "incomplete_admissions"]	\N	f	t	2
ta_request_missing_docs	sa_discharge_ready	Request missing documentation — condition: ta_check_notes_completeness.notes_incomplete > 0	\N	["requested"]	\N	f	t	3
ta_check_pending_results	sa_discharge_ready	Check for pending lab/imaging results before finalizing summary — condition: ta_batch_assess_discharges.ready > 0	\N	["results_pending", "admissions_with_pending"]	\N	f	t	4
ta_get_discharge_records	sa_discharge_retrospective	Fetch recently discharged / closed encounters — ONLY for retrospective, audit, or post-discharge review goals; exclude for active admission readiness assessment	\N	["records", "count"]	\N	f	t	0
ta_generate_summaries	sa_discharge_retrospective	Generate AI discharge summaries — always include when discharge-ready patients exist; marks any pending lab/imaging results in the draft rather than blocking on them	\N	["summaries_generated"]	\N	f	t	1
ta_create_discharge_approval	sa_discharge_barriers	Create discharge approval task in Hasura	\N	["approval_id"]	\N	f	t	0
ta_confirm_discharge_updates	sa_discharge_barriers	Execute confirmed discharge updates	\N	["confirmed"]	\N	f	t	1
ta_get_discharge_patients	sa_stock_monitor	Fetch discharge-ready patients for med reconciliation	\N	["patients"]	\N	f	t	0
ta_check_medication_reconciliation	sa_stock_monitor	Check medication reconciliation gaps	\N	["gaps", "stock_hours_remaining"]	\N	f	t	1
ta_save_pharmacy_report	sa_stock_monitor	Persist pharmacy report to Hasura	\N	["saved"]	\N	f	t	2
ta_check_stat_medication_orders	sa_medication_prioritization	Check for STAT medication orders	\N	["stat_count", "stat_orders"]	\N	f	t	0
ta_apply_critical_patient_priority	sa_medication_prioritization	Apply highest priority for critical and ICU/ER patients	\N	["critical_patient_count", "prioritized_count"]	\N	f	t	1
ta_check_stat_availability	sa_medication_prioritization	Check if STAT medications are in stock	\N	["stat_available_count", "stat_unavailable_count"]	\N	f	t	2
ta_escalate_stat_shortage	sa_medication_prioritization	Escalate when STAT medication is unavailable	\N	["escalated"]	\N	f	t	3
ta_check_prescription_received	sa_medication_fulfillment	Check if prescriptions have been received for pending orders	\N	["prescription_count", "pending_count"]	\N	f	t	0
ta_check_medication_availability	sa_medication_fulfillment	Verify medication is available in inventory	\N	["available_count", "unavailable_count"]	\N	f	t	1
ta_track_dispensing_progress	sa_medication_fulfillment	Track in-progress dispensing orders	\N	["dispensing_count", "delayed_count"]	\N	f	t	2
ta_close_fulfilled_orders	sa_medication_fulfillment	Mark completed medication orders as closed	\N	["closed_count"]	\N	f	t	3
ta_check_stock_levels	sa_drug_availability	Check current medication stock vs reorder levels	\N	["low_stock_count", "out_of_stock_count", "adequate_count"]	\N	f	t	0
ta_search_alternate_location	sa_drug_availability	Search satellite pharmacy and ICU cart for alternative stock	\N	["alternate_found", "alternate_location"]	\N	f	t	1
ta_reserve_inventory	sa_drug_availability	Reserve available inventory for STAT and critical orders	\N	["reserved_count"]	\N	f	t	2
ta_escalate_critical_shortage	sa_drug_availability	Escalate shortage impacting patient care to pharmacy lead	\N	["escalated", "shortage_medications"]	\N	f	t	3
ta_validate_prescription_completeness	sa_prescription_validation	Check prescriptions are complete with all required fields	\N	["complete_count", "incomplete_count"]	\N	f	t	0
ta_validate_dosage_range	sa_prescription_validation	Validate dose is within therapeutic safe range	\N	["safe_count", "unsafe_dose_count"]	\N	f	t	1
ta_detect_duplicate_medications	sa_prescription_validation	Detect duplicate medication orders for same patient	\N	["duplicate_count", "duplicates"]	\N	f	t	2
ta_approve_or_hold_prescription	sa_prescription_validation	Release prescription for dispensing or hold for review	\N	["approved_count", "held_count"]	\N	f	t	3
ta_check_polypharmacy	sa_clinical_interaction	Check patients prescribed multiple concurrent medications	\N	["polypharmacy_count", "patient_count"]	\N	f	t	0
ta_run_interaction_check	sa_clinical_interaction	Run drug-drug interaction check against known rules	\N	["major_interaction_count", "total_interactions"]	\N	f	t	1
ta_check_allergy_conflict	sa_clinical_interaction	Check for allergy conflicts in pending orders	\N	["allergy_conflict_count"]	\N	f	t	2
ta_approve_safe_dispense	sa_clinical_interaction	Approve or hold medication based on interaction findings	\N	["approved_count", "held_count"]	\N	f	t	3
ta_verify_patient_identity	sa_dispensing_validation	Verify patient identity before medication dispensing	\N	["verified_count", "unverified_count"]	\N	f	t	0
ta_match_medication_prescription	sa_dispensing_validation	Match dispensed medication to prescription	\N	["match_failed_count", "matched_count"]	\N	f	t	1
ta_validate_dispensing_dosage	sa_dispensing_validation	Validate correct dosage before medication release	\N	["dose_mismatch_count", "dose_correct_count"]	\N	f	t	2
ta_release_or_hold_dispensing	sa_dispensing_validation	Release verified medication or hold discrepancy for review	\N	["released_count", "held_count"]	\N	f	t	3
ta_check_unavailable_medications	sa_medication_substitution	Identify prescribed medications that are unavailable	\N	["unavailable_count", "unavailable_drugs"]	\N	f	t	0
ta_search_formulary_alternatives	sa_medication_substitution	Search formulary for therapeutic substitutes	\N	["substitute_available", "alternatives_found"]	\N	f	t	1
ta_request_physician_approval	sa_medication_substitution	Send substitution approval request to prescribing physician	\N	["approval_sent", "approved_count"]	\N	f	t	2
ta_update_substitution_order	sa_medication_substitution	Update order with approved substitute medication	\N	["orders_updated"]	\N	f	t	3
ta_check_queue_length	sa_pharmacy_queue	Check current dispensing queue length and STAT backlog	\N	["queue_length", "stat_waiting_count", "queue_above_threshold"]	\N	f	t	0
ta_analyze_queue_bottleneck	sa_pharmacy_queue	Identify bottleneck causing queue buildup	\N	["bottleneck_stage", "bottleneck_count"]	\N	f	t	1
ta_prioritize_stat_medications	sa_pharmacy_queue	Reprioritize queue for pending STAT medication orders	\N	["reprioritized_count"]	\N	f	t	2
ta_escalate_tat_breach	sa_pharmacy_queue	Escalate to pharmacy supervisor when TAT SLA is breached	\N	["escalated", "breach_count"]	\N	f	t	3
ta_identify_controlled_orders	sa_controlled_drug_compliance	Identify controlled substance orders requiring audit	\N	["controlled_count", "controlled_orders"]	\N	f	t	0
ta_verify_controlled_authorization	sa_controlled_drug_compliance	Verify authorization and witness documentation	\N	["authorized_count", "missing_auth_count"]	\N	f	t	1
ta_check_inventory_variance	sa_controlled_drug_compliance	Check for controlled drug inventory discrepancies	\N	["variance_detected", "variance_count"]	\N	f	t	2
ta_escalate_compliance_issue	sa_controlled_drug_compliance	Escalate to compliance officer for investigation	\N	["escalated"]	\N	f	t	3
ta_check_stat_status	sa_sample_prioritization	Check if any STAT samples are pending	\N	["stat_count", "stat_samples"]	\N	f	t	0
ta_apply_icu_er_priority	sa_sample_prioritization	Apply highest priority for ICU/ER samples	\N	["prioritized_count"]	\N	f	t	1
ta_check_analyzer_available	sa_sample_prioritization	Check if target analyzer is available	\N	["available_count"]	\N	f	t	2
ta_escalate_tat_risk	sa_sample_prioritization	Escalate to supervisor if TAT target is at risk	\N	["escalated"]	\N	f	t	3
ta_check_sample_collection	sa_sample_tracking	Check which samples are collected vs pending	\N	["collected_count", "pending_count"]	\N	f	t	0
ta_check_sample_transport	sa_sample_tracking	Check transport status for collected samples	\N	["in_transit", "delayed_count"]	\N	f	t	1
ta_verify_sample_receipt	sa_sample_tracking	Verify sample received at lab	\N	["received_count", "missing_count"]	\N	f	t	2
ta_trigger_sample_search	sa_sample_tracking	Trigger search for misplaced samples	\N	["search_triggered"]	\N	f	t	3
ta_check_tat_threshold	sa_tat_optimization	Check if current TAT exceeds SLA threshold	\N	["overdue_count", "tat_exceeded"]	\N	f	t	0
ta_analyze_tat_bottleneck	sa_tat_optimization	Identify the processing bottleneck stage	\N	["bottleneck_stage", "bottleneck_count"]	\N	f	t	1
ta_prioritize_stat_queue	sa_tat_optimization	Reprioritize queue for pending STAT samples	\N	["reprioritized_count"]	\N	f	t	2
ta_escalate_tat_supervisor	sa_tat_optimization	Escalate to Lab Supervisor when TAT is not restored	\N	["escalated"]	\N	f	t	3
ta_check_analyzer_utilization	sa_analyzer_utilization	Check if any analyzer load exceeds 90%	\N	["overloaded_count", "max_utilization"]	\N	f	t	0
ta_identify_alternate_analyzer	sa_analyzer_utilization	Identify available backup analyzer	\N	["alternate_available", "alternate_id"]	\N	f	t	1
ta_rebalance_analyzer_workload	sa_analyzer_utilization	Rebalance workload to backup analyzer	\N	["rebalanced"]	\N	f	t	2
ta_trigger_maintenance_alert	sa_analyzer_utilization	Alert maintenance team for predicted downtime	\N	["alerted"]	\N	f	t	3
ta_check_analyzer_overload	sa_analyzer_routing	Check if primary analyzer is overloaded	\N	["overloaded", "load_pct"]	\N	f	t	0
ta_validate_alternate_analyzer	sa_analyzer_routing	Validate backup analyzer is certified for the test	\N	["validated", "alternate_id"]	\N	f	t	1
ta_execute_sample_routing	sa_analyzer_routing	Route samples to alternate analyzer	\N	["routed_count"]	\N	f	t	2
ta_restore_routing_capacity	sa_analyzer_routing	Close routing workflow when capacity is normalized	\N	["restored"]	\N	f	t	3
ta_check_qc_status	sa_quality_control	Check QC pass/fail for active analyzers this shift	\N	["failed_count", "qc_failed"]	\N	f	t	0
ta_trigger_recalibration	sa_quality_control	Stop result release and trigger recalibration	\N	["recalibration_triggered"]	\N	f	t	1
ta_repeat_qc_check	sa_quality_control	Rerun QC after calibration	\N	["passed", "repeat_passed"]	\N	f	t	2
ta_compliance_alert	sa_quality_control	Generate compliance alert if accreditation is impacted	\N	["alerted"]	\N	f	t	3
ta_validate_result_rules	sa_test_validation	Check result against auto-validation rules	\N	["auto_released", "flagged_count"]	\N	f	t	0
ta_check_delta_flag	sa_test_validation	Run delta check against prior result	\N	["delta_failed_count"]	\N	f	t	1
ta_check_critical_value_flag	sa_test_validation	Check for critical value requiring escalation	\N	["critical_count"]	\N	f	t	2
ta_release_validated_report	sa_test_validation	Release auto-validated reports	\N	["released_count"]	\N	f	t	3
ta_detect_critical_results	sa_critical_result_escalation	Detect critical lab values requiring immediate action	\N	["critical_count", "critical_results"]	\N	f	t	0
ta_notify_physician_critical	sa_critical_result_escalation	Alert physician for critical result	\N	["notified_count"]	\N	f	t	1
ta_escalate_icu_er_critical	sa_critical_result_escalation	Trigger urgent escalation for ICU/ER patients	\N	["escalated_count"]	\N	f	t	2
ta_log_critical_action	sa_critical_result_escalation	Log physician acknowledgment and close workflow	\N	["logged"]	\N	f	t	3
ta_detect_abnormal_result	sa_test_recommendation	Detect abnormal results triggering reflex rules	\N	["abnormal_count", "abnormal_results"]	\N	f	t	0
ta_evaluate_reflex_rules	sa_test_recommendation	Apply reflex/add-on rules to abnormal results	\N	["recommended_count"]	\N	f	t	1
ta_recommend_additional_test	sa_test_recommendation	Send recommendation to physician	\N	["sent_count"]	\N	f	t	2
ta_create_reflex_order	sa_test_recommendation	Auto-create order per protocol if no approval needed	\N	["orders_created"]	\N	f	t	3
ta_get_ot_census	sa_ot_census	Fetch OT schedule, rooms, room status, today's equipment, and available post-op (ICU/HDU) beds from cache — always include	\N	["schedule", "rooms", "room_status", "upcoming_surgeries", "upcoming_count", "post_op_beds_available", "icu_available", "hdu_available"]	\N	f	t	0
ta_ot_check_cleaning	sa_ot_turnaround	OT cleaning coordination — check which theatres need cleaning before next case — always include	\N	["cleaning_count", "rooms_to_clean"]	\N	f	t	0
ta_ot_check_instruments	sa_ot_turnaround	Instrument readiness validation — validate equipment availability for upcoming surgeries — condition: ta_get_ot_census.upcoming_count > 0	\N	["gap_count", "ready_count", "gaps"]	\N	f	t	1
ta_ot_track_turnaround	sa_ot_turnaround	OT turnaround tracking — track theatre utilisation and active surgeries — always include	\N	["rooms_active", "active_count", "utilisation_pct"]	\N	f	t	2
ta_ot_predict_delays	sa_ot_turnaround	Delay prediction — predict on-time start risks per theatre — always include	\N	["delay_risks", "high_risk_count"]	\N	f	t	3
ta_ot_coordinate_staff	sa_ot_turnaround	Staff coordination — assign staff actions to address delay risks and gaps — condition: ta_ot_predict_delays.high_risk_count > 0	\N	["staff_actions"]	\N	f	t	4
ta_ot_detect_conflicts	sa_ot_scheduling	Conflict detection — detect room double-bookings and surgeon overlaps — always include	\N	["conflict_count", "has_conflicts", "room_conflicts", "surgeon_conflicts"]	\N	f	t	0
ta_ot_check_resources	sa_ot_scheduling	Resource-aware scheduling — assess room availability and case load per theatre — always include	\N	["available_rooms", "utilisation_pct", "under_resourced"]	\N	f	t	1
ta_ot_optimise_slots	sa_ot_scheduling	Surgery slot optimisation — recommend slot swaps to resolve conflicts — condition: ta_ot_detect_conflicts.has_conflicts == true	\N	["slot_optimizations"]	\N	f	t	2
ta_ot_balance_load	sa_ot_scheduling	OT load balancing — balance case load across available theatres — always include	\N	["load_balance", "summary"]	\N	f	t	3
ta_ot_find_theatre_slots	sa_ot_scheduling	Find open theatre slots — derive bookable OT time-windows (by room type + duration) for (re)scheduling a surgery — include when a surgery must be scheduled or rescheduled into a slot	\N	["open_slots", "open_slot_count"]	\N	f	t	4
ta_ot_reschedule_surgery	sa_ot_scheduling	Reschedule a cancelled surgery to the earliest open theatre slot; stages an executable move for commit — ONLY when a surgery is cancelled / must be moved to a new slot	\N	["rescheduled", "proposals", "status"]	\N	f	t	5
ta_ot_find_emergencies	sa_ot_emergency	Emergency detection -- identify non-elective and emergency cases in the schedule -- always include	\N	["emergency_count", "emergency_cases"]	\N	f	t	0
ta_ot_handle_emergencies	sa_ot_emergency	Emergency OT handling -- plan immediate actions for emergency cases -- condition: ta_ot_find_emergencies.emergency_count > 0	\N	["emergency_actions"]	\N	f	t	1
ta_ot_score_efficiency	sa_ot_analysis	OT efficiency optimisation — calculate overall OT efficiency score from delays, instrument gaps, and conflicts — always include	\N	["efficiency_score"]	\N	f	t	0
ta_analyze_ot_capacity	sa_ot_analysis	Per-case disposition — recommend proceed/delay/escalate for each case from conflicts, emergencies, and capacity — always include	\N	["case_recommendations", "recommendation_count", "escalate_count", "delay_count", "proceed_count", "summary"]	\N	f	t	1
ta_ot_defer_electives	sa_ot_analysis	Reprioritisation (executable) — move the electives flagged delay to a later open theatre slot to free capacity for higher-acuity cases; stages the moves for commit — include when electives must yield to a non-elective/emergency or a conflict	\N	["deferred", "proposals", "status"]	\N	f	t	2
ta_identify_revenue_leakage	sa_rev_optimization	Identify revenue leakage across departments and workflows — always include	\N	["leakage_detected", "leakage_amount", "unbilled_count"]	\N	f	t	0
ta_optimize_package_utilization	sa_rev_optimization	Optimize treatment and insurance package utilization — ONLY when goal involves package billing or package optimization	\N	["packages_reviewed", "savings_identified", "recommendations"]	\N	f	t	1
ta_analyze_resource_utilization	sa_rev_optimization	Analyze utilization efficiency across hospital resources — always include	\N	["utilization_score", "idle_equipment_count", "bottlenecks"]	\N	f	t	2
ta_analyze_dept_profitability	sa_rev_optimization	Analyze profitability across departments and specialties — ONLY when goal involves department performance or profitability analysis	\N	["dept_count", "below_target_count", "recommendations"]	\N	f	t	3
ta_predict_denial_risk_rev	sa_rev_denial_prevention	Predict insurance claim denial risk before submission — always include	\N	["high_risk_count", "medium_risk_count", "denial_probability"]	\N	f	t	0
ta_presubmission_validation_rev	sa_rev_denial_prevention	Validate claims before payer submission — ONLY when goal is NOT a snapshot, report, or dashboard; condition: ta_predict_denial_risk_rev.high_risk_count > 0	\N	["validation_passed", "issues_found", "missing_fields_count"]	\N	f	t	1
ta_payer_rule_compliance_rev	sa_rev_denial_prevention	Validate claims against payer-specific policies — always include	\N	["compliance_issues", "non_covered_count", "auth_missing_count"]	\N	f	t	2
ta_detect_missing_docs_rev	sa_rev_denial_prevention	Detect incomplete documentation before claim submission — always include	\N	["missing_docs_count", "missing_summaries", "missing_signatures"]	\N	f	t	3
ta_escalation_recommendations_rev	sa_rev_denial_prevention	Recommend escalation actions for high-risk revenue cases — condition: ta_predict_denial_risk_rev.high_risk_count > 0	\N	["escalated", "escalation_count"]	\N	f	t	4
ta_detect_claim_discrepancies	sa_claim_validation	Detect duplicate claims, missing invoice linkages, and amount mismatches	\N	["discrepancy_count", "missing_invoice", "duplicate_claims"]	\N	f	t	0
ta_validate_insurance_eligibility	sa_claim_validation	Check all pending claims for missing TPA linkage and unverified insurance	\N	["eligibility_issues", "no_tpa_pending_count", "unverified_amount"]	\N	f	t	1
ta_check_billing_compliance	sa_claim_validation	Flag claims and invoices missing required fields or violating coding rules	\N	["total_compliance_issues", "claim_compliance_issues", "invoice_compliance_issues"]	\N	f	t	2
ta_track_pending_payments	sa_billing_optimization	Bucket overdue invoices by SLA and flag high-value accounts for follow-up	\N	["overdue_count", "overdue_amount", "high_value_count"]	\N	f	t	0
ta_detect_revenue_leakage	sa_billing_optimization	Find claims without invoices and low-value IPD billing gaps	\N	["unlinked_claims_count", "estimated_leakage", "leakage_detected"]	\N	f	t	1
ta_generate_billing_recommendations	sa_billing_optimization	Synthesises billing state into prioritised optimisation recommendations	\N	["recommendation_count", "recommendations"]	\N	f	t	2
ta_prioritize_payments	sa_billing_optimization	Rank outstanding invoices by value × aging for targeted collection	\N	["prioritized_count", "total_recoverable", "top_priority"]	\N	f	t	3
ta_trigger_payment_reminder	sa_billing_optimization	Send payment reminders for overdue invoices — condition: ta_track_pending_payments.overdue_count > 0	\N	["reminders_sent"]	\N	f	t	4
ta_notify_followup_team	sa_billing_optimization	Notify follow-up team about claims awaiting payer response — condition: ta_validate_insurance_eligibility.no_tpa_pending_count > 0	\N	["notified"]	\N	f	t	5
ta_get_patient_invoices	sa_rev_patient_billing	Fetch all invoices and claims for a specific patient	\N	["invoices", "claims"]	\N	f	t	0
ta_create_billing_request	sa_rev_initiate_billing	Create a bill-generation request for the resolved patient(s) -- always include when the goal is to initiate/generate/raise a bill or invoice for a patient	\N	["billing_requests", "patient_count", "status"]	\N	f	t	0
ta_identify_patients	sa_patient_identification	Identify incoming patient(s) by mobile and resolve token + vitals -- always include	\N	["verified_count", "unknown_count", "patients"]	\N	f	t	0
ta_flag_unknown_patients	sa_patient_identification	Flag incoming patient(s) with no record -- condition: ta_identify_patients.unknown_count > 0	\N	["flagged"]	\N	f	t	1
ta_register_patient	sa_patient_registration	Request registration of the unknown incoming patient(s) and pause until created	\N	["requested", "registered", "still_unknown", "patients"]	\N	f	t	0
exec__analyze_icu	sa_icu_stepdown	Patient transfer recommendations	Identifies which patients should move between the ICU and regular wards based on their current condition and care needs.	[]	def execute(inp: dict) -> dict:\n    available_beds = inp.get("available_beds", [])\n    icu_patients = inp.get("icu_patients", [])\n    escalation_candidates_input = inp.get("escalation_candidates", [])\n    \n    step_down_candidates = []\n    escalation_candidates = []\n    \n    for patient in icu_patients:\n        admission_id = patient.get("admission_id", "")\n        ventilation = patient.get("ventilation", "")\n        vitals = patient.get("vitals", {})\n        \n        spo2 = vitals.get("spo2", 0)\n        pulse = vitals.get("pulse", 0)\n        bp_systolic = vitals.get("bp_systolic", 0)\n        resp_rate = vitals.get("resp_rate", 0)\n        temp = vitals.get("temp", 0)\n        \n        vitals_stable = spo2 >= 95 and 60 <= pulse <= 100 and 90 <= bp_systolic <= 140 and 12 <= resp_rate <= 20 and 36.0 <= temp <= 37.5\n        \n        if vitals_stable and ventilation != "full_ventilator":\n            confidence = "high" if spo2 >= 98 and 70 <= pulse <= 90 and 100 <= bp_systolic <= 130 else "medium"\n            step_down_candidates.append({"admission_id": admission_id, "reason": "Stable vitals and no full ventilator support", "confidence": confidence})\n    \n    for candidate in escalation_candidates_input:\n        admission_id = candidate.get("admission_id", "")\n        vitals = candidate.get("vitals", {})\n        \n        spo2 = vitals.get("spo2", 100)\n        pulse = vitals.get("pulse", 70)\n        bp_systolic = vitals.get("bp_systolic", 120)\n        resp_rate = vitals.get("resp_rate", 16)\n        temp = vitals.get("temp", 36.5)\n        \n        critical_count = 0\n        critical_reasons = []\n        \n        if spo2 < 90:\n            critical_count += 1\n            critical_reasons.append("severe hypoxemia")\n        elif spo2 < 95:\n            critical_reasons.append("hypoxemia")\n        \n        if pulse < 50 or pulse > 120:\n            critical_count += 1\n            critical_reasons.append("severe bradycardia" if pulse < 50 else "severe tachycardia")\n        elif pulse < 60 or pulse > 100:\n            critical_reasons.append("bradycardia" if pulse < 60 else "tachycardia")\n        \n        if bp_systolic < 80 or bp_systolic > 180:\n            critical_count += 1\n            critical_reasons.append("severe hypotension" if bp_systolic < 80 else "severe hypertension")\n        elif bp_systolic < 90 or bp_systolic > 160:\n            critical_reasons.append("hypotension" if bp_systolic < 90 else "hypertension")\n        \n        if resp_rate < 8 or resp_rate > 30:\n            critical_count += 1\n            critical_reasons.append("severe respiratory depression" if resp_rate < 8 else "severe tachypnea")\n        elif resp_rate < 12 or resp_rate > 24:\n            critical_reasons.append("bradypnea" if resp_rate < 12 else "tachypnea")\n        \n        if temp < 35.0 or temp > 39.0:\n            critical_count += 1\n            critical_reasons.append("severe hypothermia" if temp < 35.0 else "severe hyperthermia")\n        elif temp < 36.0 or temp > 38.0:\n            critical_reasons.append("hypothermia" if temp < 36.0 else "hyperthermia")\n        \n        if critical_count >= 2:\n            urgency = "immediate"\n            reason = "Multiple critical vital signs: " + ", ".join(critical_reasons[:3])\n        elif critical_count == 1:\n            urgency = "urgent"\n            reason = "Critical vital signs: " + ", ".join(critical_reasons[:2])\n        elif len(critical_reasons) >= 2:\n            urgency = "watch"\n            reason = "Concerning vital signs: " + ", ".join(critical_reasons[:2])\n        else:\n            continue\n        \n        escalation_candidates.append({"admission_id": admission_id, "reason": reason, "urgency": urgency})\n    \n    step_down_count = len(step_down_candidates)\n    escalation_count = len(escalation_candidates)\n    immediate_count = len([c for c in escalation_candidates if c.get("urgency") == "immediate"])\n    \n    if step_down_count == 0 and escalation_count == 0:\n        summary = "No ICU flow changes recommended at this time. All ICU patients require continued intensive care and no ward patients need escalation."\n    elif immediate_count > 0:\n        summary = f"Critical situation: {immediate_count} patient(s) need immediate ICU admission. {step_down_count} ICU patient(s) can be stepped down to create capacity."\n    else:\n        summary = f"Recommended ICU flow: {step_down_count} patient(s) ready for step-down, {escalation_count} patient(s) may benefit from ICU monitoring."\n    \n    return {"step_down_candidates": step_down_candidates, "escalation_candidates": escalation_candidates, "summary": summary}	f	t	9999
exec__assess_discharge	sa_discharge_ready	Check discharge readiness	Reviews patient's vital signs and outstanding care tasks to determine if they are medically stable and ready to leave the hospital.	[]	def execute(inp: dict) -> dict:\n    pending_task_count = inp.get("pending_task_count", 0)\n    vitals = inp.get("vitals")\n    \n    if pending_task_count > 0:\n        return {"discharge_ready": False, "blocked_reason": "pending_tasks", "assessment": "Patient has incomplete nursing tasks that must be completed before discharge."}\n    \n    if vitals is None:\n        return {"discharge_ready": False, "blocked_reason": "needs_review", "assessment": "Patient requires vital signs assessment before discharge evaluation."}\n    \n    temperature = vitals.get("temperature")\n    pulse = vitals.get("pulse")\n    spo2 = vitals.get("spo2")\n    bp_systolic = vitals.get("bp_systolic")\n    respiratory_rate = vitals.get("respiratory_rate")\n    \n    if temperature is None or pulse is None or spo2 is None or bp_systolic is None or respiratory_rate is None:\n        return {"discharge_ready": False, "blocked_reason": "needs_review", "assessment": "Patient requires complete vital signs assessment before discharge evaluation."}\n    \n    if temperature > 38 or temperature < 36 or pulse < 50 or pulse > 120 or spo2 < 94 or bp_systolic < 90 or bp_systolic > 160 or respiratory_rate < 10 or respiratory_rate > 25:\n        return {"discharge_ready": False, "blocked_reason": "vitals_unstable", "assessment": "Patient has unstable vital signs requiring continued monitoring and treatment."}\n    \n    return {"discharge_ready": True, "blocked_reason": "", "assessment": "Patient meets all clinical criteria for safe discharge with stable vital signs."}	f	t	9999
\.


--
-- Data for Name: checkpoint_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.checkpoint_migrations (v) FROM stdin;
0
1
2
3
4
5
6
7
8
9
\.


--
-- Name: agent_budget agent_budget_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.agent_budget
    ADD CONSTRAINT agent_budget_pkey PRIMARY KEY (id);


--
-- Name: auction_bid auction_bid_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.auction_bid
    ADD CONSTRAINT auction_bid_pkey PRIMARY KEY (id);


--
-- Name: auction_outcome auction_outcome_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.auction_outcome
    ADD CONSTRAINT auction_outcome_pkey PRIMARY KEY (id);


--
-- Name: auction auction_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.auction
    ADD CONSTRAINT auction_pkey PRIMARY KEY (id);


--
-- Name: forecast_history forecast_history_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.forecast_history
    ADD CONSTRAINT forecast_history_pkey PRIMARY KEY (id);


--
-- Name: pending_observation pending_observation_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.pending_observation
    ADD CONSTRAINT pending_observation_pkey PRIMARY KEY (id);


--
-- Name: utility_snapshot utility_snapshot_pkey; Type: CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.utility_snapshot
    ADD CONSTRAINT utility_snapshot_pkey PRIMARY KEY (id);


--
-- Name: checkpoint_blobs checkpoint_blobs_pkey; Type: CONSTRAINT; Schema: hospilot; Owner: -
--

ALTER TABLE ONLY hospilot.checkpoint_blobs
    ADD CONSTRAINT checkpoint_blobs_pkey PRIMARY KEY (thread_id, checkpoint_ns, channel, version);


--
-- Name: checkpoint_migrations checkpoint_migrations_pkey; Type: CONSTRAINT; Schema: hospilot; Owner: -
--

ALTER TABLE ONLY hospilot.checkpoint_migrations
    ADD CONSTRAINT checkpoint_migrations_pkey PRIMARY KEY (v);


--
-- Name: checkpoint_writes checkpoint_writes_pkey; Type: CONSTRAINT; Schema: hospilot; Owner: -
--

ALTER TABLE ONLY hospilot.checkpoint_writes
    ADD CONSTRAINT checkpoint_writes_pkey PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id, task_id, idx);


--
-- Name: checkpoints checkpoints_pkey; Type: CONSTRAINT; Schema: hospilot; Owner: -
--

ALTER TABLE ONLY hospilot.checkpoints
    ADD CONSTRAINT checkpoints_pkey PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id);


--
-- Name: advisories advisories_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.advisories
    ADD CONSTRAINT advisories_pkey PRIMARY KEY (id);


--
-- Name: advisory_rules advisory_rules_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.advisory_rules
    ADD CONSTRAINT advisory_rules_pkey PRIMARY KEY (id);


--
-- Name: advisory_rules advisory_rules_rule_key_key; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.advisory_rules
    ADD CONSTRAINT advisory_rules_rule_key_key UNIQUE (rule_key);


--
-- Name: agent_registry agent_registry_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.agent_registry
    ADD CONSTRAINT agent_registry_pkey PRIMARY KEY (id);


--
-- Name: approval_tasks approval_tasks_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.approval_tasks
    ADD CONSTRAINT approval_tasks_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);


--
-- Name: rag_conversation rag_conversation_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.rag_conversation
    ADD CONSTRAINT rag_conversation_pkey PRIMARY KEY (id);


--
-- Name: rag_memory rag_memory_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.rag_memory
    ADD CONSTRAINT rag_memory_pkey PRIMARY KEY (id);


--
-- Name: rag_message rag_message_conversation_seq_key; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.rag_message
    ADD CONSTRAINT rag_message_conversation_seq_key UNIQUE (conversation_id, seq);


--
-- Name: rag_message rag_message_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.rag_message
    ADD CONSTRAINT rag_message_pkey PRIMARY KEY (id);


--
-- Name: scheduled_queries scheduled_queries_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.scheduled_queries
    ADD CONSTRAINT scheduled_queries_pkey PRIMARY KEY (id);


--
-- Name: session_agent_overrides session_agent_overrides_session_id_agent_id_key; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.session_agent_overrides
    ADD CONSTRAINT session_agent_overrides_session_id_agent_id_key UNIQUE (session_id, agent_id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: subagent_registry subagent_registry_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.subagent_registry
    ADD CONSTRAINT subagent_registry_pkey PRIMARY KEY (id);


--
-- Name: task_registry task_registry_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.task_registry
    ADD CONSTRAINT task_registry_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: checkpoint_blobs checkpoint_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkpoint_blobs
    ADD CONSTRAINT checkpoint_blobs_pkey PRIMARY KEY (thread_id, checkpoint_ns, channel, version);


--
-- Name: checkpoint_migrations checkpoint_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkpoint_migrations
    ADD CONSTRAINT checkpoint_migrations_pkey PRIMARY KEY (v);


--
-- Name: checkpoint_writes checkpoint_writes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkpoint_writes
    ADD CONSTRAINT checkpoint_writes_pkey PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id, task_id, idx);


--
-- Name: checkpoints checkpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkpoints
    ADD CONSTRAINT checkpoints_pkey PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id);


--
-- Name: agent_budget_shift_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX agent_budget_shift_idx ON allocation.agent_budget USING btree (shift_start DESC);


--
-- Name: agent_budget_uniq; Type: INDEX; Schema: allocation; Owner: -
--

CREATE UNIQUE INDEX agent_budget_uniq ON allocation.agent_budget USING btree (agent, shift_id);


--
-- Name: auction_bid_agent_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX auction_bid_agent_idx ON allocation.auction_bid USING btree (agent, decided_at DESC);


--
-- Name: auction_bid_q_action_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX auction_bid_q_action_idx ON allocation.auction_bid USING btree (q_action) WHERE (q_action IS NOT NULL);


--
-- Name: auction_bid_uniq; Type: INDEX; Schema: allocation; Owner: -
--

CREATE UNIQUE INDEX auction_bid_uniq ON allocation.auction_bid USING btree (auction_id, round_index, agent);


--
-- Name: auction_key_live_uniq; Type: INDEX; Schema: allocation; Owner: -
--

CREATE UNIQUE INDEX auction_key_live_uniq ON allocation.auction USING btree (auction_key) WHERE (mode = 'live'::text);


--
-- Name: auction_opened_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX auction_opened_idx ON allocation.auction USING btree (opened_at DESC);


--
-- Name: auction_outcome_uniq; Type: INDEX; Schema: allocation; Owner: -
--

CREATE UNIQUE INDEX auction_outcome_uniq ON allocation.auction_outcome USING btree (auction_id);


--
-- Name: auction_resource_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX auction_resource_idx ON allocation.auction USING btree (resource_type, resource_id);


--
-- Name: auction_training_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX auction_training_idx ON allocation.auction USING btree (mode, closed_at) WHERE (mode = 'live'::text);


--
-- Name: forecast_history_for_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX forecast_history_for_idx ON allocation.forecast_history USING btree (forecast_for);


--
-- Name: forecast_history_median_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX forecast_history_median_idx ON allocation.forecast_history USING btree (endpoint, scope, horizon, computed_at DESC);


--
-- Name: pending_observation_auction_uniq; Type: INDEX; Schema: allocation; Owner: -
--

CREATE UNIQUE INDEX pending_observation_auction_uniq ON allocation.pending_observation USING btree (auction_id);


--
-- Name: pending_observation_due_idx; Type: INDEX; Schema: allocation; Owner: -
--

CREATE INDEX pending_observation_due_idx ON allocation.pending_observation USING btree (due_at) WHERE (status = 'pending'::text);


--
-- Name: utility_snapshot_uniq; Type: INDEX; Schema: allocation; Owner: -
--

CREATE UNIQUE INDEX utility_snapshot_uniq ON allocation.utility_snapshot USING btree (auction_id, round_index);


--
-- Name: checkpoint_blobs_thread_id_idx; Type: INDEX; Schema: hospilot; Owner: -
--

CREATE INDEX checkpoint_blobs_thread_id_idx ON hospilot.checkpoint_blobs USING btree (thread_id);


--
-- Name: checkpoint_writes_thread_id_idx; Type: INDEX; Schema: hospilot; Owner: -
--

CREATE INDEX checkpoint_writes_thread_id_idx ON hospilot.checkpoint_writes USING btree (thread_id);


--
-- Name: checkpoints_thread_id_idx; Type: INDEX; Schema: hospilot; Owner: -
--

CREATE INDEX checkpoints_thread_id_idx ON hospilot.checkpoints USING btree (thread_id);


--
-- Name: idx_advisories_rule; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_advisories_rule ON hospilot_app.advisories USING btree (rule_key, created_at DESC);


--
-- Name: idx_advisories_status_created; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_advisories_status_created ON hospilot_app.advisories USING btree (status, created_at DESC);


--
-- Name: idx_advisory_rules_due; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_advisory_rules_due ON hospilot_app.advisory_rules USING btree (enabled, next_check_at);


--
-- Name: idx_approval_tasks_session; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_approval_tasks_session ON hospilot_app.approval_tasks USING btree (session_id);


--
-- Name: idx_approval_tasks_status; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_approval_tasks_status ON hospilot_app.approval_tasks USING btree (status, created_at DESC);


--
-- Name: idx_audit_log_session; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_audit_log_session ON hospilot_app.audit_log USING btree (session_id);


--
-- Name: idx_rag_conversation_created; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_rag_conversation_created ON hospilot_app.rag_conversation USING btree (created_at DESC);


--
-- Name: idx_rag_conversation_user; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_rag_conversation_user ON hospilot_app.rag_conversation USING btree (user_id);


--
-- Name: idx_rag_memory_user; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_rag_memory_user ON hospilot_app.rag_memory USING btree (user_id, updated_at DESC);


--
-- Name: idx_rag_message_conversation; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_rag_message_conversation ON hospilot_app.rag_message USING btree (conversation_id, seq);


--
-- Name: idx_scheduled_queries_due; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_scheduled_queries_due ON hospilot_app.scheduled_queries USING btree (enabled, next_run_at);


--
-- Name: idx_scheduled_queries_user; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_scheduled_queries_user ON hospilot_app.scheduled_queries USING btree (user_id);


--
-- Name: idx_sessions_created; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_sessions_created ON hospilot_app.sessions USING btree (created_at DESC);


--
-- Name: idx_sessions_scheduled_query; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_sessions_scheduled_query ON hospilot_app.sessions USING btree (scheduled_query_id);


--
-- Name: idx_sessions_user_id; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX idx_sessions_user_id ON hospilot_app.sessions USING btree (user_id);


--
-- Name: subagent_registry_agent_id_idx; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX subagent_registry_agent_id_idx ON hospilot_app.subagent_registry USING btree (agent_id);


--
-- Name: task_registry_dynamic_active_idx; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX task_registry_dynamic_active_idx ON hospilot_app.task_registry USING btree (is_dynamic, is_active) WHERE ((function_code IS NOT NULL) AND (function_code <> ''::text));


--
-- Name: task_registry_subagent_id_idx; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX task_registry_subagent_id_idx ON hospilot_app.task_registry USING btree (subagent_id);


--
-- Name: users_org_id_idx; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX users_org_id_idx ON hospilot_app.users USING btree (org_id);


--
-- Name: users_role_idx; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX users_role_idx ON hospilot_app.users USING btree (role);


--
-- Name: users_status_idx; Type: INDEX; Schema: hospilot_app; Owner: -
--

CREATE INDEX users_status_idx ON hospilot_app.users USING btree (status);


--
-- Name: checkpoint_blobs_thread_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checkpoint_blobs_thread_id_idx ON public.checkpoint_blobs USING btree (thread_id);


--
-- Name: checkpoint_writes_thread_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checkpoint_writes_thread_id_idx ON public.checkpoint_writes USING btree (thread_id);


--
-- Name: checkpoints_thread_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checkpoints_thread_id_idx ON public.checkpoints USING btree (thread_id);


--
-- Name: advisories set_hospilot_app_advisories_updated_at; Type: TRIGGER; Schema: hospilot_app; Owner: -
--

CREATE TRIGGER set_hospilot_app_advisories_updated_at BEFORE UPDATE ON hospilot_app.advisories FOR EACH ROW EXECUTE FUNCTION hospilot_app.set_current_timestamp_updated_at();


--
-- Name: advisory_rules set_hospilot_app_advisory_rules_updated_at; Type: TRIGGER; Schema: hospilot_app; Owner: -
--

CREATE TRIGGER set_hospilot_app_advisory_rules_updated_at BEFORE UPDATE ON hospilot_app.advisory_rules FOR EACH ROW EXECUTE FUNCTION hospilot_app.set_current_timestamp_updated_at();


--
-- Name: rag_conversation set_hospilot_app_rag_conversation_updated_at; Type: TRIGGER; Schema: hospilot_app; Owner: -
--

CREATE TRIGGER set_hospilot_app_rag_conversation_updated_at BEFORE UPDATE ON hospilot_app.rag_conversation FOR EACH ROW EXECUTE FUNCTION hospilot_app.set_current_timestamp_updated_at();


--
-- Name: rag_memory set_hospilot_app_rag_memory_updated_at; Type: TRIGGER; Schema: hospilot_app; Owner: -
--

CREATE TRIGGER set_hospilot_app_rag_memory_updated_at BEFORE UPDATE ON hospilot_app.rag_memory FOR EACH ROW EXECUTE FUNCTION hospilot_app.set_current_timestamp_updated_at();


--
-- Name: scheduled_queries set_hospilot_app_scheduled_queries_updated_at; Type: TRIGGER; Schema: hospilot_app; Owner: -
--

CREATE TRIGGER set_hospilot_app_scheduled_queries_updated_at BEFORE UPDATE ON hospilot_app.scheduled_queries FOR EACH ROW EXECUTE FUNCTION hospilot_app.set_current_timestamp_updated_at();


--
-- Name: sessions set_hospilot_app_sessions_updated_at; Type: TRIGGER; Schema: hospilot_app; Owner: -
--

CREATE TRIGGER set_hospilot_app_sessions_updated_at BEFORE UPDATE ON hospilot_app.sessions FOR EACH ROW EXECUTE FUNCTION hospilot_app.set_current_timestamp_updated_at();


--
-- Name: auction_bid auction_bid_auction_id_fkey; Type: FK CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.auction_bid
    ADD CONSTRAINT auction_bid_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES allocation.auction(id) ON DELETE CASCADE;


--
-- Name: auction_outcome auction_outcome_auction_id_fkey; Type: FK CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.auction_outcome
    ADD CONSTRAINT auction_outcome_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES allocation.auction(id) ON DELETE CASCADE;


--
-- Name: pending_observation pending_observation_auction_id_fkey; Type: FK CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.pending_observation
    ADD CONSTRAINT pending_observation_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES allocation.auction(id) ON DELETE CASCADE;


--
-- Name: utility_snapshot utility_snapshot_auction_id_fkey; Type: FK CONSTRAINT; Schema: allocation; Owner: -
--

ALTER TABLE ONLY allocation.utility_snapshot
    ADD CONSTRAINT utility_snapshot_auction_id_fkey FOREIGN KEY (auction_id) REFERENCES allocation.auction(id) ON DELETE CASCADE;


--
-- Name: approval_tasks approval_tasks_session_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.approval_tasks
    ADD CONSTRAINT approval_tasks_session_id_fkey FOREIGN KEY (session_id) REFERENCES hospilot_app.sessions(id) ON DELETE CASCADE;


--
-- Name: audit_log audit_log_session_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.audit_log
    ADD CONSTRAINT audit_log_session_id_fkey FOREIGN KEY (session_id) REFERENCES hospilot_app.sessions(id) ON DELETE CASCADE;


--
-- Name: rag_message rag_message_conversation_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.rag_message
    ADD CONSTRAINT rag_message_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES hospilot_app.rag_conversation(id) ON DELETE CASCADE;


--
-- Name: session_agent_overrides session_agent_overrides_session_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.session_agent_overrides
    ADD CONSTRAINT session_agent_overrides_session_id_fkey FOREIGN KEY (session_id) REFERENCES hospilot_app.sessions(id) ON DELETE CASCADE;


--
-- Name: subagent_registry subagent_registry_agent_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.subagent_registry
    ADD CONSTRAINT subagent_registry_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES hospilot_app.agent_registry(id);


--
-- Name: task_registry task_registry_subagent_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.task_registry
    ADD CONSTRAINT task_registry_subagent_id_fkey FOREIGN KEY (subagent_id) REFERENCES hospilot_app.subagent_registry(id);


--
-- Name: users users_org_id_fkey; Type: FK CONSTRAINT; Schema: hospilot_app; Owner: -
--

ALTER TABLE ONLY hospilot_app.users
    ADD CONSTRAINT users_org_id_fkey FOREIGN KEY (org_id) REFERENCES hospilot_app.organizations(id);


--
-- PostgreSQL database dump complete
--

\unrestrict kLqhQU9m1axgv3E38qMnLapNwtipI1UpBUGwVxZCr5nwR0PQIVTcdcCZjIzVCZe


-- 097_lab_critical_escalations.sql
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
