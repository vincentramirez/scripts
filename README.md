# kvm host prep bash script

This bash script is used to prep a CentOS linux host prior to installing 
the PF9 host agent and authorizing the host.  

## Requirements

*Ensure the host has internet connectivity 
*Run a yum update and ensure the host can communicate with public repos


## Instructions

*Modify the script at Step 10 to update the device names for physical nics and ifcfg-xxx file names
*Use your own unique IP addrs per sub interface based on your vlans 
*After customizing the script with the environmentals per host, scp the script to the host /tmp
*Modify the script at Step 13 if using NFS exports to reflect the ip and export path of your nfs server
line 138 & 147

## License

NA

