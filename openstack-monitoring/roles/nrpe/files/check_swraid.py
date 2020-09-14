#!/usr/bin/python3

# check_swraid - plugin for nagios to check the status of linux swraid devices
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
# Copyright 2004 Duke University
# Written by Sean Dilda <sean@duke.edu>

# Version: 0.2

import os
import sys
import string

mdstat = '/proc/mdstat'

mdFile = open(mdstat).readlines()

# Remove the first and lasts lines as we don't need them
mdFile = mdFile[1:-1]

mdData = []
mdDev = []
for line in mdFile:
    if line.strip():
        mdDev.append(line)
    else:
        mdData.append(mdDev)

overallStatus = 0
errorMsg = ''
for tup in mdData:
    device, colon, status, type, drives = tup[0].split(None, 4)
    drives = drives.split()
    values = tup[1].split()[-2]
    values = values[1:-1]
    normal, current = values.split('/')
    normal = int(normal)
    current = int(current)


    # Status of 0 == Ok, 1 == Warning, 2 == Critical
    status = 0
    failed = 0
    degraded = 0
    msg = ''

    failed_list = []
    for drive in drives:
        if drive[-3:] == '(F)':
            failed_list.append(drive[:string.index(drive, '[')])
            status = 1
    failed = ", "
    failed = ' (' + failed.join(failed_list) + ').'


    if status == 'inactive':
        status = 2
        msg = device + ' is inactive.'
    if type == 'raid5':
        if current < (normal -1):
            msg = device + ' failed' + failed 
            status = 2
        elif current < normal:
            msg = device + ' degraded' + failed
            status = 1
    else:
        if current < normal:
            msg = device + ' failed' + failed
            status = 2

    if len(msg) > 0:
        if len(errorMsg) > 0:
            errorMsg = errorMsg + '; '
        errorMsg = errorMsg + msg
        overallStatus = max(overallStatus, status)

if overallStatus == 0:
    print ('All md devices Ok.')
    sys.exit(0)
else:
    print (errorMsg)
    sys.exit(overallStatus)
