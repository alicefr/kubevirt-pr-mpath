#!/bin/bash -x

curl -o /etc/multipath.conf https://raw.githubusercontent.com/kubevirt/kubevirt/refs/heads/main/cmd/pr-helper/multipath.conf
dnf install -y device-mapper-multipath
systemctl enable multipathd.socket && systemctl start multipathd.socket

