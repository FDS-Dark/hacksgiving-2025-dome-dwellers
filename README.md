# Dome Dwellers

**An AI-powered mobile visitor engagement platform for the Milwaukee Domes Alliance**

---

## Overview

Dome Dwellers is a full-stack, cross-platform mobile application built during the HacksGiving 2025 hackathon to modernize the visitor experience at the Mitchell Park Domes in Milwaukee, Wisconsin. The platform gives the Milwaukee Domes Alliance — a non-profit botanical garden organization — production-grade digital capabilities that have traditionally been out of reach due to budget constraints.

The system pairs a React Native/Expo mobile app with a FastAPI backend to deliver an interactive visitor experience, an AI-driven brainstorming assistant for staff, and a comprehensive set of administrative tools — all completed within a 72-hour competition window.

---

## Key Features

### Visitor Features

- **QR Code Scrapbook** — Gamified plant discovery system where visitors scan QR codes placed throughout the domes to build a personal digital collection of discovered species, complete with rarity tiers, favorites, and personal notes.
- **Plant Encyclopedia** — Searchable catalog of 100+ plant species with detailed articles, taxonomy, and imagery sourced from data spanning 21 botanical gardens nationwide.
- **Interactive Visitor Guide** — Per-dome guides covering the Desert Dome, Tropical Dome, and Show Dome, including tours, routes, accessibility information, and seasonal content.
- **Event Calendar & Registration** — Real-time event listings with in-app registration and modal-based registration flows.
- **Real-Time Announcements** — Push-style announcements surfaced to visitors within the app.
- **Tickets & Donations** — In-app ticket purchasing and donation flows powered by Stripe.
- **Plant Trivia & Wordle** — Engagement mini-games for visitors to test their botanical knowledge.
- **Multi-Language Support** — Localization for English, Spanish, French, German, Polish, Russian, Ukrainian, Chinese, and Hmong via i18n-js and Google Cloud Translate.
- **Gift Shop** — In-app browsing and purchasing for the Domes gift shop.

### Staff / Admin Features

- **Staff Panel** — Dedicated administrative interface accessible to authenticated staff accounts.
- **QR Code Management** — Generate, label, activate, deactivate, and bulk-export QR codes as PNG images or ZIP archives for physical placement throughout exhibits.
- **Plant Inventory Management** — Manage plant species records, individual plant instances, storage locations, stock requests, and plant notes.
- **Visitor Feedback Collection** — Structured feedback submission and staff review tooling.
- **Task Management** — Internal staff task tracking and assignment system.
- **Business Analytics Dashboard** — Aggregate visitor and engagement metrics for operational reporting.
- **AI Brainstorming Assistant** — GPT-4o powered chat interface seeded with data from 21 comparable botanical gardens, enabling staff to generate ideas and benchmark the Domes against peer institutions. Supports multiple response personas: Critical, Creative, Optimistic, and Pirate.
- **Announcement Management** — Create and publish announcements that surface to all active visitors.

---

## Tech Stack

### Mobile (app/)

| Layer | Technology |
|---|---|
| Framework | React Native 0.81 / Expo SDK 54 |
| Routing | Expo Router 6 (file-based) |
| State / Data Fetching | TanStack React Query 5 |
| Authentication | Auth0 via expo-auth-session (PKCE) |
| Camera / QR Scanning | expo-camera |
| Payments | Stripe (via API) |
| Localization | i18n-js + Google Cloud Translate |
| HTTP Client | Axios |
| Language | TypeScript 5.9 |

### Backend (api/)

| Layer | Technology |
|---|---|
| Framework | FastAPI (Python 3.13) |
| Server | Uvicorn (port 8443) |
| Package Manager | uv |
| AI / LLM | OpenAI GPT-4o |
| Authentication | Auth0 (JWT / OAuth2 PKCE) |
| Payments | Stripe Python SDK |
| QR Generation | qrcode + Pillow |
| Data Validation | Pydantic v2 / pydantic-settings |
| Database Driver | asyncpg + SQLAlchemy 2.0 |
| Search | RapidFuzz (fuzzy plant name matching) |

### Database / Auth

