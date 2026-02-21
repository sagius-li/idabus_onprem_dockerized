# TODO: Fix `DefaultAzureCredential` Failure for `dataservice-api`

## Summary
Use Azure service-principal environment variables in Docker so `DefaultAzureCredential` resolves via `EnvironmentCredential` for local Kestrel hosting.

## Tasks
- [ ] Keep current prebuilt API deployment model unchanged (`./engine` mounted into `dataservice-api`).
- [ ] Keep `UseManagedIdentity: true` values in `engine/appsettings.production.json` unchanged.
- [ ] Update `docker-compose.yml` under `dataservice-api.environment` to include:
  - [ ] `AZURE_TENANT_ID=${AZURE_TENANT_ID}`
  - [ ] `AZURE_CLIENT_ID=${AZURE_CLIENT_ID}`
  - [ ] `AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}`
- [ ] Add a local `.env` file at repo root with:
  - [ ] `AZURE_TENANT_ID=...`
  - [ ] `AZURE_CLIENT_ID=...`
  - [ ] `AZURE_CLIENT_SECRET=...`
- [ ] Ensure `.env` is ignored by git (`.gitignore`).

## Validation
- [ ] Run `docker compose up -d`.
- [ ] Run `docker compose ps` and verify `dataservice-api` is `Up`.
- [ ] Check `docker compose logs dataservice-api` and confirm no `DefaultAzureCredential failed...` error.
- [ ] Open `http://localhost:8090/swagger` and run an endpoint that calls Azure resources.
- [ ] If auth still fails, verify service-principal RBAC for:
  - [ ] Cosmos DB
  - [ ] Key Vault
  - [ ] Service Bus
  - [ ] Application Insights (if applicable)

## Notes
- Host/API port mapping remains `8090:8090`.
- Secrets are intentionally kept out of `docker-compose.yml` and loaded via `.env`.
