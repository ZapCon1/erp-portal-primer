# Deploy — <TODO: your company>

> Copy to `deploy.md` **before go-live** (Bootstrap checklist). This is
> the executable version of `docs/STACK.md` § Deployment: one image,
> two processes, Postgres, migrations run exactly once per deploy.

## The shape

```yaml
# docker-compose.yml — skeleton; fill the <TODO>s
services:
  migrate:                # one-shot: runs migrations, exits
    image: <TODO: your image:tag>
    command: npx prisma migrate deploy
    env_file: .env
    depends_on: { db: { condition: service_healthy } }

  web:
    image: <TODO: same image>
    command: node server.js          # next build output: 'standalone'
    env_file: .env
    restart: unless-stopped
    ports: ["3000:3000"]
    depends_on: { migrate: { condition: service_completed_successfully } }
    healthcheck: { test: ["CMD", "wget", "-qO-", "http://localhost:3000/api/health"], interval: 30s }

  worker:                 # pg-boss: jobs, digests, CAD conversion
    image: <TODO: same image>
    command: node worker.js
    env_file: .env
    restart: unless-stopped
    depends_on: { migrate: { condition: service_completed_successfully } }

  db:
    image: postgres:<TODO: version>
    env_file: .env
    volumes: ["pgdata:/var/lib/postgresql/data"]
    restart: unless-stopped
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER"], interval: 10s }

volumes: { pgdata: {} }
```

**Why the `migrate` one-shot exists**: web and worker boot from the
same image — if either ran migrations, two could race, and a deploy
whose code expects the new schema 500s until migrations land. Exactly
one process migrates, before anything starts.

## Deploy sequence

1. `docker build -t <image>:<git-sha> .` (CI green first — the pre-push
   hook and ci.yml are the gate).
2. Push the image; update the tag in compose.
3. `docker compose up -d` — migrate runs, exits 0, web+worker start.
4. Smoke: hit `/api/health`, log in to both realms, open one portal page.
5. Note the previous image tag — that is your rollback.

## Rollback

`docker compose up -d` with the previous image tag. **Caveat**: code
rolls back; migrations don't. Only additive migrations (new columns
nullable/defaulted, new tables) are safely roll-back-able — destructive
migrations on live financial data get the expand/migrate/contract
treatment and a rehearsed restore (`backup-restore.md`) as the last
resort. Rehearse a rollback once before go-live.

## Env injection

Secrets live in the host's `.env` (never in the image, never
committed). Startup fails loudly on missing required vars (Day-1
checklist item). Per-realm auth secrets are separate vars — see
`.env.example`.

## <TODO: your host specifics>

Where the VPS/PaaS lives, who has access, where DNS is, where TLS
terminates (Caddy/Traefik/PaaS), and where to look when it's down
(`incident-response.md` Scenario 4).