| Layer | Technology |
|---|---|
| Database | Supabase (PostgreSQL) |
| Migrations | Supabase CLI |
| Auth Provider | Auth0 |

### Infrastructure

| Layer | Technology |
|---|---|
| Containerization | Docker / Docker Compose |
| Networking | Tailscale (optional, for local dev tunneling) |
| API Versioning | `/api/v1` prefix throughout |

---

## Architecture Overview

```
┌──────────────────────────────────────┐
│         React Native / Expo App       │
│  (iOS · Android · Web via Expo Go)   │
└────────────────┬─────────────────────┘
                 │ HTTPS / REST
                 ▼
┌──────────────────────────────────────┐
│           FastAPI Backend             │
│  /api/v1/{dome, plants, scrapbook,   │
│   chat, inventory, qr-admin,         │
│   announcements, tasks, feedback,    │
│   stripe, user}                      │
└──────┬───────────────────┬───────────┘
       │                   │
       ▼                   ▼
┌─────────────┐   ┌─────────────────────┐
│  Supabase   │   │  External Services  │
│  PostgreSQL │   │  · Auth0 (authn)    │
│             │   │  · OpenAI GPT-4o    │
│             │   │  · Stripe           │
└─────────────┘   └─────────────────────┘
```

Authentication flows through Auth0, which issues JWTs validated by FastAPI middleware on every protected route. The Expo app exchanges Auth0 tokens using the PKCE flow via `expo-auth-session`. Supabase serves as the primary data store, with stored procedures handling gamification logic, QR token resolution, and business analytics aggregation. The OpenAI integration is context-fed via `chat_context.txt`, a curated document derived from research on 21 peer botanical gardens and conservatories.

---

## Repository Structure

```
.
├── app/                        # React Native / Expo mobile application
│   ├── app/                    # Expo Router file-based pages
│   │   ├── (main)/             # Authenticated visitor screens
│   │   │   ├── index.tsx       # Home screen
│   │   │   ├── scrapbook.tsx   # QR scrapbook collection
│   │   │   ├── guide/          # Per-dome visitor guides
│   │   │   ├── announcements.tsx
│   │   │   ├── events.tsx
│   │   │   ├── map.tsx
│   │   │   └── staff-panel.tsx # Admin interface
│   │   ├── brainstorm-chat.tsx # AI assistant screen
│   │   ├── plant-encyclopedia.tsx
│   │   ├── plant-details.tsx
│   │   ├── plant-trivia.tsx
│   │   ├── plant-wordle.tsx
│   │   ├── scan.tsx            # QR code camera scanner
│   │   ├── tickets.tsx
│   │   ├── donation.tsx
│   │   ├── login.tsx / signup.tsx
│   │   └── qr-management.tsx
│   ├── components/             # Shared UI components
│   ├── services/               # API client functions (per domain)
│   ├── hooks/                  # Custom React hooks
│   ├── types/                  # TypeScript type definitions
│   ├── constants/              # App-wide constants
│   ├── i18n/                   # Localization (9 languages)
│   └── app.json                # Expo configuration
│
├── api/                        # FastAPI backend
│   ├── main.py                 # App entry point, router registration, CORS
│   ├── settings.py             # Pydantic settings (env-based config)
│   ├── dependencies.py         # FastAPI dependency injection
│   ├── routers/                # One router per domain
│   ├── models/                 # Pydantic request/response models
│   ├── services/               # Business logic layer
│   ├── databridge/             # Supabase data access layer
│   ├── engine/                 # Core processing utilities
│   ├── chat_context.txt        # AI assistant knowledge base
│   ├── pyproject.toml          # Python dependencies (uv)
│   └── Dockerfile
│
├── supabase/                   # Database schema and migrations
│   ├── migrations/             # Timestamped SQL migration files
│   ├── schemas/                # Schema definitions
│   └── config.toml
│
├── utils/                      # Data tooling and seeding scripts
│   ├── generate_plant_articles.py
│   ├── import_plant_articles.py
│   ├── upsert_plants_to_db.py
│   ├── seed_plant_articles.py
│   └── plant_articles.ipynb
│
├── Desert_Dome/                # Dome-specific reference content
├── Show_Dome/
├── Tropical_Dome/
│
├── data.ipynb                  # Data processing notebook
├── plants_data.csv             # Raw plant encyclopedia data
├── plants_data_clean.csv       # Cleaned plant data
└── docker-compose.yml          # Backend service orchestration
```

