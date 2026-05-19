# Secret management in a GitOps repository

Companion to Phần V of the research README. Concrete comparison of the
two examples in `secrets-examples/`.

## The fundamental tension

GitOps wants everything in Git. Secrets want to stay out of Git. The two
families of solution resolve the tension in opposite directions:

| Family | Where the secret lives | Git contains |
|---|---|---|
| Encrypted-in-Git (Sealed Secrets) | In Git, ciphertext | The encrypted blob |
| Centralized Vault (HashiCorp Vault) | Outside Git | A reference + policy |

Neither approach puts plaintext in Git, ever.

## Choosing between them

The recommendation matrix from Phần V §5.4, restated with the bias
explained:

| Situation | Pick | Why |
|---|---|---|
| 1-10 dev, no platform team | Sealed Secrets | One controller, no extra infra |
| 10+ services, platform team exists | Vault | Audit + rotation pay off |
| Compliance audits expected | Vault | Sealed Secrets has no read audit |
| Need short-lived DB credentials | Vault | Dynamic secrets engine |
| Air-gapped, no platform capacity | Sealed Secrets | Simpler day-2 ops |

The "right" choice depends on operational maturity, not on which tool is
"better". Vault is more powerful and more expensive to run.

## Daily friction

A new developer joining a Sealed Secrets project needs to:

1. Install `kubeseal`.
2. Fetch each environment's cert.
3. Learn the three-environment encryption dance.
4. Hope nobody loses a controller key.

A new developer joining a Vault project needs to:

1. Get added to the Vault policy for the app.
2. ...that's it. Pods authenticate as their ServiceAccount; the app reads
   from `/vault/secrets/`.

The trade-off: the platform team had to set Vault up in step 0. If you do
not have a platform team, that "step 0" never happens, and Sealed Secrets
is the realistic choice.

## What never changes

Five rules that hold regardless of which tool you pick:

1. Plaintext never lands in Git. Not even temporarily.
2. Each environment has its own secret material.
3. Rotation is automated, not a calendar reminder.
4. Read access is auditable, or you treat read access as compromised.
5. Losing the key material is a recoverable event you have practiced.
