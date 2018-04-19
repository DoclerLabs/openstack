1. Common upgrade instructions
==============================

Upgrading OpenStack is supported when you try to upgrade to the next release.
General upgrading instructions are below.

- It is important to use the latest configs in the system. Run ansible-playbook
  for Ceph and OpenStack from the HEAD of the branch you're currently using:

  ::

    $ git checkout xenial/ocata
    $ ansible-playbook ceph.yml
    $ ansible-playbook main.yml

- Switch to the branch where the configs of the new version is:

  ::

    $ git checkout xenial/pike

- Generate newly added secrets:

  ::

    $ scripts/generate_secrets.py

- Upgrade Ceph first (this can be skipped if there's no new Ceph version) :

  ::

    $ ansible-playbook upgrade_ceph.yml

- Check ceph health (on a monitor host):

  ::

    $ ceph -s

- Upgrade pacemaker (this can be skipped if there's no new Pacemaker version):

  ::

    $ ansible-playbook pacemaker_upgrade.yml

- Upgrade galera cluster (don't use it for major galera version upgrade):

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


- Ready!

Newton -> Ocata specific instructions
=====================================

- With Ocata, MySql version 5.7 is installed, so skip Galera upgrade before the OpenStack upgrade.
  Upgrade to Percona XtraDB 5.7 after OpenStack is upgraded. This is a manual process, and don't
  use the galera_upgrade.yml playbook for it.

  The steps required for the upgrade:

  1. Detach galera from Pacemaker:

  ::

    $ crm resource unmanage p_galera

  2. Stop mysqld on one cluster member:

  ::

    $ kill $(cat /var/run/mysqld/mysqld.pid)

  3. Upgrade galera:

  ::

    $ apt-get install percona-xtradb-cluster-server-5.7

  4. Start the new server without authentication:

  ::

    $ mysqld_safe --skip-grant-tables &

  5. Upgrade the data structures:

  ::

    $ mysql_upgrade

  6. Stop mysqld:

  ::

    $ kill $(cat /var/run/mysqld/mysqld.pid)

  7. Put the server back to the cluster to sync with it:

  ::

    $ crm resource manage p_galera

  8. After the synchronization is successful, move to the next member, and repeat the steps 1-7.

- Seems there's an error with the Gnocchi package updates. If the package upgrade fails, finish it
  with

  ::

    $ apt-get install -f

  and restart the upgrade playbook after that.

- Cinder volumes without named backends are no longer supported, so after the upgrade, one has to
  manually change the 'host' field of the 'volumes' table of the cinder database.

  One example with the MySQL command line client:

  ::

     cinder> update volumes set host='controller1@ceph-1#ceph-1' where host='controller1#RBD';

- Nova instances must be mapped to a cell:

  ::

    $ nova-manage cell_v2 list_cells

     +-------+--------------------------------------+
     |  Name |                 UUID                 |
     +-------+--------------------------------------+
     |  None | 669ccdca-c368-46a5-a478-299d001a556f |
     | cell0 | 00000000-0000-0000-0000-000000000000 |
     +-------+--------------------------------------+

    $ nova-manage cell_v2 map_instances --cell_uuid 669ccdca-c368-46a5-a478-299d001a556f
