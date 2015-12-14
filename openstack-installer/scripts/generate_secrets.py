#!/usr/bin/python

import os
import sys
import re
import random
import string

PASSWORD_LEN = 32


def generate_secrets(filename):

    secrets = []
    with open(filename, 'r') as f:
        for line in f:
            match = re.search('^([a-zA-Z].*):\s*$', line)
            if match:
                password = ''.join(random.SystemRandom().
                                   choice(string.ascii_uppercase +
                                          string.ascii_lowercase +
                                          string.digits)
                                   for _ in range(PASSWORD_LEN))
                secrets.append(match.group(1) + ': ' + password + '\n')
            else:
                secrets.append(line)

    with open(filename, 'w') as f:
        f.write(''.join(secrets))

generate_secrets(os.path.join(
    os.path.dirname(sys.argv[0]), "..", "group_vars/all/secrets.yml"))
