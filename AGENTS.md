# Repository Guidelines

## Files

This repository is currently infrastructure-focused and centered on `docker-compose.yml`.

- `.env`: Holds all passwords.
- `docker-compose.yml`: Defines the local stack, networking, ports, and container/runtime wiring.
- `scripts/es-security-init.sh`: Waits for Elasticsearch and sets the `kibana_system` password.
- `scripts/es-index-init.sh`: Waits for Elasticsearch, checks required indices, and creates missing indices with configured settings/mappings.
- `scripts/sqlserver-init.sh`: Waits for SQL Server, ensures the `IdabusIdentitySolution` database, required tables, and required indexes exist.

## Containers

- `esdata-init (alpine:3.21)`: One-shot host directory initialization and permission setup for Elasticsearch data.
- `elasticsearch (docker.elastic.co/elasticsearch/elasticsearch:8.19.11)`: Elasticsearch single-node backend.
- `es-security-init (curlimages/curl:8.12.1)`: One-shot setup of the `kibana_system` password.
- `es-index-init (curlimages/curl:8.12.1)`: One-shot creation of required indices if missing (`events`, `eventsarchive`, `resources`, `workflowexecution`).
- `kibana (docker.elastic.co/kibana/kibana:8.19.11)`: Kibana UI for Elasticsearch.
- `idabus-portal (nginx:alpine)`: Static hosting for portal assets.
- `idabus-engine (mcr.microsoft.com/dotnet/aspnet:10.0)`: DataService API runtime container.
- `sqlserver (mcr.microsoft.com/mssql/server:2022-latest)`: Local Microsoft SQL Server container for development/testing.
- `sqlserver-init (mcr.microsoft.com/mssql/server:2022-latest)`: One-shot SQL bootstrap service that waits for SQL Server and ensures DB/table/index readiness.
- `keycloak (quay.io/keycloak/keycloak:26.0)`: Identity and realm/auth provider.

## Mount Settings

- `./esdata -> /esdata` in `esdata-init`: Bootstrap permissions target.
- `./esdata -> /usr/share/elasticsearch/data`: Elasticsearch persistent data.
- `./scripts -> /scripts` in `es-security-init` (read-only): Mounts init script files.
- `./scripts -> /scripts` in `es-index-init` (read-only): Mounts index bootstrap script files.
- `./scripts -> /scripts` in `sqlserver-init` (read-only): Mounts SQL bootstrap script files.
- `./sqldata -> /var/opt/mssql`: SQL Server persistent data.
- `./keycloak/data -> /opt/keycloak/data`: Keycloak persistent data.
- `./keycloak/import -> /opt/keycloak/data/import` (read-only): Realm import files.
- `./nginx/angular.conf -> /etc/nginx/conf.d/default.conf` (read-only): Nginx config.
- `./portal -> /usr/share/nginx/html` (read-only): Portal static files.
- `./engine -> /app` (read-only): DataService runtime files.

If new app code is added, keep it in clear top-level folders such as `src/`, `tests/`, and `docs/` to maintain separation from deployment assets.

## Build, Test, and Development Commands

Use Docker Compose as the primary development workflow.

- `docker compose up -d`: Start the full local stack in the background.
- `docker compose ps`: Check service status and container health.
- `docker compose up -d [service-name|...]`: Start specified services in the background.
- `docker compose logs -f [service-name|...]`: Stream logs of services for troubleshooting.
- `docker compose down`: Stop and remove containers and network.
- `docker compose down -v`: Stop everything and remove volumes (deletes local Elasticsearch data).
- `docker compose down -v --rmi all`: clean up everything (containers, images, networks, volumes), do not use this unless specifically stated.

## Coding Style & Naming Conventions

For YAML and infra files:

- Use 2-space indentation and consistent key ordering (service, image, environment, ports, volumes, networks).
- Prefer lowercase service names (`elasticsearch`, `kibana`) and descriptive volume/network names (`esdata`, `elastic`).
- Pin explicit image tags (for example, `8.19.11`) instead of `latest` to keep environments reproducible.

## Testing Guidelines

No automated test suite is defined yet in this repository. Validate changes with runtime checks:

- Start the stack: `docker compose up -d`
- Verify Elasticsearch: `curl http://localhost:9200`
- Verify Kibana UI: open `http://localhost:5601`
- Verify Keycloak UI: open `http://localhost:8180`
- Verify SQL Server port: `nc -zv localhost 1433` (or connect with a SQL client using `localhost,1433`)
- Verify IDABUS Engine: open `http://localhost:8090/swagger`
- Verify IDABUS Portal: open `http://localhost:8080`

When scripts or application code are introduced, add corresponding tests under `tests/` and document the command to run them here.

## Commit & Pull Request Guidelines

Git history is available in this repository. Follow the existing commit style for consistency.

- Commit subject style: concise lowercase phrase (for example, `added sql server bootstrap`, `updated agents.md`).
- Keep commits focused on one logical change.
- Avoid noisy WIP commit messages in shared history; squash/fixup before merge when needed.
- PRs should include: purpose, key changes, verification steps, and any config or data-impact notes.
- Include screenshots only for UI changes (for example, Kibana dashboards).

## Security & Configuration Tips

- Do not commit secrets or credentials; use environment variables or a local `.env` file.
- `xpack.security.enabled=false` is for local development only; enable security before any shared or production deployment.
