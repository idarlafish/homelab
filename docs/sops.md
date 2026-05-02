# SOPS

Use sops ≥ 3.12 (3.11 has a config-discovery bug for new files).

`.sops.yaml` at the repo root defines the age recipient and `encrypted_regex`, shared by all clusters. The matching private key lives in the `sops-age` Secret in each cluster's `flux-system` namespace (Tofu's `flux_bootstrap` injects it).

## Encrypting new files

Sops 3.12 walks up from the current working directory; `.sops.yaml` at the repo root is found automatically when invoked from any subdirectory. From the repo root:

```bash
sops --encrypt --in-place k8s/apps/<concern>/<app>/<name>-secret.yaml
```

Encrypted secrets are co-located with the app they belong to (under `k8s/apps/<concern>/<app>/`). Each Flux Kustomization that includes encrypted resources has a `decryption` block referencing the `sops-age` Secret in `flux-system`.

## Decrypting locally

Sops 3.12.2 doesn't actually auto-discover `~/.config/sops/age/keys.txt` despite the docs claiming so — `SOPS_AGE_KEY_FILE` must be set explicitly.

One-time setup, extract the age key from the cluster:

```bash
mkdir -p ~/.config/sops/age
KUBECONFIG=.kube/config kubectl get secret -n flux-system sops-age \
  -o jsonpath='{.data.age\.agekey}' | base64 -d > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

Make the env var permanent (one of):

```bash
# In ~/.zshenv (recommended; applies to all shells, including non-interactive)
echo 'export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"' >> ~/.zshenv
```

```bash
# Or in the project's gitignored .env (only when you `source .env`)
echo 'export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"' >> .env
```

## Editing existing files

Once `SOPS_AGE_KEY_FILE` is set:

```bash
sops <path-to-encrypted-file>.yaml
```

Sops reads metadata from the encrypted file itself; no `--config` flag needed for edit (only for first-time encrypt).
