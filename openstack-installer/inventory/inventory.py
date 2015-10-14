#!/usr/bin/python

import argparse
import yaml
import json

def inventory(hostname):

    with open("inventory.yml", 'r') as f:
        yml=yaml.safe_load(f)

    if hostname:
        for group in yml:
            if hostname in yml[group]:
                hostvars=yml[group][hostname]
                hostvars['ansible_ssh_host']=hostvars['ip']['mgmt']
                print json.dumps(hostvars, indent=4)
                return
    else:
        inventory={}
        for group in yml:
            if 'inherit' in yml[group]:
                groupname=yml[group]['inherit']
            else:
                groupname=group

            inventory[group]=sorted(yml[groupname].keys())

        print json.dumps(inventory, indent=4)

parser = argparse.ArgumentParser(description='Dynamic inventory for Openstack.')
parser.add_argument('--list', help='list the hosts', action='store_true')
parser.add_argument('--host', help='returnt the variables for the hosts')
args = parser.parse_args()

inventory(args.host)
