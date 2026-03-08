# MetalLB Setup for Bare-Metal Kubernetes (Layer 2 Mode) 🚀

![MetalLB](https://img.shields.io/badge/MetalLB-Layer2-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Bare--Metal-blue?logo=kubernetes&logoColor=white)

This guide explains how to install **MetalLB** on a bare-metal Kubernetes cluster and configure it in **Layer 2 mode**.

It is written for learning and lab environments, but the structure is also clean enough for GitHub and future production refinement.

---

Inside the repo, store MetalLB manifests in a dedicated folder:

```text
metallb-config/
```

That keeps all MetalLB YAML files grouped in one place and makes the repo easier to navigate.

---

## Project Structure

```text
kubernetes-metallb-l2-setup/
├── README.md
└── metallb-config/
    ├── ipaddresspool.yaml
    └── l2advertisement.yaml
```

---

## What MetalLB Does

In cloud Kubernetes, a Service of type `LoadBalancer` usually gets an external IP from the cloud provider.

In a **bare-metal cluster**, Kubernetes does not provide that automatically. MetalLB fills that gap by assigning an IP address from a pool you define and advertising that IP on your network.

This allows services like Traefik, NGINX Ingress, or your own applications to be reachable through a real LAN IP.

---

## Why Use Layer 2 Mode

MetalLB supports multiple announcement methods. For learning and most home-lab setups, **Layer 2 mode** is the best place to start because:

- simpler than BGP
- no router peering required
- easy to test on a normal LAN
- works well for small and medium bare-metal clusters

In Layer 2 mode, one eligible node answers ARP requests for the service IP and attracts the traffic for that IP.

---

## Before You Start

Make sure:

- your Kubernetes cluster is healthy
- your nodes are in `Ready` state
- your CNI is already installed
- you have a few **unused IP addresses** from your LAN
- those IPs are **outside DHCP scope** or permanently reserved

Check cluster status:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Check your node subnet:

```bash
ip addr
ip route
```

---

## Example Network

Example:

- subnet: `10.70.16.0/24`
- gateway: `10.70.16.1`
- master: `10.70.16.27`
- worker: `10.70.16.28`

Example free IP range for MetalLB:

```text
10.70.16.53-10.70.16.55
```

> Important: only use IPs that are not already assigned to another device and are not handed out by DHCP.

---

## 1. Install MetalLB

Install MetalLB in native mode:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml
```

### Why this step?

This creates the MetalLB components in your cluster, including:

- **controller**: assigns IPs from the configured pool to `LoadBalancer` services
- **speaker**: announces the assigned IPs on your network

Verify installation:

```bash
kubectl get pods -n metallb-system
kubectl get all -n metallb-system
```

Wait until all MetalLB pods are `Running`.

---

## 2. Create the IP Address Pool

Create this file:

**`metallb-config/ipaddresspool.yaml`**

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lan-pool
  namespace: metallb-system
spec:
  addresses:
    - 10.70.57.53-10.70.57.55
  autoAssign: true
  avoidBuggyIPs: true
```

### Why this file is needed

`IPAddressPool` tells MetalLB which IP addresses it is allowed to assign.

### Field explanation

- `name`: logical name of the pool
- `namespace`: MetalLB resources live in `metallb-system`
- `addresses`: the IP range MetalLB can use
- `autoAssign: true`: allows automatic assignment to `LoadBalancer` services
- `avoidBuggyIPs: true`: avoids problematic addresses on some networks

Apply it:

```bash
kubectl apply -f metallb-config/ipaddresspool.yaml
```

Verify it:

```bash
kubectl get ipaddresspools -n metallb-system
kubectl describe ipaddresspool lan-pool -n metallb-system
```

---

## 3. Create the L2 Advertisement

Create this file:

**`metallb-config/l2advertisement.yaml`**

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
    - lan-pool
```

### Why this file is needed

Creating only the IP pool is not enough.

`L2Advertisement` tells MetalLB **how to announce those IPs** on the network. In Layer 2 mode, MetalLB uses ARP to advertise the service IP from one selected node.

Apply it:

```bash
kubectl apply -f metallb-config/l2advertisement.yaml
```

Verify it:

```bash
kubectl get l2advertisements -n metallb-system
kubectl describe l2advertisement lan-advertisement -n metallb-system
```

---

## Optional: Restrict Advertisement to a Specific Interface

If your nodes have multiple network interfaces, you may want to advertise only on one interface.

Example:

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
    - lan-pool
  interfaces:
    - ens34
```

Use this only if you clearly know which NIC should announce the IP.

For many labs, the simpler version without `interfaces` is easier and safer to start with.

---

## 4. Validate the Configuration

Check both resources:

```bash
kubectl get ipaddresspools,l2advertisements -n metallb-system
```

You should see:

- one `IPAddressPool`
- one `L2Advertisement`

Also confirm MetalLB is healthy:

```bash
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l component=controller --tail=100
kubectl logs -n metallb-system -l component=speaker --tail=100
```

---

## 5. Test MetalLB with a LoadBalancer Service

After MetalLB is installed and configured, any Kubernetes Service with:

```yaml
type: LoadBalancer
```

can receive an external IP from the pool.

Example verification command:

```bash
kubectl get svc -A
```

When MetalLB is working, you should see an `EXTERNAL-IP` assigned from your configured range.

Example:

```text
NAME        TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)
traefik     LoadBalancer   10.30.10.120    10.70.57.53    80:xxxxx/TCP,443:xxxxx/TCP
```

---

## 6. Best Practices

### Keep manifests separate
Use separate YAML files for:

- `ipaddresspool.yaml`
- `l2advertisement.yaml`

This makes changes easier and cleaner in Git.

### Keep IPs outside DHCP
Always reserve your MetalLB IP range and make sure your router never hands out those IPs.

### Use clear names
Prefer names like:

- `lan-pool`
- `lan-advertisement`

instead of vague or overly generic names.

### Start simple
For labs, avoid advanced options until the basic flow works.

### Commit config to Git
Store all manifests in a clean folder like:

```text
metallb-config/
```

This makes your repo reusable and easier to document.

---

## Troubleshooting

### MetalLB pods are not running

```bash
kubectl get pods -n metallb-system
kubectl describe pods -n metallb-system
```

### No external IP is assigned

```bash
kubectl describe svc <service-name>
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

### IP is assigned but not reachable

Check:

- the IP is free on your LAN
- the service really uses `type: LoadBalancer`
- no firewall is blocking traffic
- the selected node can reach your LAN
- DHCP is not conflicting with the MetalLB pool

### Inspect MetalLB logs

```bash
kubectl logs -n metallb-system -l component=controller --tail=100
kubectl logs -n metallb-system -l component=speaker --tail=100
```

---

## Useful Commands

```bash
kubectl get all -n metallb-system
kubectl get ipaddresspools,l2advertisements -n metallb-system
kubectl describe ipaddresspool lan-pool -n metallb-system
kubectl describe l2advertisement lan-advertisement -n metallb-system
kubectl get svc -A
kubectl get events -A --sort-by=.lastTimestamp | tail -n 50
```

---

## Final Recommended Files

### `metallb-config/ipaddresspool.yaml`

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lan-pool
  namespace: metallb-system
spec:
  addresses:
    - 10.70.57.53-10.70.57.55
  autoAssign: true
  avoidBuggyIPs: true
```

### `metallb-config/l2advertisement.yaml`

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
    - lan-pool
```
---

## References

This documentation is based on the official MetalLB documentation for installation, Layer 2 configuration, advanced L2 options, and service behavior.
