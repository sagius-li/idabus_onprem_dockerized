# Repository Guidelines

## Project Structure & Module Organization

This repository is currently infrastructure-focused and centered on `docker-compose.yml`.

- `docker-compose.yml`: Defines the local stack (Elasticsearch, Kibana, Angular static hosting, DataService API, and Keycloak), networking, ports, and storage mounts.
- Bind mount `./esdata`: Persists Elasticsearch data on the host filesystem across container restarts.
- Bind mount `./keycloak/data`: Persists Keycloak identities/realm data on the host filesystem across container restarts.

If new app code is added, keep it in clear top-level folders such as `src/`, `tests/`, and `docs/` to maintain separation from deployment assets.

## Build, Test, and Development Commands

Use Docker Compose as the primary development workflow.

- `docker compose up -d`: Start the full local stack in the background.
- `docker compose ps`: Check service status and container health.
- `esdata-init` is a one-shot setup container and should normally show `Exited (0)` after applying directory permissions.
- `es-security-init` is a one-shot setup container and should normally show `Exited (0)` after setting the `kibana_system` password.
- `docker compose logs -f elasticsearch kibana`: Stream logs for troubleshooting startup/connectivity.
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
- Verify Angular UI: open `http://localhost:8080`
- Verify DataService API: open `http://localhost:8090/swagger`
- Verify Keycloak UI: open `http://localhost:8180`

When scripts or application code are introduced, add corresponding tests under `tests/` and document the command to run them here.

## Commit & Pull Request Guidelines

Git history is not available in this workspace, so adopt a clear convention now:

- Commit format: `type(scope): summary` (for example, `chore(compose): pin elastic image versions`)
- Keep commits focused on one logical change.
- PRs should include: purpose, key changes, verification steps, and any config or data-impact notes.
- Include screenshots only for UI changes (for example, Kibana dashboards).

## Security & Configuration Tips

- Do not commit secrets or credentials; use environment variables or a local `.env` file.
- `xpack.security.enabled=false` is for local development only; enable security before any shared or production deployment.
