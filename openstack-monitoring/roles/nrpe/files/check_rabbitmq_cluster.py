#!/usr/bin/python3

import subprocess
import re
import yaml
import json

NAGIOS_OK = 0
NAGIOS_WARN = 1
NAGIOS_CRIT = 2
NAGIOS_UNKNOWN = 3
NAGIOS_STATUS = {
    NAGIOS_OK: "OK",
    NAGIOS_WARN: "Warning",
    NAGIOS_CRIT: "Critical",
    NAGIOS_UNKNOWN: "Unknown"}


class RabbitError(Exception):
    pass


def get_rabbitmq_nodes():

    proc = subprocess.Popen(["/usr/sbin/rabbitmqctl", "cluster_status", "--formatter=json"],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            shell=False)
    (out, err) = proc.communicate()
    if proc.returncode != 0:
        raise RabbitError(err)

    doc=json.loads(out)
    disc_nodes = ram_nodes = running_nodes = partitions = []
    for section in doc:
        if section == 'ram_nodes':
            ram_nodes = doc[section]
        elif section == 'disk_nodes':
            disc_nodes = doc[section]
        elif section == 'running_nodes':
            running_nodes = doc[section]
        elif section == 'partitions':
            partitions = doc[section]
    return disc_nodes, ram_nodes, running_nodes, partitions


def main():

    try:
        (disc_nodes, ram_nodes, running_nodes, partitions) = get_rabbitmq_nodes()
        if not running_nodes:
            ret = NAGIOS_CRIT
            msg = "No running nodes!"
        elif partitions:
            ret = NAGIOS_WARN
            msg = "Partitions: %s" % partitions
        elif sorted(disc_nodes + ram_nodes) != sorted(running_nodes):
            ret = NAGIOS_CRIT
            msg = "Disc nodes: %s, RAM nodes: %s, running nodes: %s" % \
                  (disc_nodes, ram_nodes, running_nodes)
        else:
            ret = NAGIOS_OK
            msg = "Disc nodes: %s, RAM nodes: %s" % (disc_nodes, ram_nodes)
    except RabbitError as e:
        ret = NAGIOS_CRIT
        msg = str(e)
    except Exception as e:
        ret = NAGIOS_UNKNOWN
        msg = str(e)

    print("%s: %s" % (NAGIOS_STATUS[ret],  msg))
    exit(ret)

main()
