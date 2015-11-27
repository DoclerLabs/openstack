#!/usr/bin/python

import sys
import os
import argparse
import yaml
import json

MAX_NESTING_LEVEL = 10

def expand_group(yml, group, nesting_level):

    nesting_level+=1
    if nesting_level == MAX_NESTING_LEVEL:
        raise(Exception, "Too many nesting level of groups, probably a loop?")
    hosts=[]
    if yml[group]:
        for host, key in yml[group].iteritems():
            if host == 'inherit':
                if isinstance(key,list):
                    for inherited_group in key:
                        hosts.extend(expand_group(yml,inherited_group,nesting_level))
                else:
                     hosts.extend(expand_group(yml,key,nesting_level))
            else:
                hosts.append(host)
    return hosts

def inventory(hostname):

    with open(os.path.dirname(sys.argv[0])+"/inventory.yml", 'r') as f:
        yml=yaml.safe_load(f)

    if hostname:
        for group, data in yml.iteritems():
            if data and hostname in data:
                hostvars=data[hostname]
                hostvars['ansible_ssh_host']=hostvars['ip']['mgmt']
                print json.dumps(hostvars, indent=4)
                return
    else:
        inventory={ "_meta": { "hostvars" : {} } }
        for group, data in yml.iteritems():
            inventory[group]=sorted(expand_group(yml,group,0))
            if data:
                for host, hostvars in data.iteritems():
                    if host != 'inherit':
                        inventory['_meta']['hostvars'][host]=hostvars
                        inventory['_meta']['hostvars'][host]['ansible_ssh_host']=hostvars['ip']['mgmt']

        print json.dumps(inventory, indent=4)

parser = argparse.ArgumentParser(description='Dynamic inventory for Openstack.')
parser.add_argument('--list', help='list the hosts', action='store_true')
parser.add_argument('--host', help='returnt the variables for the hosts')
args = parser.parse_args()

inventory(args.host)
