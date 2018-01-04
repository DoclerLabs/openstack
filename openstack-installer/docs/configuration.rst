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

Various other artifacts (like certificates) can be put into the files/ directory.

2. Configuration storage
========================

By default, configuration of a cloud is stored at ~/.oscfg/default.

There are two small helper scripts supplied with this installer, scripts/newcfg.sh and
scripts/switchcfg.sh, which can create a new empty configuration from the config template and activate an
already created configuration. With these scripts, you can maintain configurations to more than
one OpenStack environment.

Usage of these scripts:

::

  # scripts/newcfg.sh [-b basedir] cfgname
  # scripts/switchcfg.sh [-b basdir] cfgname

Where basedir is the base of your config files, and cfgname is a subdirectory for a given cloud.
E.g.

::

  # scripts/newcfg -b $HOME/openstack cloud-1

will create a new config directory in ~/openstack/cloud-1. Later on, you can re-activate this configuration
via

::

  #scripts/switchcfg.sh -b $HOME/openstack cloud-1


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
management network, too, but some clients don't really support correct certificate checking (or
turning off verifying the certs).

The list of services which currently has problems:

- trove: trove cannot check, nor disable certificate checking to OS components.

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
  nova_console_ssl: True          # Turn on TLS in nova vnc/spice proxy.
  radosgw_ssl: True               # Turn on TLS for Ceph RadosGW.

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

  pacemaker_colocate_vips: False   # Put the public and management VIPs on the same host.

Syslog-ng or rsyslog
--------------------

The installer configures syslog-ng or rsyslog on the hosts. You can choose between the two by assigning
your hosts to the inventory groups syslog-ng or rsyslog. The syslog inventory group is inherited by
syslog-ng. The options controlling the system logger's behavior:

::

  syslog_use: False               # Disables/Enables sending logs from OpenStack components into the system logger.
  syslog_use_mongodb: False       # Syslog-ng only. Enabling this will send the logs to the MongoDB replica set,
                                  # which can be used as a central logging service. The document format sent
                                  # to Mongo is compatible with Adiscon LogAnalyzer.
  syslog_remote_syslog:           # If a domain name or IP address is given, send logs to a remote syslog.
  syslog_elasticsearch:           # Rsyslog and Ubuntu Xenial only. Send the logs to an Elasticsearch cluster
                                  # directly, no need to install Logstash.

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

There are several other settings exposed which can be used to fine-tune ceph, see roles/ceph_monitor/defaults/main.yml and
roles/ceph_osd/defaults/main.yml.

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
Support for OpenID-connect federation is also provided.

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
  keystone_token_provider: fernet              # By default, Fernet tokens are used. You can use deprecated UUID tokens, too.

There are some other settings in roles/os_keystone/defaults/main.yml, they can be overridden to fine-tune the service.

To configre OpenID-connect federation, a manual step is required for installing the libapache2-mod-auth-openidc package on Ubuntu Trusty.
This package is included in Ubuntu Xenial.

The config options for keystone to enable OIDC are:

::

  keystone_federation_oidc: False              # Change it to True to enable OpenID-connect federation.

  keystone_OIDCProviderMetadataURL:            # Set the Metadata URL or the three options below for the
  keystone_OIDCProviderIssuer:                 # OIDC provider.
  keystone_OIDCProviderAuthorizationEndpoint:
  keystone_OIDCProviderJwksUri:

  keystone_OIDCClientID:                       # Client ID expected by the OIDC provider.
  keystone_OIDCClientSecret:                   # Client secret expected by the OIDC provider.
  keystone_OIDCCryptoPassphrase:               # A passphrase.

  keystone_OIDCSSLValidateServer: True         # To check the certificate of the OIDC provider.


The final step is to create a JSON file for the identity provider mapping, and upload it to keystone. Horizon has a GUI
uploading/editing this file. Please see the Keystone docs about the format of the JSON.

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
        swift: 192.168.1.1                    # IP of the interface used for swift traffic. If you omit this, ip.mgmt will used.
        swift_replication: 192.168.2.1        # IP of the interface used for replication traffic (rsyncd will listen on this address).
                                              # If you omit this, it will fall back to ip.swift and ip.mgmt
      swift:
        - { device: "/dev/sdb" }              # The devices used for swift storage. They'll be formatted with xfs filesystem, and
        - { device: "/dev/sdc" }              # mounted under /srv/node.
    swift-storage-1:
      ip:
        mgmt: 192.168.0.2
        swift: 192.168.1.2
        swift_replication: 192.168.2.2
      swift:
        - { device: "/dev/sdb" }
        - { device: "/dev/sdc" }
    swift-storage-2:
      ip:
        mgmt: 192.168.0.3
        swift: 192.168.1.3
        swift_replication: 192.168.2.3
      swift:
        - { device: "/dev/sdb" }
        - { device: "/dev/sdc" }

