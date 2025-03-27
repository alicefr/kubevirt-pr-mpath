#!/bin/bash

set -x

iqn1=iqn.2003-01.org.linux-iscsi.node01.x8664:sn.a06ca3a2277b
iqn2=iqn.2003-01.org.linux-iscsi.node01.x8664:sn.c3bbb87c7fbd

dnf install -y targetcli
mkdir -p /tmp/disks

targetcli backstores/fileio create disk1 /tmp/disks/disk.img 1G
targetcli /iscsi create $iqn1
targetcli iscsi/$iqn1/tpg1 set attribute authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1
targetcli iscsi/$iqn1/tpg1/luns create /backstores/fileio/disk1

targetcli /iscsi create $iqn2
targetcli iscsi/$iqn2/tpg1 set attribute authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1
targetcli iscsi/$iqn2/tpg1/luns create /backstores/fileio/disk1
iscsiadm --mode discovery --type sendtargets --portal 127.0.0.1 --login
lsblk --scsi

