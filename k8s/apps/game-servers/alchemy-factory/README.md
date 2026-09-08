# Alchemy Factory Server

Windows-only dedicated server run under Proton via
[idarlafish/alchemy-factory-server](https://github.com/idarlafish/alchemy-factory-server).

Players join with the **join code** from the logs, not an IP:

```bash
KUBECONFIG=infra/game-servers/kubeconfig kubectl exec -n alchemy-factory alchemy-factory-0 -- \
  grep -oE 'join code: [A-Z0-9]+' /data/server/AlchemyFactory/Saved/Logs/AlchemyFactory.log | tail -1
```

`SERVER_RELAY: "1"` routes traffic through Steam, so the NodePort and its Hetzner firewall
rule are unused. Set it to `0` for direct `IP:30015` joins.

Admin in-game: `/admin <adminPassword>` in chat, then `/help`.

## Notes

- amd64 only — the server binary is Windows x86-64 under Proton.
- The whole install lives on the PVC at `/data/server`, so restarts don't re-download it.
- No RCON or query protocol exists; backups are crash-consistent unless the pod is stopped.
