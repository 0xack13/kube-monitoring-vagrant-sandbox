Vagrant.configure("2") do |config|
  config.vm.provision "shell", inline: <<-SHELL
      apt-get update -y
      echo "10.0.10.10  master-node" >> /etc/hosts
      echo "10.0.10.11  worker-node01" >> /etc/hosts
      echo "10.0.10.12  worker-node02" >> /etc/hosts
  SHELL

  config.vm.box = "bento/ubuntu-21.10"
  config.vm.box_check_update = true

  config.vm.define "master" do |master|
    # master.vm.box = "bento/ubuntu-18.04"
    master.vm.hostname = "master-node"
    master.vm.network "private_network", ip: "10.0.10.10"
    master.vm.provider "virtualbox" do |vb|
        vb.memory = 4048
        vb.cpus = 2
    end
    master.vm.provision "shell", path: "utils.sh"
  end

  (1..2).each do |i|

  config.vm.define "node0#{i}" do |node|
    # node.vm.box = "bento/ubuntu-18.04"
    node.vm.hostname = "worker-node0#{i}"
    node.vm.network "private_network", ip: "10.0.10.1#{i}"
    node.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 1
    end
    node.vm.provision "shell", path: "worker_node.sh"
  end

  end
end 

# NUM_WORKER_NODES=2
# IP_NW="10.0.10."
# IP_START=10

# Vagrant.configure("2") do |config|
#     config.vm.provision "shell", inline: <<-SHELL
#         apt-get update -y
#         echo "$IP_NW$((IP_START))  master-node" >> /etc/hosts
#         echo "$IP_NW$((IP_START+1))  worker-node01" >> /etc/hosts
#         echo "$IP_NW$((IP_START+2))  worker-node02" >> /etc/hosts
#     SHELL
#     config.vm.box = "bento/ubuntu-21.10"
#     config.vm.box_check_update = true

#     config.vm.define "master" do |master|
#       master.vm.hostname = "master-node"
#       master.vm.network "private_network", ip: IP_NW + "#{IP_START}"
#       master.vm.provider "virtualbox" do |vb|
#           vb.memory = 4048
#           vb.cpus = 2
#           vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
#       end
#       master.vm.provision "shell", path: "utils.sh"
#     end

#     # workers
#     (1..NUM_WORKER_NODES).each do |i|
#       config.vm.define "node0#{i}" do |node|
#         node.vm.hostname = "worker-node0#{i}"
#         node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
#         node.vm.provider "virtualbox" do |vb|
#             vb.memory = 2048
#             vb.cpus = 1
#             vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
#         end
#         node.vm.provision "shell", path: "worker_node.sh"
#       end
#     end

#   end
