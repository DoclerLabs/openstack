#!/usr/bin/env python

import os
import sys
import re
import random
import string
import yaml

PASSWORD_LEN = 32


def generate_secrets(filename, template):

    secrets = []
    with open(filename, 'r') as f:
        secretfile = yaml.safe_load(f)

    with open(template, 'r') as f:
        for line in f:
            match = re.search('^([a-zA-Z].*):', line)
            if match:
                key = match.group(1)
                if key in secretfile and secretfile[key]:
                    password = secretfile[key]
                else:
                    password = ''.join(random.SystemRandom().
                                   choice(string.ascii_uppercase +
                                          string.ascii_lowercase +
                                          string.digits)
                                   for _ in range(PASSWORD_LEN))
                secrets.append(key + ': ' + password + '\n')
            else:
                secrets.append(line)

    with open(filename, 'w') as f:
        f.write(''.join(secrets))


def main():
    generate_secrets(
        os.path.join(
            os.path.dirname(sys.argv[0]),
            "..",
            "group_vars",
            "all",
            "secrets.yml"),
        os.path.join(
            os.path.dirname(sys.argv[0]),
            "secrets.yml.template"))

if __name__ == "__main__":
    # execute only if run as a script
    main()
