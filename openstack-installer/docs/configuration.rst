1. Configuration locations
==========================

Most configuration options have a default value. There are several locations, where Ansible allows to
override the defaults. Also there are some mandatory config values, which you must define before 
successfully deploying a cloud. The most important config locations:

- inventory file (inventory/inventory.yml)
- the "all" group variables (group_vars/all/config.yml)

The main difference between the two locations is the former can have host-specific values, while the
later is applied to all hosts.
There are some variables, which can be used on both places, and the location depends on your needs.
E.g. neutron_physical_interface_mappings used in config.yml applies the same logical-physical interface
assignment on all hosts, but if you have hosts with different network configurations, or different NICs,
it is also possible to use this setting on a per-host basis in inventory.yml.

2. Configuration backup/restore
===============================

There are two small helper scripts supplied with this installer, scripts/savecfg.sh and
scripts/restorecfg.sh, which backup and restore the inventory and the global config files into the
configs/ directory. With these scripts, you can maintain configurations to more than one OpenStack
environment.

3. Inventory format
===================

The inventory.yml file is written in YAML format. It contains a hierarchial key-value data structure.
On the top of this hieararcy there are the host groups, which collects hosts with the same role.
The next level are the host names which are belong to this group. Another level contains the variables
assigned to this host. Instead of specifying a list of hosts for each group, one group can inherit
the members from another group. It is useful when more than one role applies to the same set of hosts
(which is very common in an OpenStack deployment).

Example inventory entry:

::

  ceph_osd:                        # The group.
    inherit: controller            # Inherit members from the 'controller' group.
    os-ceph-0:                     # A host in this group. Note: it is possible to combine it with 'inherit'.
      ip:
        mgmt: 192.168.0.1          # ip.mgmt is the only mandatory host variable. It is used by Ansible to connect to the host.
      osd:                         # Another host variable, in this case, 'osd' is used by the ceph_osd role.
        - { disk: "/dev/sdb" }
        - { disk: "/dev/sdc" }
        - { disk: "/dev/sdd" }
        - { disk: "/dev/sde" }

If you want to skip the installation of a component (and it is not a mandatory component), don't delete
the group from the inventory, but don't assign any hosts to it.
Example for not installing Trove:

::

  trove:
         # Leave the host list empty

4. Secrets
==========

While it is also a group variable file in the 'all' group, group_vars/all/secrets.yml has special use:
it contains the various passwords configured for internal communication of the various components.
You can specify those manually, but using scripts/generate_secrets.py ensures that fairly strong
passwords will be used. Possible exception is the keystone_admin_password which is the Admin password
of the Cloud, and most probably you want to give it yourself. Note: this file must be protected from
unintentional disclosure, since it has very security-sensitive content.

5. Global configuration
=======================

As mentioned in the first section, group_vars/all/config.yml contains global configuration values for
the whole deployment. Nearly all values have sane defaults, which you can inspect at
roles/role_name/defaults/main.yml. These values can be overwritten here (or in the inventory, if needed).
Some variables must be defined in the global config, since they don't (or can not) have any sane defaults.
The description of some component's configuration values follows:

Pacemaker
---------

Pacemaker creates the VIP addresses, where you can reach your OpenStack cluster, so it is mandatory to
configure the management and the public-facing VIP addresses (but they can be the same, if you plan to
restrict the access to the cluster via firewalls, or by any other means).

Pacemaker is also responsible for starting/stopping the Galera cluster, so you don't have to worry about 
the bootstrapping and cold-starting process.
Configuration options:

::

  vip_mgmt: 192.168.0.100          # The VIP of the management network.
  vip_mgmt_cidr: 24                # The netmask bits of the management network.
  vip_mgmt_nic: eth2               # The NIC used by the management network on the controller(s).

  vip_public: 192.168.1.100        # The public VIP.
  vip_public_cidr: 24              # The netmask of the public network.
  vip_public_nic: eth3             # The NIC used by the public network.


Syslog-ng
---------

The installer configures syslog-ng on the hosts. There are two options to alter its behavior:

::

  syslog_use: False               # Disables/Enables sending logs from OpenStack components into syslog-ng.
  syslog_use_mongodb: False       # Enabling this will send the logs to the MongoDB replica set, which can be
                                  # used as a central logging service. The document format sent to Mongo is
                                  # compatible with Adiscon LogAnalyzer.
