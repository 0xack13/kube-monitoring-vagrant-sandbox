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

# kube-state-metrics and prometheus port-forward
kubectl apply -f kube-state-metrics-configs/
while [[ $(kubectl get pods -A -l app=prometheus-server -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "prometheus: waiting for the nodes to come up.."
   sleep 1
done
sleep 5
prom_pod=$(kubectl get pod -A -owide | awk '{print $2}' | grep prometheus)
kubectl port-forward -n monitoring $prom_pod 8080:9090 > /dev/null 2>&1 &

# grafana
kubectl apply -f kubernetes-grafana/
while [[ $(kubectl get pods -A -l app=grafana -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "grafana: waiting for the nodes to come up.."
   sleep 1
done
sleep 5
grafana_pod=$(kubectl get pod -A -owide | awk '{print $2}' | grep grafana)
kubectl port-forward -n monitoring $grafana_pod 3000:3000 > /dev/null 2>&1 &

echo "Installation completed"
echo "======================================="
echo "prometheus URL: http://localhost:8080/"
echo "grafana URL:    http://localhost:3000/"