Global configuration affecting swift:

::

  swift_part_power: 12                        # The log2 number of partitions (default: 2^12 partitions).
  swift_replicas: 3                           # Number of replicas of the objects.
  swift_min_part_hours: 1                     # Minimum hours must be elapsed before a partitioning change.

Glance
------

Glance is the image service in OpenStack. Its main purpose is to store VM images. Configuring doesn't require much effort than
choosing the backend where it stores the images.

The best place for glance settings is the global config.yml file:

::

  glance_backend: ceph                       # The backend to store the images. The settings accepted are: ceph, swift and files.
                                             # It is true that the 'files' backend doesn't require any other components,
                                             # but it cannot be HA, so use it only for testing/development purposes.
  glance_ceph_pool: images                   # The pool name in Ceph when glance_backend is ceph.
  glance_ceph_user: glance                   # The user name in Ceph when glance_backend is ceph.
  glance_ceph_key:                           # You can give your own Ceph authx key if you don't want to create the user automatically.

Nova
----

Nova is the compute service in OpenStack. Probably this is the most known service. The inventory groups nova_controller and nova_compute
are telling where to install Nova services.
The most important settings for Nova are:

::

  nova_ephemeral_backend: local              # Where to put root and ephemeral disks for the instances. The default 'local' value is the storage
                                             # in the compute node itself, while 'ceph' allows to use computes without local disc resources.
  nova_ephemeral_ceph_pool: vms              # If Ceph is used for ephemeral disks, the pool name used for them.
  nova_ephemeral_ceph_user: nova             # If Ceph is used for ephemeral disks, the user name used for accessing the pool.
  nova_ephemeral_volume_secret_uuid:         # If Ceph is used for ephemeral disks, a random UUID for the Ceph secret in Libvirt.
  nova_ephemeral_ceph_key:                   # If a cephx key is given here, use that, instead of creating a user. Useful for external Ceph.

  nova_cpu_allocation_ratio: 16.0            # The overprovisioning ratio for CPUs.
  nova_ram_allocation_ratio: 1.5             # The overprovisioning ratio for RAM.
  nova_compute_driver: libvirt.LibvirtDriver # The compute driver used. For LXD, use nova_lxd.nova.virt.lxd.LXDDriver.
  nova_compute_package: kvm                  # The package contains the used nova driver. For LXD, use lxd.
  nova_virt_type: kvm                        # Can be 'kvm' if KVM hardware acceleration is available on the compute node or 'qemu' if not.

  nova_console_type: vnc                     # Use 'vnc' or 'spice' for remote console
  nova_console_ssl: False                    # To use TLS for novncproxy/spiceproxy.
  nova_novncproxy_base_url:                  # Override this if the the default URL for the novncproxy is not presented correctly. By default it is
                                             # http(s)://{{ os_public_address }}:6080/vnc_auto.html
  nova_spiceproxy_base_url:                  # Override this if the the default URL for the spiceproxy is not presented correctly. By default it is
                                             # http(s)://{{ os_public_address }}:6082/spice_auto.html


Cinder
------

Cinder is the storage component in OpenStack. This installer supports the LVM and Ceph backends.
Cinder can be configured with multi-backend support, e.g. more than one Ceph pool (or even Ceph clusters) can be used.
The configuration options are:

::

  cinder_backend: lvm                        # The default backend for Cinder volumes. Can be 'lvm' or 'ceph'.
  cinder_volume_group: cinder-volumes        # The volume group name used by the lvm backend.
  cinder_ceph_pool: volumes                  # The default Ceph pool for the volumes.
  cinder_ceph_user: cinder                   # The Ceph user for accessing the Ceph pool.
  cinder_volume_secret_uuid:                 # A random UUID for the Ceph secret in Libvirt.
  cinder_ceph_key:                           # If a cephx key is given here, use that, instead of creating a user. Useful for external Ceph.
  cinder_iscsi_helper: tgtadm                # iSCSI subsystem, tgtadm is there for backwards compatibility, advisable to use lioadm.

  cinder_backup_backend: posix               # The backend for cinder backup, Can be 'posix', 'swift' or 'ceph'.
  cinder_backup_ceph_cluster_name:           # The cluster name for ceph used by cinder-backup. Default is ceph_cluster_name(ceph).
  cinder_backup_ceph_monitors:               # Alternative ceph monitor hosts for cinder-backup. Userful for external Ceph.
  cinder_backup_ceph_pool: backups           # The Ceph pool used for the volume backups.
  cinder_backup_ceph_user: cinder-backup     # The Ceph user used for the volume backups.
  cinder_backup_ceph_key:                    # Same as cinder_ceph_key, for the backup user/pool.


