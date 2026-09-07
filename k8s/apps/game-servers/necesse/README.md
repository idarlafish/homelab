# Necesse Server

[BrammyS/necesse-docker-server](https://github.com/BrammyS/necesse-docker-server) on the `game-servers` cluster.

**Connect to `<node-ip>:30159`, not the default `:14159`.** The server binds 14159 in-container and the
image's entrypoint has no `-port` flag; NodePort must be in the 30000+ range and `hostNetwork` is blocked
by the enforced PodSecurity baseline. Necesse's join dialog accepts `address:port`.

Node IP: `tofu -chdir=infra/game-servers output server_ip`.

## Admin

No RCON and no Steam query protocol — the only console is the server process's stdin, which isn't
reachable without `stdin: true` on the pod. In-game admin comes from `OWNER` in `configmap.yaml`
(currently `Echo`); use `/players`, `/kick` etc. in chat.

## Mods

Steam Workshop mods download anonymously — no Steam account needed. Add space-separated
workshop IDs to `WORKSHOP_IDS` in `configmap.yaml`, commit, restart the pod:

```yaml
WORKSHOP_IDS: "3617102992 2849573426"
```

The `fetch-mods` initContainer clears `/necesse/mods` and re-downloads on every pod start, so
the server tracks the same mod versions Workshop auto-updates on clients — Necesse requires
exact parity to connect. Removing an ID removes the mod.

## Storage

One PVC mounted three times by `subPath` (`saves`, `logs`, `cfg`). `cfg` holds bans and permissions,
so it has to survive restarts.

## Start / stop

Same as the other games — edit `replicas` in `statefulset.yaml`, commit, push. See
[minecraft/README.md](../minecraft/README.md#pause--resume).
