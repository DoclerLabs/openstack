#!/usr/bin/python3

import subprocess
import re
import yaml
import json
import lsb_release

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

    proc = subprocess.Popen(["/usr/sbin/rabbitmqctl", "cluster_status"],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE,
                            shell=False)
    (out, err) = proc.communicate()
    out = out.decode()
    if proc.returncode != 0:
        raise RabbitError(err)

    # remove first line
    status = out[out.find('\n')+1:]
    # erl to yaml
    yml_s = re.sub('{([a-z\'].*?),', r'{"\1":', status)
    yml = yaml.safe_load(yml_s)

    disc_nodes = ram_nodes = running_nodes = partitions = []
    for section in yml:
        if 'nodes' in section:
            for kind in section['nodes']:
                if 'disc' in kind:
                    disc_nodes = kind['disc']
                elif 'ram' in kind:
                    ram_nodes = kind['ram']
        elif 'running_nodes' in section:
            running_nodes = section['running_nodes']
        elif 'partitions' in section:
            partitions = section['partitions']
    return disc_nodes, ram_nodes, running_nodes, partitions

def get_rabbitmq_nodes_new():

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
        dinfo=lsb_release.get_distro_information()
        (disc_nodes, ram_nodes, running_nodes, partitions) = \
            get_rabbitmq_nodes_new() if dinfo['RELEASE']>'20' else get_rabbitmq_nodes()
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
