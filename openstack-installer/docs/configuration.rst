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

Ceph
----

Ceph has 3 host groups in the inventory, namely ceph_monitor, ceph_osd and ceph_radosgw.

Ceph monitor is the 'brain' of the ceph cluster, it is recommended to have at least 3 hosts. Monitors are
forming a cluster with quorum, so odd number of monitor hosts is recommended.

Ceph OSDs (Object Store Daemons) are the actual storage nodes. For performance reasons, it is recommended
to use bare disks (so if you have a RAID controller, set it to JBOD mode), possibly use a separate fast 
device for journal and to not share disks between monitor and OSD usage.

Radosgw is an Amazon S3 or Swift compatible object storage backed by the Ceph storage cluster.

Important configuration options:

::

  ceph_cluster_name: ceph            # Name of the cluster. 'ceph' is the default, it is best to leave it as is.
  ceph_osd_journal_size: 10000       # The default journal size. Look at the ceph docs to calculate the correct size.
                                     # Default value is 10GB, it is good for the most use cases.
  ceph_osd_pool_default_size: 3      # The number of replicas of a pool. By default, 3 copies of each data is
                                     # maintained across the cluster. It is not recommended to lower it, but if you
                                     # have less than 3 OSDs (testing for example), then do it.
  ceph_osd_pool_default_min_size: 0  # The minimum number of active replicas for a pool to work. The default '0' value
                                     # means size - (size / 2).
  ceph_osd_pool_default_pg_num: 64   # The default number of placement groups for an automatically created pool.

  ceph_public_network:               # It is recommended to have separate networks for the front-end and the internal
  ceph_cluster_network:              # side of the ceph nodes, for performance reasons. Give a network/netmask value here.
                                     # There is no default value, since it depends on your environment. Not giving any
                                     # value here will use the same network for front-end and replication traffic.

Configuring ceph includes setting up disk space for OSD usage. The recommended way is to give whole disks to Ceph,
and to use a fast journal device (like fast SSDs, or even NVMes). Since the disk configuration likely different
on the storage nodes, it is the best to put it as host variables in the inventory. If you're absolutely sure that
the same disk configuration is used on all ceph_osd nodes, then you can put it into config.yml, too.

Example OSD configuration in the inventory:

::

  ceph_osd:
    os-ceph-1:
      ip:
        mgmt: 192.168.0.1          # Address of the os-ceph-1 node.
      osd:
        - { disk: "/dev/sdb" }     # Use the whole device directly.
        - { disk: "/dev/sdc", journal: "/dev/sdf1" }  # For the OSD on /dev/sdc, create a journal on /dev/sdf1
    os-ceph-2:
      ip:
        mgmt: 192.168.0.2          # Address of the os-ceph-2 node.
      osd:
        - { path: "/mnt/osd" }     # Use an already formatted and mounted FS for the OSD.