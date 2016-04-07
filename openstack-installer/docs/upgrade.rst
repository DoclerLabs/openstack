1. Common upgrade instructions
==============================

Upgrading OpenStack is supported when you try to upgrade to the next release.
General upgrading instructions are below.

- It is important to use the latest configs in the system. Run ansible-playbook
  for Ceph and OpenStack from the HEAD of the branch you're currently using:

::

  $ git checkout trusty/liberty
  $ ansible-playbook ceph.yml
  $ ansible-playbook main.yml

- Switch to the branch where the configs of the new version is:

::

  $ git checkout master

- Upgrade Ceph first:

::

  $ ansible-playbook upgrade_ceph.yml

- Check ceph health (on a monitor host):

::

  $ ceph -s

- Upgrade galera cluster:

::

  $ ansible-playbook galera_upgrade.yml

- Upgrade RabbitMQ:

::

  $ ansible-playbook rabbitmq_upgrade.yml

- Check RabbitMQ health:

::

  $ rabbimtqctl cluster_status

- Upgrade OpenStack:

::

  $ ansible-playbook os_upgrade.yml

- Apply the latest configs:

  $ ansible-playbook ceph.yml
  $ ansible-playbook main.yml

- Ready!
