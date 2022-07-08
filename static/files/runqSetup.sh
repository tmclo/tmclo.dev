#!/bin/bash
sudo yum update -y
sudo yum -y install git
sudo yum -y groupinstall 'Development Tools'
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
if cat /proc/cpuinfo | egrep -q "vmx|svm";
then
	echo "System supports virtualization, continuing..."
fi
sudo dnf -y update
sudo dnf -y install qemu-kvm qemu-img libvirt virt-install libvirt-client virt-viewer
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
cd /opt && git clone --recurse-submodules https://github.com/gotoz/runq.git && cd runq && make release && make release-install
cat << EOF > /etc/docker/daemon.json
{
  "runtimes": {
    "runq": {
      "path": "/var/lib/runq/runq",
      "runtimeArgs": [
        "--cpu", "1",
        "--mem", "256",
        "--dns", "1.1.1.1,1.0.0.1",
        "--tmpfs", "/tmp"
      ]
    }
  }
}
EOF
sudo systemctl restart docker.service
sh /var/lib/runq/qemu/mkcerts.sh
if [[ $(cat /proc/sys/kernel/random/entropy_avail) -lt 1000 ]];
then
	echo "not enough entropy, maybe try installing rng-tools & haveged?"
else
	echo "enough entropy"
fi
sudo modprobe vhost_vsock
echo "finished installing."
while true; do
    read -p "Reboot recommended, do this now? [Y/n] " yn
    case $yn in
        [Yy]* ) sudo reboot; break;;
        [Nn]* ) exit 1;;
        * ) echo "Please answer yes or no.";;
    esac
done