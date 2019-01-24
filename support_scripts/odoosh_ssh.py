#!/usr/bin/env python3
import os
import requests
import socket
import sys
import urllib

OLD_SERVERS_IPS = {
    '35.198.220.217': 'aspp1',
    '35.195.18.151': 'eupd1',
    '35.187.115.106': 'eupp1',
    '104.155.23.254': 'eupp2',
    '35.205.247.29': 'eupp3',
    '35.187.46.26': 'eupv1',
    '104.155.86.160': 'eupv2',
    '35.224.116.9': 'ampd1',
    '35.202.90.205': 'ampp1',
    '104.154.114.160': 'ampp2',
    '146.148.95.232': 'ampp3',
    '35.226.155.95': 'ampp4',
    '35.185.248.9': 'ampv1',
    '35.199.167.163': 'ampv2',
}

def check_host(host):
    try:
        old_server = OLD_SERVERS_IPS.get(socket.gethostbyname(host))
        if old_server:
            sys.exit("This database is hosted on an older Odoo.sh server: %s" % old_server)
    except Exception:
        sys.exit("Can't resolve host %s" % host)


args = sys.argv[:]

if len(args) != 2:
    sys.exit('''Usage: odoossh <BUILD>

BUILD can be a database name, a hostname or an uri. Here are some examples:

    odoossh my-odoo-sh-project-user-test-666
    odoossh my-odoo-sh-project.odoo.com
    odoossh https://my-odoo-sh-project.odoo.com/web/whatever-copy-pasted-url
    odoossh 666@eupp1.odoo.com
''')

db = None
host = args[1]

if host.startswith('http'):
    host = urllib.parse.urlparse(host).netloc

if '@' in host:
    user, host = host.split('@')
else:
    if '.' in host:
        check_host(host)
        try:
            res = requests.post('http://%s/web/database/list' % host, json={'id': '1'})
        except Exception as e:
            sys.exit("Could not contact host: %s", e)
        if not res.ok:
            sys.exit("Could not retreive database name. Odoo instance might be down or cloudflare in front. "
                     "Use the database name instead of an url in this case.")
        try:
            db = res.json()['result'][0]
        except Exception:
            sys.exit("Could not extract database name from host")
    else:
        db = host
        host = '%s.dev.odoo.com' % db  # won't work on test.odoo.sh

    try:
        user = int(db.split('-')[-1])
    except ValueError:
        sys.exit("%s is not a valid Odoo.sh database name" % db)


check_host(host)
ssh_host = '%s@%s' % (user, host)
os.execvp('/usr/bin/ssh', [
    '/usr/bin/ssh', '-p', '22',
    '-o', 'UserKnownHostsFile=/dev/null',
    '-o', 'StrictHostKeyChecking=no',
    ssh_host
])
