---
title: StreamlineHMIS
emoji: 👁
colorFrom: yellow
colorTo: purple
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: Streamline command center
---

# Hospilot — Hugging Face Space

All-in-one demo of Hospilot: web UI, agentic-framework backend, Fabric (FHIR R5 layer),
a mock HIS, Hasura + Postgres and Redis in a single container. Kafka and Temporal are
disabled (both optional).

## Space secrets

| Name | Required | Notes |
|---|---|---|
| `LLM_API_KEY` | yes | OpenRouter (or other OpenAI-compatible) API key |
| `BOOTSTRAP_ADMIN_PASSWORD` | yes | Password for the admin login |
| `BOOTSTRAP_ADMIN_USERNAME` | no | Defaults to `admin` |
| `JWT_SECRET` | no | Random per boot if unset (sessions log out on restart) |

Optional variables: `LLM_PROVIDER`, `LLM_BASE_URL`, `LLM_MODEL`, `LLM_FAST_MODEL`,
`LLM_QUALITY_MODEL`, `ANTHROPIC_API_KEY`.

Without persistent storage, the database is re-seeded on every restart.
