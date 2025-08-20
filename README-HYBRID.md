# EKS Hybrid Node in a Separate VPC (Peered)

This adjusts your project to place the Hybrid Node EC2 in a **different VPC** (simulating on‑prem) and peers it with the EKS cluster VPC.

## What changed

- New **Hybrid VPC** (`172.16.0.0/16`) with public subnets.
- **VPC Peering** between Cluster VPC and Hybrid VPC, with routes in both directions.
- **Best‑effort** enabler for `remoteNetworkConfig` (required by Hybrid Nodes). If your AWS CLI is too old, follow the hint printed during `terraform apply`.
- EC2 user‑data now bootstraps `nodeadm`, `containerd`, and SSM registration using the Activation created by Terraform.

## Apply

```bash
terraform init
terraform apply -auto-approve
```

> If `nodeadm init` fails the first time with:
> `eks cluster does not have remoteNetworkConfig enabled`,
> make sure your AWS CLI is v2.17+ and run:

```bash
aws eks update-cluster-config   --region $AWS_REGION   --name   $CLUSTER_NAME   --remote-network-config '{"remoteNodeNetwork":{}}'
```

Then on the EC2, run:

```bash
sudo nodeadm init --config-source file:///etc/nodeadm/nodeConfig.yaml
```

## Install CNI (Cilium) after the node appears

On your workstation (where `kubectl` talks to the cluster):

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
helm upgrade --install cilium cilium/cilium   --namespace kube-system   --version 1.15.6   --set tunnel=geneve
```

> Hybrid Nodes **don’t** use VPC CNI. You need a CNI (Cilium/Calico) that supports remote/hybrid networking so the Pods on the Hybrid Node get connectivity.

## Verify

```bash
# Should show the managed instance too
aws ssm describe-instance-information   --query 'InstanceInformationList[].[InstanceId,ResourceType,PingStatus]'   --output table

# When nodeadm succeeds and CNI is installed:
kubectl get nodes -o wide
```