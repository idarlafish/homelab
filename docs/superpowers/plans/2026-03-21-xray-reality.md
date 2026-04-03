# Xray VLESS-Reality Deployment Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a VLESS-Reality (xray-core) pod in the existing `vpn` namespace with `hostNetwork: true` on port 443 for censorship-resistant proxy access.

**Architecture:** A single-replica Deployment using `ghcr.io/xtls/xray-core:latest` with hostNetwork mode. Config is split between a ConfigMap (non-sensitive template) and a SOPS-encrypted Secret (UUID, x25519 private key, shortId). The entrypoint uses `sed` to substitute secret placeholders into the config before starting xray.

**Tech Stack:** Kubernetes (k3s), Kustomize, SOPS (age encryption), Xray-core (VLESS + TCP + XTLS-Vision + Reality)

---

### Task 1: Generate Xray keys

**Files:** None (output values used in Task 2)

These commands must be run when Docker is available (or on the server):

- [ ] **Step 1: Generate UUID**

```bash
docker run --rm ghcr.io/xtls/xray-core:latest uuid
```

Save the output as `XRAY_UUID`.

- [ ] **Step 2: Generate x25519 keypair**

```bash
docker run --rm ghcr.io/xtls/xray-core:latest x25519
```

Save the `Private key` line as `XRAY_PRIVATE_KEY` and the `Public key` line — you'll need the public key for Happ client configuration.

- [ ] **Step 3: Generate shortId**

```bash
openssl rand -hex 8
```

Save the output as `XRAY_SHORT_ID`.

---

### Task 2: Create SOPS-encrypted Secret

**Files:**
- Create: `k8s/secrets/vpn-xray-reality-secrets.yaml`
- Modify: `k8s/secrets/kustomization.yaml`

- [ ] **Step 1: Create the plaintext Secret manifest**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: xray-reality-secrets
  namespace: vpn
type: Opaque
stringData:
  uuid: "<XRAY_UUID from Task 1>"
  private-key: "<XRAY_PRIVATE_KEY from Task 1>"
  short-id: "<XRAY_SHORT_ID from Task 1>"
```

- [ ] **Step 2: Encrypt with SOPS**

```bash
cd k8s/secrets && sops --encrypt --in-place vpn-xray-reality-secrets.yaml
```

- [ ] **Step 3: Add to secrets kustomization**

Add `vpn-xray-reality-secrets.yaml` to the resources list in `k8s/secrets/kustomization.yaml`.

- [ ] **Step 4: Commit**

```bash
git add k8s/secrets/vpn-xray-reality-secrets.yaml k8s/secrets/kustomization.yaml
git commit -m "add SOPS-encrypted xray-reality secrets"
```

---

### Task 3: Create ConfigMap with Xray config template

**Files:**
- Create: `k8s/vpn/xray-reality/configmap.yaml`

The config uses placeholder strings that get replaced by `sed` at pod startup with values from the Secret.

- [ ] **Step 1: Create ConfigMap**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: xray-reality-config
  namespace: vpn
data:
  config.json: |
    {
      "log": {
        "loglevel": "warning"
      },
      "inbounds": [
        {
          "listen": "0.0.0.0",
          "port": 443,
          "protocol": "vless",
          "settings": {
            "clients": [
              {
                "id": "XRAY_UUID_PLACEHOLDER",
                "flow": "xtls-rprx-vision"
              }
            ],
            "decryption": "none"
          },
          "streamSettings": {
            "network": "tcp",
            "security": "reality",
            "realitySettings": {
              "show": false,
              "dest": "www.samsung.com:443",
              "serverNames": [
                "www.samsung.com",
                "samsung.com"
              ],
              "privateKey": "XRAY_PRIVATE_KEY_PLACEHOLDER",
              "shortIds": [
                "XRAY_SHORT_ID_PLACEHOLDER"
              ],
              "maxTimeDiff": 0
            }
          },
          "sniffing": {
            "enabled": true,
            "destOverride": [
              "http",
              "tls",
              "quic"
            ]
          }
        }
      ],
      "outbounds": [
        {
          "protocol": "freedom",
          "tag": "direct"
        },
        {
          "protocol": "blackhole",
          "tag": "block"
        }
      ]
    }
```

- [ ] **Step 2: Commit**

```bash
git add k8s/vpn/xray-reality/configmap.yaml
git commit -m "add xray-reality config template"
```

