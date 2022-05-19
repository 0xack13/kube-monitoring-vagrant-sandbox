#!/bin/bash
echo "Patching etcd to expose metrics.."
sudo sed -i -e 's/\(.*listen-metrics-urls.*\)/\1,http:\/\/10.0.10.10:2381/g' /etc/kubernetes/manifests/etcd.yaml
systemctl restart kubelet
while [[ $(kubectl get pods -A -l component=etcd -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "waiting for the nodes to come up.."
   sleep 1
done
sleep 5
# etcd_container=$(sudo crictl ps 2>/dev/null | grep etcd | awk '{print $1}')
# sudo crictl stop $etcd_container && sudo crictl rm $etcd_container
kubectl expose pod -n kube-system etcd-master-node --port 2381