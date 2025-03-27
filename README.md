# Test multiupath, Kubevirt, persistent reservation and failover

## Cluster setup
Until the [upstream PR](https://github.com/kubevirt/kubevirt/pull/14353) for updating the multipath libraries isn’t merged, please build KubeVirt from this branch.

## Create the cluster with 2 nodes and persistent reservation feature gate enable
```bash
export FEATURE_GATES=PersistentReservation
export KUBEVIRT_NUM_NODES=2
export KUBECONFIG=$($GOPATH/src/github.com/kubevirt/kubevirt/kubevirtci/cluster-up/kubeconfig.sh)
make cluster-down && make cluster-up && make cluster-sync
```

If kubevirt complains that the feature gate isn’t enabled (at VM creation), then:
```bash
kubectl patch kubevirt kubevirt -n kubevirt --type='json' -p='[
    {"op": "add", "path": "/spec/configuration/developerConfiguration/featureGates", "value": [
        "PersistentReservation",
    ]},
]'
```

The node01 will be used as storage node and the VM will be deployed on the node02

## Create the storage on node01

```bash
handler=$(kubectl get po -n kubevirt -l kubevirt.io=virt-handler --no-headers=true -o custom-columns=":metadata.name" --field-selector spec.nodeName=node01)
kubectl cp -n kubevirt create-storage.sh $handler:/proc/1/root/create-storage.sh
kubectl exec -ti -n kubevirt $handler -- nsenter -a -t 1 /create-storage.sh
```
## Install multipath on node02 with the multipath socket enabled

```bash
handler=$(kubectl get po -n kubevirt -l kubevirt.io=virt-handler --no-headers=true -o custom-columns=":metadata.name" --field-selector spec.nodeName=node02)
kubectl cp -n kubevirt install-multipath.sh $handler:/proc/1/root/install-multipath.sh
kubectl exec -ti -n kubevirt $handler -- nsenter -a -t 1 /install-multipath.sh
```


## Login the storage into node02
``` bash
kubectl exec -ti -n kubevirt $handler -- nsenter -a -t 1 iscsiadm --mode discovery --type sendtargets --portal 192.168.66.101 --login
```

## Log into the node
Either with `kubevirtci/cluster-up/ssh.sh node01` or execing in virt-handler:
```bash
handler=$(kubectl get po -n kubevirt -l kubevirt.io=virt-handler --no-headers=true -o custom-columns=":metadata.name" --field-selector spec.nodeName=node02)
kubectl exec -ti -n kubevirt $handler -- nsenter -a -t 1
```

Deploy the VM with persistent reservation
The password for the user `fedora` is `fedora`.
``` bash
kubectl apply -f vm.yaml
```

Log into the VM:
```bash
virtctl console vm
```
