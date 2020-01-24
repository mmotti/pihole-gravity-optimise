#!/usr/bin/env python

import os
import sqlite3
import re
import subprocess
import tempfile
import locale


def split_list(in_list, size):
    # Set action on parameters missing
    if not in_list:
        return
    if not size:
        size = 1000

    # Yield each sub-list
    for i in range(0, len(in_list), size):
        yield in_list[i:i + size]


# Set locale automatically
locale.setlocale(locale.LC_ALL, '')

path_pihole = r'/etc/pihole'
path_dnsmasq = r'/etc/dnsmasq.d'
path_legacy_regex = os.path.join(path_pihole, 'regex.list')
path_legacy_gravity = os.path.join(path_pihole, 'gravity.list')
path_pihole_db = os.path.join(path_pihole, 'gravity.db')

set_gravity_domains = set()
set_wildcard_domains = set()
set_regexps = set()
list_removal_chunks = list()
set_regexp_domain_matches = set()
set_removal_domains = set()

db_exists = False
c = None
conn = None

# Exit if not running as root
if not os.getuid() == 0:
    print('Please run this script as root')
    exit(1)
else:
    print('[i] Root user detected')

# Exit if Pi-hole dir does not exist
if not os.path.exists(path_pihole):
    print(f'{path_pihole} was not found')
    exit(1)
else:
    print('[i] Pi-hole path exists')

print('[i] Updating gravity (this may take a little time)')
subprocess.call(['pihole', '-g'], stdout=subprocess.DEVNULL)

# Determine whether we are using DB or not
if os.path.isfile(path_pihole_db) and os.path.getsize(path_pihole_db) > 0:
    db_exists = True
    print('[i] DB detected')
else:
    print('[i] Legacy lists detected')

# Fetch gravity domains
print('[i] Fetching domains')

if db_exists:
    # Create a DB connection
    print(f'[i] Connecting to {path_pihole_db}')

    # Create a connection object
    try:
        conn = sqlite3.connect(path_pihole_db)
    except sqlite3.Error as e:
        print(e)
        exit(1)

    # Tell the text factory to ignore UTF-8 errors as
    # gravity doesn't yet accommodate for these pesky domains
    conn.text_factory = lambda b: b.decode(errors='ignore')
    # Create a cursor object
    c = conn.cursor()

    # Run query to fetch domains
    print('[i] Querying DB for gravity domains')
    c.execute('SELECT domain FROM gravity')
    set_gravity_domains.update(x[0] for x in c.fetchall())
else:
    # If gravity.list exists and isn't 0 bytes
    if os.path.exists(path_legacy_gravity) and os.path.getsize(path_legacy_gravity) > 0:
        # Read to set
        # Excluding non utf-8 characters that may have been introduced by list maintainers
        with open(path_legacy_gravity, 'r', encoding='utf-8', errors='ignore') as fOpen:
            set_gravity_domains.update(x for x in map(str.strip, fOpen) if x and x[:1] != '#')

# If gravity domains were returned
if set_gravity_domains:
    print(f'[i] --> {len(set_gravity_domains):n} domains found')
else:
    print('[i] No domains were found')
    exit(1)

