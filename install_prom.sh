#!/bin/bash
vagrant destroy -f && sleep 2 && vagrant up
export KUBECONFIG=$(pwd)/configs/config
kubectl get node -owide
sleep 3
kubectl create namespace monitoring
# install prom
cd monitoring/kubernetes-prometheus
kubectl create -f clusterRole.yaml
kubectl create -f config-map.yaml
kubectl create  -f prometheus-deployment.yaml
kubectl get deployments --namespace=monitoring
kubectl create -f prometheus-service.yaml --namespace=monitoring
cd ..
kubectl apply -f kube-state-metrics-configs/
while [[ $(kubectl get pods -A -l app=prometheus-server -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "waiting for the nodes to come up.."
   sleep 1
done
sleep 5
prom_pod=$(kubectl get pod -A -owide | awk '{print $2}' | grep prometheus)
kubectl port-forward -n monitoring $prom_pod 8080:9090 > /dev/null 2>&1 &

echo "prom URL: http://localhost:8080/"