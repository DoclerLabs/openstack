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

It is important, that one host (with the same management IP) must be only in one host group. If you
want to put a host into several roles, use the inherit keyword, or an alternative format: a host group can
have a "special host", called roles. You can specify a list here, which roles must be applied to the
machines in the list. Example:

::

  controller:
    controller1:
      ip:
        mgmt: 192.168.0.1
    controller2:
      ip
        mgmt: 192.168.0.2
    roles:
      - pacemaker
      - haproxy
      - memcached
      - rabbitmq
      - galera
      - mongodb
      - syslog
      - keystone
      - glance
      - horizon
      - nova_controller
      - neutron_controller
      - heat
      - cinder
      - cinder_volume

With this notation, unused components still have to be given as an empty group.

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

TLS for public facing services
------------------------------

HTTP connections to OpenStack components can be secured by TLS. It is recommended in production.
This installer implements full end-to-end TLS connections, so HAProxy doesn't terminate the secured
channel. One implication is that services configured to https are communicating with TLS on the
management network, too, but some clients doesn't really support correct certificate checking (or
turning off verifying the certs).

The list of services which currently has problems:

- cinder: cinder quotas code doesn't work connecting to secured keystone.
- trove: trove cannot check, nor disable certificate checking to OS components.
- sahara: sahara has some options to allow to set CA certificate or turn the checking off in nova,
  neutron and cinder, but they're not implemeneted correctly.
- radosgw: there's no way to specify a custom CA certificate or turn the checking off.

Settings for TLS connections:

::

  SSLCertificateFileSource:        # The PEM file for the server certificate.
  SSLCertificateKeyFileSource:     # The PEM file with the private key.
  SSLCACertificateKeyFileSource:   # The PEM file for the CA certificate.
  ssl_insecure:                    # Don't check the CA certificate in the clients during
                                   # inter-communication of OS components. Not recommended in
                                   # production.

If the SSLCertificateFileSource and SSLCertificateKeyFileSource settings are defined, Horizon will
automatically configured to https. Http connections will redirected to https, too.

To turn on TLS support in other services, use the following settings:

::

  keystone_ssl: True              # Turn on TLS in keystone. Default is False (no TLS).
  os_ssl: True                    # Turn on TLS in other OpenStack components.
  nova_novncproxy_ssl: True       # Turn on TLS in nova vnc proxy.

With TLS support, it is recommended to set the components address to the domain name, which is in the
certificate. so the following settings should be set:

::

  os_internal_address: "{{ vip_mgmt }}"  # These should be changed from the default vip addresses
  os_admin_address: "{{ vip_mgmt }}"     # to a domain name, which can be checked by the TLS certificate
  os_public_address: "{{ vip_public }}"  # verification

Please note, that the services are only listen on the management interface, so they'll not present
different certificates to the clients on the public and the internal (management) network. This can be a
problem with the certificate checking. To overcome the problem, there are some options:

- Use the same network for the management and public. This is the least recommended solution.
- Set up the domain name of the management vip to the same as the public vip locally on the hosts (e.g. in
  /etc/hosts). So internal communication will always go to vip_mgmt, but external clients can see the vip_public
  from DNS. In this case, all os_xxx_address settings will be the same, but they'll have different meaning for
  internal and public clients.
- Use certificates with two subjecAltNames, one would be the public domain name, and the other would be the
  management domain name.

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

Radosgw settings:

::

  radosgw_keystone: True           # Integrate radosgw with keystone authentication, disable if using swift.
  radosgw_port: 8080               # The default port where radosgw listens, change it if swift is used.


Keystone
--------

Keystone is the central authentication service in OpenStack. UUID and Fernet tokens are implemented in this installer.

For a multi-region setup, the installation can be skipped with an empty inventory for the 'keystone' group. In this case,
the keystone_xxx_address settings (see below) should point to the central keystone instance.

Settings which most likely have to be changed in a production installation:

::

  keystone_internal_address: "{{ vip_mgmt }}"  # These are the internal, admin and public endpoint addresses
  keystone_admin_address: "{{ vip_mgmt }}"     # of the keystone service. By default, they are set to the management
  keystone_public_address: "{{ vip_public }}"  # and public VIPs, but if you're using TLS, you'll want to use domain name(s) here.

  keystone_region_name: RegionONE              # The region name where this OpenStack installation belongs to.
  keystone_domain_name: Default                # The keystone v3 domain where the service accounts will created. Note: 'Default'
                                               # is a special domain which allows compatibility with keystone v2.0.
  keystone_ssl: False                          # Enable TLS for keystone. A certificate and a private key file must be supplied in
                                               # SSLCertificateFileSource and SSLCertificateKeyFileSource.
  ssl_insecure: False                          # It's a global setting for all OpenStack components, where you can disable certificate
                                               # checking (e.g. in case of self-signed certificates). Don't use it in production.
  keystone_token_provider: uuid                # By default, uuid tokens are used. You can use fernet tokens, too.

There are some other settings in roles/os_keystone/defaults/main.yml, they can be overridden to fine-tune the service.

Swift
-----

Swift is the standard object store component of OpenStack. Two inventory groups are belong to swift: swift_proxy and swift_storage.
Swift proxy is best to put on controllers, and you can decide where to put storage. At least 3 storage nodes are recommended.
Using a separate storage network for replication traffic is recommended, because of the traffic volume, and for security reasons:
unauthenticated rsync daemons will listen on the management interfaces.

If you're using radosgw, change its port, and disable keystone integration!

Configuring the storage can be done in the inventory:

::

  swift_storage:
    swift-storage-0:
      ip:
        mgmt: 192.168.0.1
        swift: 192.168.1.3                    # IP of the interface used for replication traffic. If you omit this, ip.mgmt will used.
      swift:
        - { device: "/dev/sdb" }              # The devices used for swift storage. They'll be formatted with xfs filesystem, and
        - { device: "/dev/sdc" }              # mounted under /srv/node.
    swift-storage-1:
      ip:
        mgmt: 192.168.0.2
        swift: 192.168.1.3
      swift:
        - { device: "/dev/sdb" }
        - { device: "/dev/sdc" }
    swift-storage-2:
      ip:
        mgmt: 192.168.0.3
        swift: 192.168.1.3
      swift:
        - { device: "/dev/sdb" }
        - { device: "/dev/sdc" }

Global configuration affecting swift:

::

  swift_part_power: 12                        # The log2 number of partitions (default: 2^12 partitions).
  swift_replicas: 3                           # Number of replicas of the objects.
  swift_min_part_hours: 1                     # Minimum hours must be elapsed before a partitioning change.
