#!/bin/sh -e

if [ -z "$1" ]; then
    echo "Usage: $0 config_name [-e|--encrypt]"
    echo
    echo "$0: saves the current configs as config_name to configs"
    echo "  -e | --encrypt: encrypts secrets.yml with ansible-vault"
    exit 0
fi

BASEDIR=$(dirname "$0")/..
CONFDIR="$BASEDIR/configs/$1"
mkdir -p "$CONFDIR"/group_vars/all "$CONFDIR"/inventory "$CONFDIR"/files
cp "$BASEDIR"/group_vars/all/* "$CONFDIR/group_vars/all"
cp "$BASEDIR/inventory/inventory.yml" "$CONFDIR/inventory/inventory.yml"
cp -r "$BASEDIR/files" "$CONFDIR"
if [ "$2" = "-e" -o "$2" = "--encrypt" ]; then
    ansible-vault encrypt "$CONFDIR/group_vars/all/secrets.yml"
fi
