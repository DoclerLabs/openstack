# OpenStack Cloud Deployment

This repository contains OpenStack Cloud Control related projects. 

Currently it has openstack-installer, which is an Ansible based deployment tool to provision clouds as fast, and as easy as possible.

The motivation for creating this deployment tool is that existing solutions are too complex, over-engineered, and not reliable.

The design behind this installer is to remain simple, use Ansible's features, but not over-use them. Don't use bash scripts, which are usually going to an unmaintainable state after some iterations. Use the packages of the underlying OS (currently Ubuntu 14.04 is supported), and don't mess the system with software installed from various sources. The installer also can be used after the deployment to change parameters of an existing cloud, so it supports the full life-cycle of the deployed OpenStack.

Current OpenStack versions supported:
liberty - trusty/liberty branch
mitaka  - master branch
