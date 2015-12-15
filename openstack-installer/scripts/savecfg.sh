#!/bin/sh

if [ -z "$1" ]; then
    echo "Usage: $0 config_name"
    echo
    echo "$0: saves the current configs as config_name to configs"
    exit 0
fi

BASEDIR=$(dirname "$0")/..
CONFDIR="$BASEDIR/configs/$1"
mkdir -p "$CONFDIR"/group_vars/all "$CONFDIR"/inventory
cp "$BASEDIR"/group_vars/all/* "$CONFDIR/group_vars/all"
cp "$BASEDIR/inventory/inventory.yml" "$CONFDIR/inventory/inventory.yml"