---

### Task 4: Create Deployment

**Files:**
- Create: `k8s/vpn/xray-reality/deployment.yaml`

- [ ] **Step 1: Create Deployment manifest**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xray-reality
  namespace: vpn
spec:
  replicas: 1
  revisionHistoryLimit: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: xray-reality
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: xray-reality
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: xray
          image: ghcr.io/xtls/xray-core:latest
          command: ["/bin/sh", "-c"]
          args:
            - |
              sed -e "s|XRAY_UUID_PLACEHOLDER|$XRAY_UUID|g" \
                  -e "s|XRAY_PRIVATE_KEY_PLACEHOLDER|$XRAY_PRIVATE_KEY|g" \
                  -e "s|XRAY_SHORT_ID_PLACEHOLDER|$XRAY_SHORT_ID|g" \
                  /etc/xray/config.template.json > /tmp/config.json
              exec xray run -config /tmp/config.json
          env:
            - name: XRAY_UUID
              valueFrom:
                secretKeyRef:
                  name: xray-reality-secrets
                  key: uuid
            - name: XRAY_PRIVATE_KEY
              valueFrom:
                secretKeyRef:
                  name: xray-reality-secrets
                  key: private-key
            - name: XRAY_SHORT_ID
              valueFrom:
                secretKeyRef:
                  name: xray-reality-secrets
                  key: short-id
          ports:
            - containerPort: 443
              name: vless
              protocol: TCP
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
          livenessProbe:
            tcpSocket:
              port: vless
            periodSeconds: 10
            failureThreshold: 3
            timeoutSeconds: 1
          readinessProbe:
            tcpSocket:
              port: vless
            periodSeconds: 10
            failureThreshold: 3
            timeoutSeconds: 1
          startupProbe:
            tcpSocket:
              port: vless
            periodSeconds: 5
            failureThreshold: 30
            timeoutSeconds: 1
          securityContext:
            capabilities:
              add:
                - NET_BIND_SERVICE
          volumeMounts:
            - name: config
              mountPath: /etc/xray/config.template.json
              subPath: config.json
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: xray-reality-config
```

- [ ] **Step 2: Commit**

```bash
git add k8s/vpn/xray-reality/deployment.yaml
git commit -m "add xray-reality deployment with hostNetwork"
```

---

### Task 5: Create Kustomization and wire everything up

**Files:**
- Create: `k8s/vpn/xray-reality/kustomization.yaml`
- Modify: `k8s/vpn/kustomization.yaml`

- [ ] **Step 1: Create xray-reality kustomization**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - configmap.yaml
  - deployment.yaml
```

- [ ] **Step 2: Add xray-reality to vpn kustomization**

Add `- xray-reality` to the resources list in `k8s/vpn/kustomization.yaml`.

- [ ] **Step 3: Commit**

```bash
git add k8s/vpn/xray-reality/kustomization.yaml k8s/vpn/kustomization.yaml
git commit -m "wire xray-reality into vpn kustomize"
```

---

### Task 6: Deploy and verify

- [ ] **Step 1: Apply secrets**

```bash
cd k8s/secrets && sops --decrypt vpn-xray-reality-secrets.yaml | kubectl apply -f -
```

- [ ] **Step 2: Apply manifests**

```bash
kubectl apply -k k8s/vpn/
```

- [ ] **Step 3: Verify pod is running**

```bash
kubectl -n vpn get pods -l app.kubernetes.io/name=xray-reality
```

Expected: `Running`, `1/1 READY`

- [ ] **Step 4: Verify port 443 is listening**

```bash
kubectl -n vpn exec deploy/xray-reality -- ss -tlnp | grep 443
```

Or from outside: `curl -sI https://<server-ip>:443` should get a TLS handshake (will fail cert validation since Reality proxies to samsung.com — that's expected).

- [ ] **Step 5: Print client config for Happ**

The user needs these values to configure their Happ client:
- **Address:** `<TOOLS_SERVER_IP>`
- **Port:** `443`
- **Protocol:** `vless`
- **UUID:** (from Task 1)
- **Flow:** `xtls-rprx-vision`
- **Security:** `reality`
- **SNI:** `www.samsung.com`
- **Fingerprint:** `chrome`
- **Public Key:** (from Task 1 x25519 output)
- **Short ID:** (from Task 1)
