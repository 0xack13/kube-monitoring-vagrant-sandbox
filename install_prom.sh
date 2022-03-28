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