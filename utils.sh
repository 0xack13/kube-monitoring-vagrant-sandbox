#! /bin/bash

# Variable Declaration
KUBERNETES_VERSION="1.23.3-00"

disable_swap() {
    # disable swap 
    sudo swapoff -a
    # persist swapoff
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
}

load_netfiltermodule() {
    # load moudle explicitly
    sudo modprobe br_netfilter
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    sudo sysctl --system
}

use_containerd_as_cri_runtime() {
    cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    # Setup required sysctl params, these persist across reboots.
    cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

    # Apply sysctl params without reboot
    sudo sysctl --system
}

install_apt_essential_packages() {
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl
}

install_docker_containerd_engine() {
    # Apply sysctl params without reboot
    sudo sysctl --system
    #Clean Install Docker Engine on Ubuntu
    sudo apt-get remove docker docker-engine docker.io containerd runc
    sudo apt-get update -y
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    #Add Docker’s official GPG key:
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    #set up the stable repository
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    #Install Docker Engine
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
}

configure_containerd() {

    #Configure containerd
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml

    #restart containerd
    sudo systemctl restart containerd

    echo "ContainerD Runtime Configured Successfully"
}

# needed to add kuberentes repo
download_google_public_signing() {
    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
}

add_kube_apt_repo() {
    #Add Kubernetes apt repository
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
}

install_kube_tools() {
    sudo apt-get update -y
    sudo apt-get install -y kubelet=${KUBERNETES_VERSION} kubectl=${KUBERNETES_VERSION} kubeadm=${KUBERNETES_VERSION}
}

hold_kube_tools() {
    sudo apt-mark hold kubelet kubeadm kubectl
}


# Master Utils
MASTER_IP="192.168.56.10"
NODENAME=$(hostname -s)
POD_CIDR="192.160.0.0/16"


kubeadm_images_pull_and_init(){
    sudo kubeadm config images pull
    echo "Preflight Check Passed: Downloaded All Required Images"
    sudo kubeadm init --apiserver-advertise-address=$MASTER_IP  --apiserver-cert-extra-sans=$MASTER_IP --pod-network-cidr=$POD_CIDR --node-name $NODENAME --ignore-preflight-errors Swap
}

k8s_save_configs() {
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # Save Configs to shared /Vagrant location
    # For Vagrant re-runs, check if there is existing configs in the location and delete it for saving new configuration.
    config_path="/vagrant/configs"

    if [ -d $config_path ]; then
    rm -f $config_path/*
    else
    mkdir -p /vagrant/configs
    fi

    cp -i /etc/kubernetes/admin.conf /vagrant/configs/config
}

# Generete kubeadm join command
k8s_save_generate_join_script() {
    touch /vagrant/configs/join.sh
    chmod +x /vagrant/configs/join.sh       
    kubeadm token create --print-join-command > /vagrant/configs/join.sh
}

# Install Calico Network Plugin
k8s_install_calico() {
    curl https://docs.projectcalico.org/manifests/calico.yaml -O
    kubectl apply -f calico.yaml
}

# Install Metrics Server
k8s_install_metrics_server() {
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl patch deployment metrics-server -n kube-system --type 'json' -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
}

# Install Kubernetes Dashboard
k8s_install_dashboard() {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.4.0/aio/deploy/recommended.yaml
}
k8s_create_dashboard_user() {
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
}

k8s_get_token_from_secret() {
    kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}" >> /vagrant/configs/token
}

k8s_generate_config() {
    sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i /vagrant/configs/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
EOF
}

k8s_restart_kubelet() {
    sudo systemctl restart systemd-resolved
    sudo swapoff -a && sudo systemctl daemon-reload && sudo systemctl restart kubelet
}

# workers utils
run_worker_join_script() {
    /bin/bash /vagrant/configs/join.sh -v
}

copy_kubeconfig_to_worker() {
    sudo -i -u vagrant bash << EOF
mkdir -p /home/vagrant/.kube
sudo cp -i /vagrant/configs/config /home/vagrant/.kube/
sudo chown 1000:1000 /home/vagrant/.kube/config
NODENAME=$(hostname -s)
kubectl label node $(hostname -s) node-role.kubernetes.io/worker=worker-new
EOF
}

restart_worker_services() {
    sudo systemctl restart systemd-resolved
    sudo swapoff -a && sudo systemctl daemon-reload && sudo systemctl restart kubelet
}



# PREP SECTION
disable_swap
load_netfiltermodule
use_containerd_as_cri_runtime
install_apt_essential_packages
download_google_public_signing
add_kube_apt_repo
install_docker_containerd_engine
configure_containerd
install_kube_tools
hold_kube_tools

# Master installation
kubeadm_images_pull_and_init
k8s_save_configs
k8s_save_generate_join_script
k8s_install_calico
k8s_install_metrics_server
k8s_install_dashboard
k8s_create_dashboard_user
k8s_get_token_from_secret
k8s_generate_config
k8s_restart_kubelet

# Worker join
run_worker_join_script
copy_kubeconfig_to_worker
restart_worker_services