# If dnsmasq dir exists, extract wildcards
if os.path.isdir(path_dnsmasq):
    print(f'[i] Scanning {path_dnsmasq} for wildcards')
    # Set the wildcard regexp
    regexp_wildcard = r'^address=\/.+\/(([0-9]{1,3}\.){3}[0-9]{1,3}|::|#)?$'
    # For each file in dnsmasq dir
    for file in os.listdir(path_dnsmasq):
        # If it's a conf file and not the pi-hole conf
        if file.endswith('.conf') and file != '01-pihole.conf':
            # Create a subprocess command to run grep on the current file
            cmd = subprocess.Popen(['grep', '-E', regexp_wildcard, os.path.join(path_dnsmasq, file)],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8')
            # Run the command
            grep_result = [x.split('/')[1] for x in cmd.communicate()[0].split('\n') if x]
            # Fetch the return code
            grep_return_code = cmd.returncode

            # If there were matches
            if grep_return_code == 0:
                # Add the wildcard domain to the wildcards set
                set_wildcard_domains.update(grep_result)

    # If wildcards are found
    if set_wildcard_domains:
        print(f'[i] --> {len(set_wildcard_domains):n} wildcards found')
        print(f'[i] Identifying wildcard conflicts with gravity')

        # Remove exact wildcard matches from gravity domains
        set_gravity_domains.difference_update(set_wildcard_domains)
        # Add exact wildcard matches to removal set
        set_removal_domains.update(set_wildcard_domains)

        # Initialise a temp file for marked gravity domains
        with tempfile.NamedTemporaryFile('w+') as temp_marked_gravity:
            # Initialise a temp file for marked wildcard domains
            with tempfile.NamedTemporaryFile('w+') as temp_marked_wildcard:
                # Write marked gravity domains
                for line in (f'^{x}$' for x in set_gravity_domains):
                    temp_marked_gravity.write(f'{line}\n')
                # Write marked wildcard domains
                for line in (f'.{x}$' for x in set_wildcard_domains):
                    temp_marked_wildcard.write(f'{line}\n')

                # Seek to start of files
                temp_marked_gravity.seek(0)
                temp_marked_wildcard.seek(0)

                # Create a subprocess command to run a fixed-string grep search
                # for wildcards against the domains
                cmd = subprocess.Popen(['grep', '-Ff', temp_marked_wildcard.name, temp_marked_gravity.name],
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8')

                # Run the command
                grep_result = [x[1:-1] for x in cmd.communicate()[0].split('\n') if x]
                # Fetch the return code
                grep_return_code = cmd.returncode

                # If there were matches
                if grep_return_code == 0:
                    # Add to removal domains
                    set_removal_domains.update(grep_result)
                    # Remove from gravity domains
                    set_gravity_domains.difference_update(grep_result)
                    # Status update
                    print(f'[i] --> {len(grep_result):n} conflicts found')

                # If there were no matches
                elif grep_return_code == 1:
                    print('[i] --> 0 conflicts found')
                # If there was an error running grep
                elif grep_return_code == 2:
                    print('[i] --> An error occurred when running grep command')
    else:
        print('[i] --> No wildcards found')

# Fetch regexps
print('[i] Fetching regexps')

if db_exists:
    c.execute('SELECT domain FROM domainlist WHERE TYPE = 3')
    set_regexps.update(x[0] for x in c.fetchall())
else:
    # If regex.list exists and isn't 0 bytes
    if os.path.exists(path_legacy_regex) and os.path.getsize(path_legacy_regex) > 0:
        # Read to set
        with open(path_legacy_regex, 'r', encoding='utf-8', errors='ignore') as fOpen:
            set_regexps.update(x for x in map(str.strip, fOpen) if x and x[:1] != '#')

if set_regexps:
    print(f'[i] --> {len(set_regexps):n} regexps found')
    print('[i] Checking for gravity matches')

    # Initialise temp file for regexps
    with tempfile.NamedTemporaryFile('w+') as temp_regexps:
        # Initialise temp file for gravity
        with tempfile.NamedTemporaryFile('w+') as temp_gravity:
            # Add regexps to temp file
            for line in set_regexps:
                temp_regexps.write(f'{line}\n')
            # Add gravity domains to temp file
            for line in set_gravity_domains:
                temp_gravity.write(f'{line}\n')

            # Seek to start of files
            temp_regexps.seek(0)
            temp_gravity.seek(0)

            # Create a subprocess command to run a fixed-string grep search
            # for wildcards against the domains
            cmd = subprocess.Popen(['grep', '-Ef', temp_regexps.name, temp_gravity.name],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding='utf-8')

            # Run the command
            grep_result = [x for x in cmd.communicate()[0].split('\n') if x]
            # Fetch the return code
            grep_return_code = cmd.returncode

            # If there were matches
            if grep_return_code == 0:
                # Add to removal domains
                set_removal_domains.update(grep_result)
                # Remove from gravity domains
                set_gravity_domains.difference_update(grep_result)
                # Status update
                print(f'[i] --> {len(grep_result):n} matches found in gravity')

            # If there were no matches
            elif grep_return_code == 1:
                print('[i] --> 0 matches found in gravity')
            # If there was an error running grep
            elif grep_return_code == 2:
                print('[i] --> An error occurred when running grep command')
else:
    print('[i] --> No regexps found')

# If there are domains remaining post-processing and it's less than the the initial count
if set_removal_domains:

    if db_exists:
        print('[i] Running deletions')

        # Define list chunk size
        chunk_size = 1000

        # For each list chunk
        for chunk in split_list(list(set_removal_domains), chunk_size):
            # Run the deletions
            c.executemany('DELETE FROM gravity '
                          'WHERE domain IN (?)', [(x,) for x in chunk])

        # Commit Changes
        conn.commit()

        # Query actual DB count
        c.execute('SELECT COUNT(DISTINCT domain) FROM gravity')
        print(f'[i] --> {c.fetchall()[0][0]:n} domains remain in the gravity database')

        conn.close()
    else:
        print('[i] Outputting updated gravity.list')

        # Output gravity set to gravity.list
        with open(path_legacy_gravity, 'w', encoding='utf-8') as fWrite:
            for line in sorted(set_gravity_domains):
                fWrite.write(f'{line}\n')

        print(f'[i] --> {len(set_gravity_domains):n} domains remain in gravity.list')

    print('[i] Restarting Pi-hole')
    subprocess.call(['pihole', 'restartdns', 'reload'], stdout=subprocess.DEVNULL)
else:
    print('[i] No optimisation required')
