# Vault setup for the sample app

One-time, owned by the platform team. Reproduced here so the
`deployment-with-injector.yaml` is not a magic incantation.

## 1. Enable Kubernetes auth

```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc.cluster.local:443"
```

## 2. Policy for the app

`sample-app.hcl`:

```hcl
path "kv/data/sample-app/*" { capabilities = ["read"] }
path "database/creds/sample-app" { capabilities = ["read"] }
```

```bash
vault policy write sample-app sample-app.hcl
```

## 3. Bind the policy to the ServiceAccount

```bash
vault write auth/kubernetes/role/sample-app \
    bound_service_account_names=sample-app \
    bound_service_account_namespaces=sample-app-prod \
    policies=sample-app \
    ttl=1h
```

## 4. Configure the database secret engine

```bash
vault secrets enable database

vault write database/config/sample-postgres \
    plugin_name=postgresql-database-plugin \
    connection_url="postgresql://{{username}}:{{password}}@db.internal:5432/sample" \
    allowed_roles=sample-app \
    username=vault_admin \
    password=...

vault write database/roles/sample-app \
    db_name=sample-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl=1h \
    max_ttl=24h
```

Every pod that starts now receives a freshly minted PostgreSQL user that
expires within 24 hours. The platform team never hands out a static DB
password; the application team never writes a secret into Git.

## 5. KV v2 for static secrets

```bash
vault secrets enable -path=kv -version=2 kv
vault kv put kv/sample-app/api key=real-api-key
```

## Result

The application Deployment in `deployment-with-injector.yaml` references
`database/creds/sample-app` and `kv/data/sample-app/api`. Vault Agent
Injector handles the rest at pod admission. Compare this against
`../sealed-secrets/README.md` — the runtime story is identical, but
auditability, rotation, and onboarding cost are different orders of
magnitude.
