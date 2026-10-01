-- 095 · Control-plane bootstrap: organizations, users, agent/subagent/task registry
--
-- WHY THIS FILE EXISTS. `agentic-framework/schemas/sql/tenant_template.sql` documents that
-- users / organizations / the agent+subagent+task registries live in a "control plane" DB,
-- separate from the per-tenant `hospilot_app.*` tables it creates (sessions, approval_tasks,
-- audit_log, rag_*, scheduled_queries, advisory_rules, advisories). That control-plane DDL —
-- referred to in code as "migrations 050/051" (`main.py::_bootstrap_super_admin`,
-- `db/hasura.py::load_org_registry`) — was never exported into this OSS cut. Without it, the
-- backend crashes on boot: `main.py` calls `agents/_shared/generated_activities.load_from_db`
-- with no try/except, which queries `hospilot_app_task_registry` and dies if the table (and
-- its `hospilot_app_agent_registry` / `hospilot_app_subagent_registry` / `hospilot_app_users`
-- / `hospilot_app_organizations` siblings) doesn't exist.
--
-- Reconstructed here from the field lists in `agentic-framework/db/hasura.py` and
-- `agentic-framework/db/provisioning.py` — every column below is one an existing GraphQL
-- query or mutation in this repo actually selects or sets. Written against the DEFAULT
-- Hasura source/DB (the "Carer" org in `db/hasura.py`'s own terms — the one whose tenant
-- tables are unprefixed), matching how `HASURA_URL` / `HASURA_ADMIN_SECRET` are wired in
-- `agentic-framework/.env.example`. Apply this to the same Postgres that
-- `agentic-framework/schemas/sql/hospilot_schema.sql` and `tenant_template.sql` run against,
-- BEFORE first boot.
--
-- Idempotent (IF NOT EXISTS throughout) so re-running against an already-bootstrapped DB is
-- a no-op.
--
-- ⚠ SQL ALONE ISN'T ENOUGH. After applying, track all five tables as Hasura sources (schema
--   `hospilot_app`, source `default`) and create two array relationships by hand — Hasura
--   metadata isn't expressible in plain DDL and `fetch_agent_registry` (db/hasura.py) selects
--   through both of them:
--     hospilot_app.agent_registry     -> subagent_registries  (subagent_registry.agent_id)
--     hospilot_app.subagent_registry  -> task_registries      (task_registry.subagent_id)

BEGIN;

CREATE SCHEMA IF NOT EXISTS hospilot_app;

-- ── organizations ────────────────────────────────────────────────────────────────────────
-- Multi-tenant routing table (db/hasura.py::load_org_registry / create_org / get_org /
-- list_orgs / update_org). `root_prefix` / `hasura_source` are how HasuraClient._resolve_prefix
-- picks which Hasura source a tenant-scoped query hits; the default org (unprefixed tables,
-- this DB) is expected to have root_prefix='' and hasura_source='default'.
CREATE TABLE IF NOT EXISTS hospilot_app.organizations (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name           text NOT NULL,
    slug           text NOT NULL UNIQUE,
    status         text NOT NULL DEFAULT 'active',
    db_name        text,
    hasura_source  text NOT NULL DEFAULT 'default',
    root_prefix    text NOT NULL DEFAULT '',
    created_by     uuid,
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- ── users ────────────────────────────────────────────────────────────────────────────────
-- (db/hasura.py::create_user / get_user_by_username / get_user_by_id / count_users_by_role /
-- list_users / update_user_status / update_user_role). org_id is nullable: the platform
-- super_admin bootstrapped by main.py::_bootstrap_super_admin is org-less by design.
CREATE TABLE IF NOT EXISTS hospilot_app.users (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username       text NOT NULL UNIQUE,
    password_hash  text NOT NULL,
    display_name   text NOT NULL,
    role           text NOT NULL DEFAULT 'doctor',
    org_id         uuid REFERENCES hospilot_app.organizations(id),
    status         text NOT NULL DEFAULT 'pending',
    approved_by    uuid,
    approved_at    timestamptz,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS users_org_id_idx ON hospilot_app.users (org_id);
CREATE INDEX IF NOT EXISTS users_role_idx   ON hospilot_app.users (role);
CREATE INDEX IF NOT EXISTS users_status_idx ON hospilot_app.users (status);

-- ── agent / subagent / task registry ────────────────────────────────────────────────────
-- The planner's live catalog (db/hasura.py::fetch_agent_registry) and the codegen cache
-- (insert_task_to_registry / upsert_executor_code / fetch_all_function_codes /
-- fetch_function_code / fetch_dynamic_tasks). id columns are the human-readable slugs used
-- throughout agents/_shared/manifest.py (e.g. "bed_agent", "sa_ratio_monitor"), not surrogate
-- keys, so downstream code can reference them as string literals.
CREATE TABLE IF NOT EXISTS hospilot_app.agent_registry (
    id           text PRIMARY KEY,
    label        text NOT NULL,
    description  text,
    emoji        text,
    color        text,
    is_active    boolean NOT NULL DEFAULT true,
    sort_order   integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS hospilot_app.subagent_registry (
    id                    text PRIMARY KEY,
    agent_id              text NOT NULL REFERENCES hospilot_app.agent_registry(id),
    label                 text NOT NULL,
    description           text,
    capabilities          jsonb NOT NULL DEFAULT '[]',
    is_prefetch_eligible  boolean NOT NULL DEFAULT false,
    is_active             boolean NOT NULL DEFAULT true,
    sort_order            integer NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS subagent_registry_agent_id_idx
    ON hospilot_app.subagent_registry (agent_id);

-- function_code holds LLM-generated, RestrictedPython-sandboxed task code
-- (workflows/unified_executor.py); is_dynamic distinguishes those from builtin tasks that
-- merely cache their outputs shape here. Constraint name matches the on_conflict clause in
-- db/hasura.py::upsert_executor_code ("task_registry_pkey") — Postgres names a table's own
-- primary key "<table>_pkey" regardless of schema, so this needs no explicit naming.
CREATE TABLE IF NOT EXISTS hospilot_app.task_registry (
    id             text PRIMARY KEY,
    subagent_id    text NOT NULL REFERENCES hospilot_app.subagent_registry(id),
    label          text NOT NULL,
    description    text,
    outputs        jsonb NOT NULL DEFAULT '[]',
    function_code  text,
    is_dynamic     boolean NOT NULL DEFAULT false,
    is_active      boolean NOT NULL DEFAULT true,
    sort_order     integer NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS task_registry_subagent_id_idx
    ON hospilot_app.task_registry (subagent_id);

-- Matches fetch_all_function_codes' filter (is_dynamic, is_active, function_code not empty).
CREATE INDEX IF NOT EXISTS task_registry_dynamic_active_idx
    ON hospilot_app.task_registry (is_dynamic, is_active)
    WHERE function_code IS NOT NULL AND function_code <> '';

COMMIT;
