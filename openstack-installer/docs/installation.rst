1. Introduction
---------------

This is Another OpenStack Installer. It can deploy an OpenStack cluster (with or without HA controllers).
It uses Ansible, the best configuration management software, to install the infrastructure and the OpenStack components.
It does not install the base OS, also doesn't configure the hardware (network interfaces, disks, NTP), but everything after that.

2. Pre-requisite
----------------

- A deployment node, which can connect to the provisioned nodes via ssh. Install ansible on it.
- Ubuntu 14.04 LTS for the base OS. Need odd number of controller nodes, and arbitary number of compute nodes.
- For ceph, it is recommended to have at least 3 monitor nodes, and 3 OSD nodes.
- Set up the network for the nodes:
  - OpenStack Controller nodes need a management interface, and a separate public interface is recommended.
  - OpenStack Compute nodes need a management interface.
  - For using Neutron VLAN segmentation, a Linux Bridge where the Neutron plugin can create VLANs. This interface can be shared with the management or the public interface.
  - For Ceph, it is recommended to have separate management and cluster communication interfaces.
- NTP should be working on all nodes.
- All nodes must have an user 'ansible' created, ssh passwordless login enabled from the deployment node, and sudo rights.

3. Installation
---------------

- Copy the configuration templates from configs/template to the base directory of the installer: $ cp -r configs/template/* .
- Preparare the inventory
  - inventory/inventory.yml contains the inventory. It is possible to enable/disable components, define the hosts used for deployment, and to define host variables.
- Generate the secrets
  - Edit group_vars/all/secrets.yml, if you want pre-defined passwords for some items, add it to the file.
  - Run scripts/generate_secrets.py to auto-generate the passwords which are left empty in secrets.yml.
- Edit group_vars/all/config.yml to further refine the OpenStack configuration.
- Run ansible-playbook -i inventory/inventory.py main.yml
- Wait until the installation finishes. If it stops somewhere, just correct the configuration, and re-run the previous command.
