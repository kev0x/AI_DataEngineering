# Frontend

React + Vite frontend for the finance warehouse dashboard.

This folder owns all browser UI files. The dashboard stays intentionally one page:

- top filter/action bar
- metric cards
- insight cards
- cashflow/category/merchant/account panels
- suggested category rule review cards
- transactions table with column controls and CSV export

The page wireframe and component responsibility map are documented in:

```text
../docs/ui-wireframe.md
```

Important folders:

```text
src/api/          FastAPI request helpers.
src/components/   Presentational React components.
src/controllers/  UI data-loading controllers.
src/domain/       Testable business/view logic classes and helpers.
src/mockData/     Fallback data used when API or DuckDB is unavailable.
```

`App.jsx` is intentionally small. It owns state and page composition. Chart rendering,
filters, rule review, metric cards, and the transaction table live in `src/components/`.
Filtering, date handling, analytics, CSV export, and rule suggestions live in
`src/domain/`.

JSON files cannot have comments, but source files that support comments include a purpose
and dependencies header.

Run locally after installing Node dependencies:

```bash
cd Frontend
npm install
npm run dev
```

The frontend expects the FastAPI backend at:

```text
http://localhost:4000
```

Docker Compose can also start the UI without requiring local Node/npm:

```bash
cd ../Docker
docker compose up -d web
```

Open:

```text
http://localhost:5173
```

The `web` service can start without the API. If FastAPI or DuckDB is down, the dashboard
controller falls back to `src/mockData/dashboardMockData.js`.

Component ownership summary:

```text
App.jsx                 page state and composition
components/             visual sections and controls
controllers/            API orchestration and mock fallback
domain/                 filtering, analytics, suggestions, dates, formatting, export
api/                    FastAPI request helpers
mockData/               dashboard-shaped fallback payload
```

Production build check:

```bash
cd ../Docker
docker compose exec -T web npm run build
```
