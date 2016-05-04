# OpenStack Cloud Deployment

This repository contains OpenStack Cloud Control related projects. 

There are two sub-projects in this repository:
- openstack-installer, which is an Ansible based deployment tool to provision clouds as fast, and as easy as possible.
- openstack-monitoring, which is also an Ansible based deployment tool to set up Nagios monitoring for the Cloud.

The motivation for creating this deployment tool is that existing solutions are too complex, over-engineered, and not reliable.

The design behind this installer is to remain simple, use Ansible's features, but not over-use them. Don't use bash scripts, which are usually going to an unmaintainable state after some iterations. Use the packages of the underlying OS (currently Ubuntu 14.04 and 16.04 are supported), and don't mess the system with software installed from various sources. The installer also can be used after the deployment to change parameters of an existing cloud, so it supports the full life-cycle of the deployed OpenStack.

Current OpenStack versions supported:
- liberty/Ubuntu Trusty        - trusty/liberty branch
- mitaka/Ubuntu Trusty/Xenial  - master branch

Installing an all-in-one (Ceph, controller, compute) VM with Vagrant:

- Install vagrant
- Clone the repo
- Setup aio

```
    $ cd openstack/openstack-installer
    $ scripts/restorecfg.sh aio
    $ scripts/generate_secrets.py
    $ cd vagrant
    $ vagrant up
```

- Check out Horizon in a browser: http://10.10.1.254, use Default/admin/admIn credentials
