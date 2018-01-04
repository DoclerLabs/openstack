1. Introduction
===============

This is Another OpenStack Installer. It can deploy an OpenStack cluster (with or without HA controllers).
It uses Ansible, the best configuration management software, to install the infrastructure and the OpenStack components.
It does not install the base OS, also doesn't configure the hardware (network interfaces, disks, NTP), but everything after that.

2. Pre-requisite
================

- A deployment node, which can connect to the provisioned nodes via ssh. Install Ansible on it. Version = 2.4.1.0 is used in the CI system currently,
  so it is recommended. The 1.x series doesn't work anymore! 2.4.0.0 has several bugs, don't use it (usually x.x.0 versions are not working).
- Ubuntu 14.04 LTS (Liberty/Mitaka) or 16.04 LTS (Mitaka/Newton/Ocata/Pike) for the base OS. Need odd number of controller nodes, and arbitary number of compute nodes.
- For ceph, it is recommended to have at least 3 monitor/manager nodes, and 3 OSD nodes.
- Set up the network for the nodes:

  - OpenStack Controller nodes need a management interface, and a separate public interface is recommended.
  - OpenStack Compute nodes need a management interface.
  - For using Neutron VLAN segmentation, a Linux Bridge where the Neutron plugin can create VLANs. This interface can be shared with the management or the public interface.
    If you're using the OpenVSwitch Neutron plugin, create the OVS bridges (br-int and br-ex) first.
    VXLAN with the LinuxBridge plugin requires only an interface with IP address.
  - For Ceph, it is recommended to have separate management and cluster communication interfaces.

- NTP should be working on all nodes.
- All nodes must have an user 'ubuntu' created, ssh passwordless login enabled from the deployment node, and sudo rights. Several deployment tools, like MAAS,
  creates an 'ubuntu' user by default with sudo rights. If you're using another user, you have to give '-u username' parameter in the ansible-playbook command line,
  or change ansible.cfg remote_user parameter.

3. Installation
===============

- Copy the configuration templates from configs/template to the config directory (by default it is ~/.oscfg/default):

::

  $ scripts/newcfg.sh

- Preparare the inventory

  - inventory/inventory.yml contains the inventory. It is possible to enable/disable components, define the hosts used for deployment, and to define host variables.

- Generate the secrets

  - Edit group_vars/all/secrets.yml, if you want pre-defined passwords for some items, add it to the file. The possible items can be found in scripts/secrets.yml.template.
  - Auto-generate the missing password entries in secrets.yml:

::

  $ scripts/generate_secrets.py

.. note:: It is a good practice to run scripts/generate_secrets.py after updating the installer (e.g. after git pull or fetch-rebase),
          because it'll add newly added secrets from the template to secrets.yml.

- Edit group_vars/all/config.yml to further refine the OpenStack configuration.
- If you plan to use ceph:

::

  $ ansible-playbook ceph.yml

- Wait until the ceph monitor and OSD nodes are installed.
- Log in to a ceph monitor host, and create the pools for the OpenStack storage:

::

  $ ceph osd pool create images [pg-num]
  $ ceph osd pool create volumes [pg-num]
  $ ceph osd pool create backups [pg-num]
  $ ceph osd pool create vms [pg-num]

- If you're using gnocchi with Ceph, create the pool for it:

::

  $ ceph osd pool create gnocchi [pg-num]

The reason behind not creating the pools automatically is that the pg-num parameter. It needs to be determined carefully according to ceph docs.

- Run the OpenStack installation:

::

  $ ansible-playbook main.yml

- Wait until the installation finishes. If it stops somewhere, just correct the configuration, and re-run the previous command.

4. Test the cloud
=================

It is a good idea to run tempest on the installed cloud. The steps for preparing it:

- Check roles/os_tempest/defaults/main.yml file. You must set up the external_* parameters for your enviroment, so copy the external_* variables to group_vars/all/config.yml, and set the appropriately.
- Run the tempest setup:

::

  $ ansible-playbook -i inventory/inventory.py os_tempest.yml

The default inventory uses the deployment hosts for running tempest. It'll try to install some packages, so if you don't have sudo rights, then you'll get an error. Install those packages manually with a root user then.

- The default installation directory for tempest is ~/tempest, and a virtualenv directory is created with the plugins, so to run it:

::

  $ cd ~/tempest/tempest
  $ . ../virtualenv/bin/activate
  $ testr init
  $ testr list-tests (to check if everything is set up properly)
  $ testr run

5. Cloud repair
===============

Hardware under the cloud sometimes fail. After replacing a faulty machine, one wants to restore the services on it. To restore OpenStack, follow the steps below:

- Reinstall the OS, as in the Pre-requisite section (configure network, storage, NTP, Ansible user with public key access).
- Re-run the OpenStack installation:

::

  $ ansible-playbook main.yml

- Wait until the installation finishes. Thanks to Ansible, only the new node will reconfigured, the existing ones will preserved as is. In case of a compute
  failure, the node will be fully reconfigured with the compute services. If the failed node was a controller node, and the services were still up (quroum did not lost),
  the cluster will be restored to a fully working state.
