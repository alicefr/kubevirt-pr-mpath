# Test multiupath, Kubevirt, persistent reservation and failover

## Cluster setup
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

# Check the VM behavior during the multipath failover

Write on the disk from inside the guest:
```
dd if=/dev/urandom of=/dev/sda oflag=direct
```
On the node where the VM is running, identify the active device and set it offline:
```
[root@node02 ~]# multipath -ll
$ mpatha (36001405ebbdd420c71e4f258347dfd98) dm-0 LIO-ORG,disk1
size=1.0G features='0' hwhandler='1 alua' wp=rw
|-+- policy='service-time 0' prio=50 status=active
| `- 6:0:0:0 sda 8:0  active ready running
`-+- policy='service-time 0' prio=50 status=enabled
  `- 7:0:0:0 sdb 8:16 active ready running
$  echo offline > /sys/block/sda/device/state
```

The VM will go on `Paused` state, but it should recover and be in running after around 30s.
```bash
$ kubectl get vm
NAME   AGE   STATUS   READY
vm     14m   Paused   False
[after 30s]
$ kubectl get vm
NAME   AGE   STATUS    READY
vm     14m   Running   True
```

You should also be able to see the IO error in the events:
```bash
$ kubectl get events
LAST SEEN   TYPE      REASON                    OBJECT                               MESSAGE
10m         Normal    Created                   virtualmachineinstance/vm            VirtualMachineInstance defined.
10m         Normal    Started                   virtualmachineinstance/vm            VirtualMachineInstance started.
8s          Warning   IOerror                   virtualmachineinstance/vm            VM Paused due to IO error at the volume: scsidisk
```