Multi-backend support can be activated by using a cinder_backends list instead of the options above. The list structure:

::

  cinder_backends:
    - backend: ceph
      name: ceph-1
      ceph_cluster_name: ceph
      ceph_monitors: groups['ceph_monitor']
      ceph_pool: cinder
      ceph_user: cinder
      ceph_key:
      volume_secret_uuid:
    - backend: ceph
      name: ceph-2
      .
      .
      .
    - backend: lvm
      volume_group: cinder-volumes


Neutron
-------

Neutron is the networking component. This installer implements the LinuxBridge and OpenVSwitch drivers, LBaaS, VPNaaS, FWaaS plugins and Flat, VLAN, VXLAN and GRE network segmentations.

A good review of the work you must do prior to running this playbook is found here: https://youtu.be/8FYgmM3tUCM

The inventory groups Neutron uses are:

- neutron_controller (for the neutron API server)
- neutron_l2 (for the Layer 2 interface driver)
- neutron_l3 (for the Layer 3 agents - router, dhcp, VPN, LBaaS functions)

For backwards compatibility, all of the components are included in the neutron_controller inventory group, and the L2 agent is included in the
neutron_compute group, so you alternatively can use:

- neutron_controller (for the API server, L2 and L3 agents)
- neutron_compute (for the L2 agent)

The other Neutron settings needs to be adjusted your phyiscal networking environment, so most settings don't have proper default values.
Most probably Neutron requires the most effort to set up properly.
Settings affecting Neutron are:

::

  neutron_physical_interface_driver: linuxbridge  # The mechanism driver to use.
                                                  # 'linuxbridge' supports Flat, VLAN and VXLAN networks.
                                                  # 'openvswitch' supports Flat, VLAN, VXLAN and GRE networks.
                                                  # For GRE and VXLAN networks, one has to specify an IP address to create the overlay network
                                                  # on that interface. Those can be specified by the ip.vxlan and ip.gre settings in the inventory.
  neutron_physical_interface_mappings:    # This contains a mapping for the physical network name in Neutron and the name in the host system.
                                          # For example, if you created a bridge called br-vlan, and you want to assign it to the name 'vlan' in
                                          # Neutron, use neutron_physical_interface_mappings: 'vlan:br-vlan'
                                          # More mappings can be added by separating them with a comma. E.g.:
                                          # neutron_physical_interface_mappings: 'flat:eth1, vlan:br-vlan'
                                          # This setting can be used in the inventory, too, if the nodes have different networking setup.
  neutron_vlan_ranges:                    # The VLAN IDs used for VLAN networks. Example: vlan:100:200
  neutron_ha_routers: False               # Set to 'True' if you want to create a Neutron router in HA mode (the router will be created on all
                                          # l3 nodes, and the active is determined by Keepalived).
  neutron_ha_network_type:                # The network type used for the Keepalived traffic for HA networks. By default it is the default Neutron
                                          # network type.
  neutron_ha_network_physical_name:       # The physical network name in Neutron for the Keepalived traffic for HA networks. Default is the default
                                          # Neutron network name for the given network type.
  neutron_flat_networks:                  # The name of the networks that can be used as 'flat' types. '*' can be used if all networks can be flat.
  neutron_vxlan_vni_ranges: "65537:69999" # The VNI range to use for VXLAN networks.
  neutron_vxlan_group: 239.0.0.0/8        # The multicast group range for VXLAN networks. The value's host part will be the VNI, so for example the
                                          # default setting will use 239.0.255.255 for the VNI 65535.
  neutron_gre_vni_ranges: "1:1000"        # The range for GRE networks (only with OpenVSwitch).
  neutron_dnsmasq_dns_servers:            # DNS forwarder address(es) used globally.
  neutron_mtu: 0                          # This setting is deprecated, use neutron_path_mtu, netron_segment_mtu or neutron_physical_network_mtus.
  neutron_advertise_mtu: True             # Whether to advertise the MTU size via DHCP and IPv6 RA.
  neutron_path_mtu: 0                     # Maximum packet size for the whole L3 path
  neutron_segment_mtu: 0                  # Maximum packet size for an L2 network segment
  neutron_physical_network_mtus:          # It is possble to give the MTU size for each physical network, e.g. flat:1500, vlan:3000
  neutron_vpnaas_type:                    # The VPNaaS agent used. Can be 'openswan', 'strongswan' or empty (no VPNaaS).
