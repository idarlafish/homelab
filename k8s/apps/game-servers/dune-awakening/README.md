# Dune: Awakening

Unlike every other game here, the Steam depot (`4754530`) is not a Linux binary — it is a
Kubernetes distribution. It ships container images, four Funcom operators, 26 CRDs, a
`BattleGroup` custom resource template and its own `k3s.sh` installer. The game binary only
exists inside Funcom's `seabass-server` image and will not start without Postgres, two
RabbitMQ brokers, a text-router, a battlegroup director, a gateway and a successful Funcom
Live Services (FLS) registration. So there is no single StatefulSet to write: we run
Funcom's own architecture on our Talos cluster instead of their nested k3s.

Funcom's content is **fetched at run time, never committed** — this repo is public and the
depot is their copyright. `bootstrap-job.yaml` downloads it, pushes the images into an
in-cluster registry, applies their CRDs and renders their world template through
`world-values.yaml` (`render-script.yaml` does the same job as their `scripts/setup/world.sh`).

## Layout

| File | Purpose |
|---|---|
| `registry.yaml` | in-cluster `registry:2` on a fixed ClusterIP, plus the depot PVC |
| `operators-rbac.yaml` / `operators.yaml` | identities and Deployments for Funcom's 4 operators |
| `bootstrap-rbac.yaml` / `bootstrap-job.yaml` | fetch depot → push images → render → apply |
| `render-script.yaml` | the template→BattleGroup transformation, as reviewable Python |
| `world-values.yaml` | **the one place to change world config** |
| `dune-awakening-secret.yaml` | SOPS: FLS token, DB passwords, server password |
| `kyverno-policy.yaml` | rewrites the hostPath Funcom hardcodes (see below) |

## Start and stop — this is the cost control

The world is created **stopped**. It is the only game here that cannot idle for free: the
node must be >= 24 GB to hold it.

```sh
export KUBECONFIG=infra/game-servers/kubeconfig
NS=funcom-seabass-sh-47951649e36d38d0-zagrib
BG=sh-47951649e36d38d0-zagrib

kubectl -n $NS patch battlegroup $BG --type=merge -p '{"spec":{"stop":false}}'   # start
kubectl -n $NS patch battlegroup $BG --type=merge -p '{"spec":{"stop":true}}'    # stop
kubectl -n $NS get battlegroup,serverset,pods
```

Survival_1 takes several minutes to load, then the in-game browser needs a few more minutes.

## Joining

Server browser → **Experimental** tab (not Private, which is for paid hosts) → search the
world title. There is no direct-IP or invite-code join, so share the name. Use the retail
client; Funcom's help pages still reference the Public Test Client and a PTC client will not
see a retail world.

## Non-obvious things that will bite you

- **The world name is not free-form.** It must be `sh-<lowercase HostId>-<suffix>`, where
  HostId comes from the FLS token's JWT payload. Anything else is rejected with
  `403 ACCESS_DENIED` on `GatewayDeclareFarmStatus`, with no hint as to why.
- **A stale server is silently de-listed.** Steam's appmanifest wedges itself with
  `StateFlags 6`, after which `app_update` reports success while doing nothing, so the
  server stays on an old build and Funcom stops listing it. The bootstrap Job deletes the
  appmanifest before every run and fails loudly if the depot build does not match
  `DUNE_SERVER_BUILD`. On a game patch: bump the build in `world-values.yaml`, the image
  tags in `operators.yaml`/the rendered CR, and the Job name, then let it re-run.
- **`/funcom/artifacts`** is a hostPath hardcoded in the server-operator with no CRD
  override. Talos' root is read-only outside `/var`, so pods die with
  `mkdir /funcom: read-only file system`. The Kyverno policy rewrites it to
  `/var/funcom/artifacts`; Kyverno is therefore a hard dependency.
- **Editing the BattleGroup auto-stops the world.** The operator sets `spec.stop=true` on
  any spec change, so every config change costs a restart plus a `stop=false` patch.
- **Memory is the binding constraint.** Survival_1 is OOM-killed at 8Gi and 9Gi; it needs
  ~11-12Gi. Overmap needs 2Gi and DeepDesert_1 wants 15Gi on demand, so the full map set
  needs a 32-40 GB node. 16 GB cannot run even Funcom's default two-map layout.
- **amd64 + AVX2 only.** ARM (Hetzner cax) is impossible — the images are single-arch.
- **Registry ClusterIP is load-bearing.** `infra/game-servers/main.tf` mirrors
  `registry.funcom.com` to `10.0.96.200:5000` in the Talos machine config. Node image pulls
  happen in containerd, which does not use cluster DNS, so it must be a pinned IP.
- **After resizing the node, restart kubelet** or it keeps advertising the old capacity:
  `talosctl --talosconfig infra/game-servers/talosconfig -n <ip> service kubelet restart`

## Changing gameplay settings

Edit `world-settings.yaml` — plain ini, one place. The render step mounts it onto every
ServerSet via `userIniConfig`, at the path Funcom's own `apply-default-usersettings` uses.

Two caveats:

- **`DifficultyLevel=Custom` is mandatory.** Without it the whole
  `UserServerCustomSettings.ini` is silently ignored. There are also community reports of
  it not applying on 1.5+, so verify a fast-feedback key (carry capacity, XP) in-game
  before trusting a large batch.
- **The bootstrap Job must be deleted to re-run.** Its name is tied to the build, so a
  settings-only change leaves the name unchanged and Kubernetes rejects the update (Jobs
  are immutable). Delete it and let Flux recreate:
  `kubectl -n dune-awakening delete job dune-bootstrap-<build>`
  This re-validates the depot and re-pushes images, which is slower than it needs to be —
  splitting fetch from render would fix it.

## Configuration

Everything is server-side; the Director web UI does not persist changes. Three ini files in
the depot drive it — `UserEngine.ini` (ports, server password, Sietch display name, mining
and sandworm settings), `UserGame.ini` (PvP, security zones, landclaim caps) and
`UserServerCustomSettings.ini` (harvest/craft/combat multipliers, needs
`DifficultyLevel=Custom`). Apply them as `-ini:engine:[Section]:Key=Value` arguments on the
map sets, which is the mechanism Funcom itself uses for the FLS token.
