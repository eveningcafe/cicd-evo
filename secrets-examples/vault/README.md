# HashiCorp Vault example

Pattern: **Centralized Vault** with Vault Agent Injector (Phần V §5.2.2).

Secrets live in Vault, not Git. The pod gets credentials injected by a
sidecar at startup based on a Kubernetes ServiceAccount identity. Nothing
sensitive ever touches a YAML file.

## Files

- `deployment-with-injector.yaml` — sample-app Deployment annotated for
  Vault Agent Injector. The annotations are the only Vault-specific code.
- `vault-auth-config.md` — one-time platform setup for Kubernetes auth and
  a database secret engine that issues short-lived credentials.

## Workflow

1. Platform team configures Vault once: enable the `kubernetes` auth
   method, register the cluster's JWT issuer, create a policy that allows
   reading the secret path, and bind it to a ServiceAccount.
2. Application team annotates the Deployment to request injection.
3. Vault Agent Injector mutates pods at admission time, adds a sidecar,
   and writes rendered secrets to `/vault/secrets/`.
4. The app reads from `/vault/secrets/*` like a regular file.

## Why this scales better than Sealed Secrets

- **Identity-based access**: pods authenticate as their ServiceAccount.
  No shared key to leak.
- **Dynamic secrets**: the database engine issues a fresh DB user with a
  60-minute TTL each time a pod starts.
- **Audit log**: Vault records who read what and when.
- **Auto-rotation**: the sidecar renews credentials before expiry; the app
  just re-reads the file.
- **One source of truth across environments**: same workflow for dev,
  staging, and prod — only the policy differs.

This setup is overkill for a 3-developer team. It pays off once the
platform team owns >10 services and compliance enters the picture.
See the recommendation matrix in Phần V §5.4.
