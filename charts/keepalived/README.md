# Keepalived Helm Chart

![Version: 0.1.1](https://img.shields.io/badge/Version-0.1.1-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 2.4.3](https://img.shields.io/badge/AppVersion-2.4.3-informational?style=flat-square)

[Keepalived](https://www.keepalived.org/) runs VRRP on the host network of selected nodes so that one of them holds one or more floating IPs. If that node fails, or its health check fails, another node takes the IPs over within a few seconds.

The nodes elect the master among themselves over VRRP. Nothing in the request path talks to the Kubernetes API, so the floating IPs keep working while the control plane is down. That is the difference from lease-based announcers such as MetalLB L2, kube-vip or Cilium L2 announcements, which stop answering ARP when they can no longer renew their Kubernetes lease.

A typical use is a bare-metal cluster whose router can't do BGP: keepalived attracts the traffic for a LoadBalancer IP to one healthy node, and the CNI (for example Cilium with kube-proxy replacement) serves that IP from there.

## Features

- Host-network `DaemonSet` running the [osixia/keepalived](https://github.com/osixia/docker-keepalived) image, with a chart-rendered `keepalived.conf` (VRRP only, no IPVS)
- Interface detected per node from the IPv4 default route, so nodes with different NIC names work with one configuration
- Unicast VRRP: list every node IP in `vrrp.peers` and each pod drops its own; multicast when the list is empty
- Optional `vrrp_script` health check: a node that fails it releases the floating IPs
- `nopreempt` by default, so a recovering node doesn't move the IPs back
- No Kubernetes API access: the service account token isn't mounted
- Every resource gated by `enabled`

## Prerequisites

- Kubernetes 1.19+, Helm 3.0+
- Nodes on the same L2 segment as the floating IPs
- Pods allowed to use `hostNetwork` and the `NET_ADMIN`, `NET_RAW` and `NET_BROADCAST` capabilities (Pod Security level `privileged` on the namespace)
- Whatever should answer on the floating IPs must accept traffic addressed to them on every candidate node. With Cilium, use a `LoadBalancer` Service whose IP is the floating IP, and don't let another announcer (Cilium L2 announcements, MetalLB) advertise the same IP.

## Installation

```bash
helm repo add geekxflood https://geekxflood.github.io/helm-charts
helm repo update
helm install keepalived geekxflood/keepalived \
  --namespace keepalived --create-namespace \
  --set enabled=true \
  --set 'vrrp.virtualIPs[0]=192.0.2.10/24' \
  --set 'vrrp.peers={192.0.2.21,192.0.2.22}' \
  --set-string 'nodeSelector.node-role\.kubernetes\.io/worker=true'
```

## Failover behaviour

- Every node starts in `BACKUP`. The node with the highest priority (then the highest IP) becomes `MASTER` and adds the floating IPs to its interface, then sends gratuitous ARPs.
- The master advertises every `vrrp.advertInterval` seconds. After about three missed advertisements a backup takes over.
- When `healthCheck.enabled=true`, a node whose script fails `fall` times in a row enters `FAULT` and gives the IPs up.
- On `SIGTERM` (rolling update, drain) keepalived removes the IPs before exiting, so the next node takes over right away.

Find the current master:

```bash
kubectl -n keepalived logs -l app.kubernetes.io/name=keepalived --prefix | grep -E "Entering (MASTER|BACKUP|FAULT) STATE"
```

## Health check example

With Cilium Gateway API as the data path, check the local `cilium-envoy`, which serves the Gateway listeners:

```yaml
healthCheck:
  enabled: true
  script: |
    wget -q -T 2 -O /dev/null http://127.0.0.1:9878/healthz
  interval: 3
  timeout: 4
  fall: 3
  rise: 2
```

Keep `timeout` above the script's own worst case and `interval` at or above `timeout`, otherwise keepalived logs "Track script ... is already running" and counts the overruns as failures.

Don't track the Cilium **agent** `/healthz` (port 9879):

- Cilium counts every address on its devices as a node address. When keepalived adds a floating IP, the agent regenerates the BPF programs of every endpoint on that node. While it does, its health endpoint can stall for minutes, although the eBPF datapath keeps forwarding. Tracking it makes the IP bounce between nodes, and each move triggers a new regeneration on the receiving node.
- Without the `require-k8s-connectivity: false` header, the agent health also fails when the Kubernetes API is unreachable, which defeats the point of an API-independent floating IP.

## Configuration

| Key | Default | Description |
| --- | ------- | ----------- |
| `enabled` | `false` | Render the chart's resources |
| `image.registry` | `docker.io` | Image registry |
| `image.repository` | `osixia/keepalived` | Image repository |
| `image.tag` | `""` | Image tag, defaults to `appVersion` |
| `image.digest` | `""` | Pin the image by digest; wins over `tag` |
| `vrrp.virtualIPs` | `[]` | Floating IPs in CIDR form (required) |
| `vrrp.interface` | `""` | VRRP interface; empty = interface of the default route |
| `vrrp.peers` | `[]` | IPs of all participating nodes for unicast VRRP; empty = multicast |
| `vrrp.virtualRouterId` | `51` | VRRP router ID, unique on the L2 segment |
| `vrrp.priority` | `100` | Node priority |
| `vrrp.advertInterval` | `1` | Seconds between advertisements |
| `vrrp.nopreempt` | `true` | Don't take the IPs back when a node recovers |
| `vrrp.garpMasterRefresh` | `60` | Seconds between repeated gratuitous ARPs (0 = off) |
| `healthCheck.enabled` | `false` | Track a health script |
| `healthCheck.script` | `""` | Shell commands; exit 0 = healthy |
| `healthCheck.interval` / `timeout` / `fall` / `rise` | `2` / `3` / `2` / `2` | `vrrp_script` timing |
| `extraGlobalDefs` | `""` | Extra lines for `global_defs` |
| `extraArgs` | `[]` | Extra keepalived arguments |
| `securityContext` | `NET_ADMIN`, `NET_RAW`, `NET_BROADCAST` | Container security context |
| `priorityClassName` | `system-node-critical` | Pod priority class |
| `nodeSelector` / `affinity` / `tolerations` | `{}` / `{}` / `[]` | Which nodes take part |
