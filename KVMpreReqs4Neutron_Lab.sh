#!/bin/bash
#Setup script written for PF9 OpenStack Labs 
#The user will be prompted to press enter to continue at certain phases.
#
#This is required for all components to have their time synchronized.
echo -e "\e[31;43m***** This script will install the KVM pre-req's for Neutron on your host  *****\e[0m"
read -p "PRESS ENTER TO CONTINUE"
echo -e "\e[31;43m***** PREREQS FOR NEUTRON *****\e[0m"
echo -e "\e[31;43m***** Install, Enable, & Start the NTP Daemon *****\e[0m"
#Step 1: install ntp, *you could also use chrony in place of ntp
sudo yum install -y ntp
sudo systemctl enable ntpd
sudo systemctl start ntpd
#Step 2: Set SELinux to permissive
#This is required for Open vSwitch OVS to be able to manage networking
echo -e "\e[31;43m***** Set SELinux to permissive *****\e[0m"
sudo sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
sudo setenforce 0
sudo getenforce 
#Step 3: Disable Firewalld and NetworkManager
#This is required for KVM and OVS to be able to create iptables rules directly without Firewalld
#getting in the way. These may not be running in the lab. But are part of a standard linux build
echo -e "\e[31;43m***** Disable Firewalld and NetworkManager *****\e[0m"
sudo systemctl disable firewalld
sudo systemctl stop firewalld
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager
#Step 4: Enable Network
echo -e "\e[31;43m***** Enable Network *****\e[0m"
sudo systemctl enable network
#Step 5: Load the modules needed for Neutron
echo -e "\e[31;43m***** Load the modules needed for Neutron *****\e[0m"
sudo modprobe bridge
sudo modprobe 8021q
sudo modprobe bonding
sudo modprobe tun
sudo modprobe br_netfilter
#Makes the modules load after reboot
echo -e "\e[31;43m***** Makes the modules load after reboot *****\e[0m"
echo "bridge" | sudo tee /etc/modules-load.d/pf9.conf
echo "8021q" | sudo tee --append /etc/modules-load.d/pf9.conf
echo "bonding" | sudo tee --append /etc/modules-load.d/pf9.conf
echo "tun" | sudo tee --append /etc/modules-load.d/pf9.conf
echo "br_netfilter" | sudo tee --append /etc/modules-load.d/pf9.conf
echo -e "\e[31;43m***** You may get an error around br_netfilter not being available... This is fine as long as you don't get an error in Step 6 regarding "net.bridge.bridge-nf-call-iptables=1" *****\e[0m"
#Step 6: Add sysctl options
echo -e "\e[31;43m***** Add sysctl options *****\e[0m"
echo "net.ipv4.conf.all.rp_filter=0" | sudo tee --append /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" | sudo tee --append /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee --append /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" | sudo tee --append /etc/sysctl.conf
echo "net.ipv4.tcp_mtu_probing=1" | sudo tee --append /etc/sysctl.conf
sudo sysctl -p
#Step 7: Add the Platform9 YUM Repo
echo -e "\e[31;43m***** Add the Platform9 YUM Repo *****\e[0m"
sudo yum -y install https://s3-us-west-1.amazonaws.com/platform9-neutron/noarch/platform9-neutron-repo-1-0.noarch.rpm
#Step 8: Install Open vSwitch
echo -e "\e[31;43m***** Install Open vSwitch *****\e[0m"
sudo yum -y install --disablerepo="*" --enablerepo="platform9-neutron-el7-repo" openvswitch
#Step 9: Enable and start Open vSwitch
echo -e "\e[31;43m***** Enable and start Open vSwitch *****\e[0m"
sudo systemctl enable openvswitch
sudo systemctl start openvswitch
#Step 10: Configure networking on the host, create a bond and OVS bridge for the physical network
# 
echo -e "\e[31;43m***** Create a bond *****\e[0m"
echo "DEVICE=bond0" | sudo tee /etc/sysconfig/network-scripts/ifcfg-bond0
echo "ONBOOT=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0
echo "MTU=9000" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0
echo "BONDING_MASTER=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0
echo 'BONDING_OPTS="mode=6"' | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0
#
#Edit the physical adapters to join the bond, Adjust the device names to match yours
echo -e "\e[31;43m***** Edit phys adapter to join the bond  *****\e[0m"
echo "DEVICE=eth0" | sudo tee /etc/sysconfig/network-scripts/ifcfg-eth0
echo "ONBOOT=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth0
echo "BOOTPROTO=none" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth0
echo "MTU=9000" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth0
echo "MASTER=bond0" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth0
echo "SLAVE=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth0
#echo "MACADDR=xx:xx:xx:xx:xx:xx" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth0  
#
echo "DEVICE=eth1" | sudo tee /etc/sysconfig/network-scripts/ifcfg-eth1
echo "ONBOOT=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth1
echo "BOOTPROTO=none" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth1
echo "MTU=9000" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth1
echo "MASTER=bond0" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth1
echo "SLAVE=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth1
#echo "MACADDR=xx:xx:xx:xx:xx:xx" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-eth1
#
echo -e "\e[31;43m***** Create Bond Sub-interfaces  *****\e[0m"
#Be sure to adjsut the device name and ifcfg-bond0.YourName and your IP addrs
#Management Sub-interface
echo "DEVICE=bond0.201" | sudo tee /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "ONBOOT=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "BOOTPROTO=none" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "TYPE=Vlan" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "VLAN=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "IPADDR=1.1.1.10" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "NETMASK=255.255.255.0" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "GATEWAY=1.1..1" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "DNS1=8.8.8.8" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
echo "DNS1=8.8.4.4" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.201
#Sub-interface used for tenant networking *No gateway is intentional
echo "DEVICE=bond0.202" | sudo tee /etc/sysconfig/network-scripts/ifcfg-bond0.202
echo "ONBOOT=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.202
echo "BOOTPROTO=none" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.202
echo "TYPE=Vlan" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.202
echo "VLAN=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.202
echo "IPADDR=2.2.2.10" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.202
echo "NETMASK=255.255.255.0" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.202
#Storage Sub-interface used to isolate storage traffic *No gateway is intentional
echo "DEVICE=bond0.203" | sudo tee /etc/sysconfig/network-scripts/ifcfg-bond0.203
echo "ONBOOT=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.203
echo "BOOTPROTO=none" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.203
echo "TYPE=Vlan" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.203
echo "VLAN=yes" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.203
echo "IPADDR=3.3.3.10" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.203
echo "NETMASK=255.255.255.0" | sudo tee --append /etc/sysconfig/network-scripts/ifcfg-bond0.203
#
#Step 11: Restart Networking
#This may disconnect you from the ssh session. If you can't get back in after a few minutes
#Connect through the console if unable to ssh.
echo -e "\e[31;43m***** Restart Networking if you loose ssh access hard, console in to trouble shoot *****\e[0m"
sudo systemctl restart network.service
#Step 12: Validate network configuration
echo -e "\e[31;43m***** Validate network configuration.  Review outputs below *****\e[0m"
sudo ip a
sudo ovs-vsctl show
sudo ovs-vsctl add-br br-pf9
sudo ovs-vsctl add-port br-pf9 bond0
#Step 13: If using NFS in your environment
#Configure shares and map to an NFS server in your environment 
sudo yum install -y nfs-utils
sudo mkdir -p /remote/exports/pf9
#These next steps assume an NFS export was created in your environment called "/nfs/pf9" 
#replace the IP with IP of your nfs server or storage array provider 
sudo echo "1.2.3.4:/nfs/pf9 /remote/exports/pf9 nfs auto 0 0" | sudo tee --append /etc/fstab
sudo mount -a
echo -e "\e[31;43m***** Make sure the nfs mount is configured  *****\e[0m"
sudo df -h
read -p "PRESS ENTER TO CONTINUE"
sudo mkdir /remote/exports/pf9/instances
sudo mkdir /remote/exports/pf9/images
sudo mkdir /remote/exports/pf9/block
sudo mkdir /etc/cinder
sudo echo "1.2.3.4:/nfs/pf9/block" | sudo tee /etc/cinder/nfs_shares
sudo yum install -y lvm2
#This assumes your server has an additional volume at /dev/sdb
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo vgs
#
#END OF SCRIPT..
echo -e "\e[31;43m***** END OF SCRIPT...a system reboot is recommended at this point *****\e[0m"
read -p "PRESS ENTER TO REBOOT"
sudo shutdown -r now 
