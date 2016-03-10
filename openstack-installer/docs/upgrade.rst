1. Common upgrade instructions
==============================

- It is important to use the latest configs in the system. Run ansible-playbook
  for Ceph and OpenStack from the HEAD of the branch you're currently using.

::

  $ git checkout liberty
  $ ansible-playbook ceph.yml
  $ ansible-playbook main.yml

- Switch to the branch where the configs of the new version is.

::

  $ git checkout master

- Upgrade Ceph first:

::

  $ ansible-playbook upgrade_ceph.yml

- Apply the latest ceph configs:

::

  $ ansible-playbook ceph.yml

- Upgrade OpenStack: TODO
