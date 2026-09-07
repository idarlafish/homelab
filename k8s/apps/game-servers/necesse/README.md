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

Driven by a **public** Steam Workshop collection — curate it in Steam and the server follows.
No Steam account needed; Workshop downloads for Necesse work with anonymous steamcmd.

```yaml
WORKSHOP_COLLECTION: "3797557934"
WORKSHOP_IDS: ""
```

Three initContainers: `resolve-mods` expands the collection via the Steam API, `fetch-mods`
downloads each item, `filter-mods` reads `clientside` from every jar's `mod.info` and installs
only server-side mods into `/necesse/mods`, clearing it first so removals take effect. Retexture
packs are dropped automatically — nothing to maintain by hand.

The collection must be Public — the API does not serve unlisted items, and `resolve-mods` fails
rather than silently starting a mod-less server. Necesse requires exact mod parity between
server and client, so refetching each start keeps the server on the versions Workshop pushes
to clients.

## Storage

One PVC mounted three times by `subPath` (`saves`, `logs`, `cfg`). `cfg` holds bans and permissions,
so it has to survive restarts.

## Start / stop

Same as the other games — edit `replicas` in `statefulset.yaml`, commit, push. See
[minecraft/README.md](../minecraft/README.md#pause--resume).
