#!/bin/sh

usage()
{
    echo "Usage: $0 [ -b basedir ] configname"
    echo "basedir default is $HOME/.oscfg"
    echo "configname default is 'default'"
    exit 0
}

INSTALLER=$(dirname "$0")/..
BASEDIR="$HOME/.oscfg"
CFGNAME="default"

while [ "$1" != "" ];
do
    if [ "$1" = "-b" ]; then
        shift
        BASEDIR="$(readlink -e $1)"
        if [ "$BASEDIR" != "" ]; then
            shift
        fi
    else
        CFGNAME="$1"
        shift
    fi
done

[ -z "$CFGNAME" ] && usage
[ -z "$BASEDIR" ] && usage

echo "CFGNAME: $CFGNAME"
echo "BASEDIR: $BASEDIR"

ln -sfn "$BASEDIR/$CFGNAME/ansible.cfg" "$INSTALLER/ansible.cfg"
ln -sfn "$BASEDIR/$CFGNAME/files" "$INSTALLER/files"
ln -sfn "$BASEDIR/$CFGNAME/files" "$INSTALLER/templates"
ln -sfn "$BASEDIR/$CFGNAME/group_vars/all" "$INSTALLER/group_vars/all"
ln -sfn "$BASEDIR/$CFGNAME/inventory/inventory.yml" "$INSTALLER/inventory/inventory.yml"
