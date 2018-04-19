# OpenStack Cloud Deployment

This repository contains OpenStack Cloud Control related projects. 

There are two sub-projects in this repository:
- openstack-installer, which is an Ansible based deployment tool to provision clouds as fast, and as easy as possible.
- openstack-monitoring, which is also an Ansible based deployment tool to set up Nagios monitoring and Collectd metrics collecting for the Cloud.

The motivation for creating this deployment tool is that existing solutions are too complex, over-engineered, and not reliable.

The design behind this installer is to remain simple, use Ansible's features, but not over-use them.
Don't use bash scripts, which are usually going to an unmaintainable state after some iterations.
Use the packages of the underlying OS (from the Newton release, only Ubuntu 16.04 is supported),
and don't mess the system with software installed from various sources.
The installer also can be used after the deployment to change parameters of an existing cloud,
so it supports the full life-cycle of the deployed OpenStack.

The deployed cloud is fully production ready, and the controlling and API components are highly available.
Upgrade option from the previous version is available.

Several clouds in production are installed and upgraded with this installer (from 10 to 40 computes, 512 to 1600 VCPUs).

Current OpenStack versions supported:
- Liberty/Ubuntu Trusty        - trusty/liberty branch
- Mitaka/Ubuntu Trusty/Xenial  - mitaka branch
- Newton/Ubuntu Xenial         - xenial/newton branch
- Ocata/Ubuntu Xenial          - xenial/ocata branch
- Pike/Ubuntu Xenial           - xenial/pike branch

Integrated Infra components:
- Pacemaker
- Galera cluster (supervised by Pacemaker)
- MongoDB (optional)
- RabbitMQ
- HAProxy
- Memcached
- PowerDNS (for designate - optional)
- Zookeeper (optional but recommended)
- Ceph (optional)

Integrated OpenStack components (all compontents can be enabled/disabled in the inventory):
- Core components, they should work out-of-box after the installer finishes:
  - keystone
  - glance
  - nova
  - neutron
  - cinder
  - gnocchi
  - panko
  - ceilometer
  - aodh
  - heat
  - swift
 
- Components, which are working, but maybe need some handwork (like getting guest images):
  - ironic
  - trove
  - murano
 
- Components, which are tagged experimental (maybe work, but there are upstream bugs to be fixed, or not really tested):
  - barbican
  - designate
  - magnum
  - manila
  - mistral
  - sahara
  - senlin

Installing an all-in-one (Ceph, controller, compute) VM with Vagrant:

- Install vagrant
- Clone the repo
- Setup aio

```
    $ cd openstack/openstack-installer
    $ scripts/switchcfg.sh -b configs aio
    $ scripts/generate_secrets.py
    $ cd vagrant
    $ vagrant up
```

- Check out Horizon in a browser: http://10.10.1.254, use Default/admin/admIn credentials

- Check current issues in the [Wiki] (https://github.com/DoclerLabs/openstack/wiki)
