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
| `bootstrap-rbac.yaml` / `reconcile-cronjob.yaml` | hourly: fetch depot → push images → render → apply on change |
| `reconcile-script.yaml` | the template→BattleGroup transformation, as reviewable Python |
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

# Start. The operator sets spec.stop=true once after any spec change, so a single
# patch can lose that race and leave the world stopped with no error. Always verify
# the value stuck, and re-patch if it did not.
until [ "$(kubectl -n $NS get battlegroup $BG -o jsonpath='{.spec.stop}')" = "false" ]; do
  kubectl -n $NS patch battlegroup $BG --type=merge -p '{"spec":{"stop":false}}'
  sleep 20
done

kubectl -n $NS patch battlegroup $BG --type=merge -p '{"spec":{"stop":true}}'    # stop
kubectl -n $NS get battlegroup,serverset,pods
```

Never send a `patch` with stderr redirected to `/dev/null` — an invalid patch fails
silently and looks identical to the operator overriding you.

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
- **A stale server is silently de-listed**, so the build is never pinned — the CronJob
  follows the depot, which is what Funcom's own VM does. Steam's appmanifest wedges itself
  with `StateFlags 6`, after which `app_update` reports success while doing nothing, so it
  is deleted before every run.
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

Edit `world-settings.yaml` — plain ini, one place. The render step translates each line
into an `-ini:` argument on every ServerSet; mounting the files loses to Unreal's
`Saved/Config` layer, which lives on the world PVC.

Three caveats:

- **`DifficultyLevel=Custom` is mandatory.** Without it the whole
  `UserServerCustomSettings.ini` is silently ignored. There are also community reports of
  it not applying on 1.5+, so verify a fast-feedback key (carry capacity, XP) in-game
  before trusting a large batch.
- **Nothing to bump.** The CronJob reconciles hourly, discovers the build from the depot
  and applies only when its rendered hash changes, restoring the run state afterwards.
  Force a run with `kubectl -n dune-awakening create job manual --from=cronjob/dune-reconcile`.
- **The in-game admin UI reads the engine's own file, not our overrides.** The live subset
  it manages is `server/DuneSandbox/Saved/Config/LinuxServer/ServerCustomSettings.ini`
  inside a map pod, and it keeps showing defaults for keys we set via `-ini:`. Read that
  file to learn a key's real name and shipped value; judge effect in-game, not from the UI.

## Configuration

Everything is server-side; the Director web UI does not persist changes. Three ini files in
the depot drive it — `UserEngine.ini` (ports, server password, Sietch display name, mining
and sandworm settings), `UserGame.ini` (PvP, security zones, landclaim caps) and
`UserServerCustomSettings.ini` (harvest/craft/combat multipliers, needs
`DifficultyLevel=Custom`). Apply them as `-ini:engine:[Section]:Key=Value` arguments on the
map sets, which is the mechanism Funcom itself uses for the FLS token.
