# Sealed Secrets example

Pattern: **Encrypted-in-Git** (Phần V §5.2.1).

The secret material is encrypted on a developer laptop with the cluster's
public key, committed to Git, and decrypted by a controller running inside
the cluster.

## Files

- `raw-secret-example.yaml` — what the secret looks like *before* encryption.
  Never commit a file like this.
- `sealed-secret-example.yaml` — what `kubeseal` produces. Safe to commit;
  only the in-cluster controller can read it.

## Workflow

```bash
# One-time: install the controller in the cluster.
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.0/controller.yaml

# Encrypt a Secret into a SealedSecret.
kubeseal --controller-namespace=kube-system \
         --format yaml \
         < raw-secret-example.yaml \
         > sealed-secret-example.yaml

# Commit the sealed file. The plaintext file never leaves the laptop.
git add sealed-secret-example.yaml
```

## Operational cost (Phần V §5.3)

- New developers need 30 minutes to install `kubeseal`, fetch the cluster
  cert, and learn the workflow.
- Each environment needs its own controller key. Re-sealing across three
  environments means running `kubeseal` three times.
- Losing the controller's private key means losing every sealed secret in
  the cluster.
- No "who read this secret" audit trail.
- No dynamic credentials, no auto-rotation.

When these costs start to bite, move to Vault — see `../vault/`.
