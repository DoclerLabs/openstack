#!/usr/bin/python

import argparse
import yaml
import json

def get_parent_group(yml, group, nesting_level):
    nesting_level+=1
    if nesting_level == 10:
        raise(Exception, "Too many nesting level of groups, probably a loop?")
    if yml[group] and 'inherit' in yml[group]:
        return get_parent_group(yml, yml[group]['inherit'], nesting_level)
    else:
        return group

def inventory(hostname):

    with open("inventory.yml", 'r') as f:
        yml=yaml.safe_load(f)

    if hostname:
        for group in yml:
            if yml[group] and hostname in yml[group]:
                hostvars=yml[group][hostname]
                hostvars['ansible_ssh_host']=hostvars['ip']['mgmt']
                print json.dumps(hostvars, indent=4)
                return
    else:
        inventory={}
        for group in yml:
            groupname=get_parent_group(yml, group,0)
            inventory[group]=sorted(yml[groupname].keys()) if yml[groupname] else []

        print json.dumps(inventory, indent=4)

parser = argparse.ArgumentParser(description='Dynamic inventory for Openstack.')
parser.add_argument('--list', help='list the hosts', action='store_true')
parser.add_argument('--host', help='returnt the variables for the hosts')
args = parser.parse_args()

inventory(args.host)