---

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) 18+ and [Bun](https://bun.sh/) (or npm)
- [Expo CLI](https://docs.expo.dev/get-started/installation/) — `npm install -g expo-cli`
- [Python 3.13+](https://www.python.org/)
- [uv](https://docs.astral.sh/uv/) — fast Python package and project manager
- [Docker](https://www.docker.com/) and Docker Compose
- [Supabase CLI](https://supabase.com/docs/guides/cli) (for local database development)
- Auth0 tenant with a configured application and API
- OpenAI API key
- Stripe account (test mode keys for local development)

### Mobile App (Expo)

```bash
cd app

# Install dependencies
bun install
# or: npm install

# Start the Expo development server
npx expo start
```

From the Expo dev tools, press `i` to open in the iOS Simulator, `a` for Android, or scan the QR code with the Expo Go app on a physical device.

To target a specific platform directly:

```bash
npx expo start --ios
npx expo start --android
```

The app reads Auth0 credentials from `app.json` under `expo.extra`. For a production build or custom credentials, update those values or supply them via environment variables before building.

### Backend (FastAPI)

```bash
cd api
```

Create a `.env` file in the `api/` directory. The backend uses the `APP__` prefix with `__` as the nested delimiter for all environment variables:

```env
APP__OPENAI__API_KEY=sk-...
APP__AUTH0__DOMAIN=your-tenant.us.auth0.com
APP__AUTH0__CLIENT_ID=...
APP__AUTH0__CLIENT_SECRET=...
APP__AUTH0__AUDIENCE=https://thedomes.api
APP__AUTH0__SECRET_ID=...
APP__STRIPE__API_KEY=sk_test_...
APP__SUPABASE__URL=http://127.0.0.1:54321
APP__SUPABASE__DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
APP__ENVIRONMENT__NAME=dev
```

```bash
# Install dependencies
uv sync

# Run the development server
uv run uvicorn main:app --host 0.0.0.0 --port 8443 --reload
```

Interactive API docs (Swagger UI) are available at `http://localhost:8443/docs` in dev mode. Docs are disabled in production.

### Backend via Docker

```bash
# From the repository root
docker compose up --build
```

The API container listens on port `8443`. Supabase should be running separately — either via the Supabase CLI locally or pointed at a hosted project.

### Database (Supabase)

```bash
# Start a local Supabase instance
supabase start

# Apply all migrations
supabase db push
```

To seed plant species and articles:

```bash
cd utils
uv sync
uv run python upsert_plants_to_db.py
uv run python import_plant_articles.py
```

---

## Hackathon Context

Dome Dwellers was built at **HacksGiving 2025**, a 72-hour hackathon hosted by the MSOE AI Club in November 2025. The client was the **Milwaukee Domes Alliance**, the non-profit organization that operates the Mitchell Park Horticultural Conservatory — Milwaukee's iconic triple-dome botanical garden.

The team's goal was to deliver digital capabilities the Alliance could not afford to develop independently: a visitor-facing mobile app, an AI-powered staff brainstorming tool, and the infrastructure to run them reliably. The full application — spanning Auth0 integration, Supabase schema design, QR code generation, AI assistant context engineering, Stripe payment flows, and multi-language support — was designed, implemented, and delivered production-ready within the competition window.

The AI brainstorming assistant was grounded with research data from 21 botanical gardens and conservatories across the United States, giving Alliance staff a practical tool to benchmark peer institutions and generate evidence-informed ideas for programming, exhibits, and visitor engagement.

**Team:** MSOE AI Club — Dome Dwellers
**Client:** Milwaukee Domes Alliance
**Event:** HacksGiving 2025
**Timeline:** November 2025 (72 hours)

---

## Links

- [Austin Koske](https://austinkoske.com)
- [Milwaukee Domes Alliance](https://milwaukeedomes.org)
- [MSOE AI Club](https://msoe.edu)
