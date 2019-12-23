from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
import os
import sqlite3
import re
import subprocess
import ahocorasick

path_pihole = r'/etc/pihole'
path_dnsmasq = r'/etc/dnsmasq.d'
path_legacy_regex = os.path.join(path_pihole, 'regex.list')
path_legacy_gravity = os.path.join(path_pihole, 'gravity.list')
path_pihole_db = os.path.join(path_pihole, 'gravity.db')

set_gravity_domains = set()
set_wildcard_domains = set()
list_regexps = list()
list_regex_chunks = list()
list_removal_chunks = list()
set_regexp_domain_matches = set()
set_removal_domains = set()

db_exists = False
c = None
conn = None

count_conflicts_wildcards = None
count_conflicts_regexps = None

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
subprocess.run(['pihole', '-g'], stdout=subprocess.DEVNULL)

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

    # Create a cursor object
    c = conn.cursor()
    # Run query to fetch domains
    c.execute('SELECT domain FROM gravity')
    set_gravity_domains.update(x[0] for x in c.fetchall())
else:
    # If gravity.list exists and isn't 0 bytes
    if os.path.exists(path_legacy_gravity) and os.path.getsize(path_legacy_gravity) > 0:
        # Read to set
        # Excluding non utf-8 characters that may have been introduced by list maintainers
        with open(path_legacy_gravity, 'r', encoding='utf-8', errors='ignore') as fOpen:
            set_gravity_domains.update(x for x in (line.strip() for line in fOpen) if x and x[:1] != '#')

# If gravity domains were returned
if set_gravity_domains:
    print(f'[i] --> {len(set_gravity_domains)} domains found')
else:
    print('[i] No domains were found')
    exit(1)

# Identify wildcard domains
print(f'[i] Scanning {path_dnsmasq} for wildcards')
regexp_wildcard = re.compile(r'^address=\/.+\/(([0-9]{1,3}\.){3}[0-9]{1,3}|::|#)?$')

# If dnsmasq dir exists, extract wildcards
if os.path.isdir(path_dnsmasq):
    # For each file in dnsmasq dir
    for file in os.listdir(path_dnsmasq):
        # If it's a conf file and not the pi-hole conf
        if file.endswith('.conf') and file != '01-pihole.conf':
            # Read contents to set
            with open(os.path.join(path_dnsmasq, file), 'r') as fOpen:
                set_wildcard_domains.update(x.split('/')[1] for x in (line.strip() for line in fOpen)
                                            if x[:1] != '#' and re.match(regexp_wildcard, x))

# If wildcards are found
if set_wildcard_domains:
    print(f'[i] --> {len(set_wildcard_domains)} wildcards found')
    print(f'[i] Identifying wildcard conflicts with gravity')

    # Remove exact wildcard matches from gravity domains
    set_gravity_domains.difference_update(set_wildcard_domains)
    # Add exact wildcard matches to removal set
    set_removal_domains.update(set_wildcard_domains)

    # Create a copy of sets with start / wildcard / end markers
    set_marked_gravity_domains = {f'^{x}$' for x in set_gravity_domains}
    set_marked_wildcard_domains = {f'.{x}$' for x in set_wildcard_domains}

    # Initialise finite-state machine of wildcards
    automaton = ahocorasick.Automaton()

    # Set conflict iterator
    count_conflicts_wildcards = 0

    # Add wildcards to automaton
    for idx, wildcard in enumerate(set_marked_wildcard_domains):
        automaton.add_word(wildcard, (idx, wildcard))

    # Convert to Aho-Corasick
    automaton.make_automaton()

    # For each domain
    for domain in set_marked_gravity_domains:
        # If a wildcard matches the domain
        if any(automaton.iter(domain)):
            # Add domains to removal set
            set_removal_domains.add(domain[1:-1])
            # Increment conflict counter
            count_conflicts_wildcards += 1

    # If there were conflicts
    if count_conflicts_wildcards > 0:
        print(f'[i] --> {count_conflicts_wildcards} conflicts found')
        # Remove domains from gravity set
        set_gravity_domains.difference_update(set_removal_domains)
    else:
        print('[i] --> 0 conflicts found')
else:
    print('[i] --> No wildcards found')

# Fetch regexps
print('[i] Fetching regexps')

if db_exists:
    c.execute('SELECT domain FROM domainlist WHERE TYPE = 3')
    list_regexps.extend(x[0] for x in c.fetchall())
else:
    # If regex.list exists and isn't 0 bytes
    if os.path.exists(path_legacy_regex) and os.path.getsize(path_legacy_regex) > 0:
        # Read to set
        with open(path_legacy_regex, 'r') as fOpen:
            list_regexps.extend(x for x in (line.strip() for line in fOpen) if x and x[:1] != '#')

if list_regexps:
    print(f'[i] --> {len(list_regexps)} regexps found')
    print('[i] Checking for gravity matches')

    # Split regexps into chunks
    list_regex_chunks = [list_regexps[x:x + 10] for x in range(0, len(list_regexps), 10)]
    # Set conflict counter to 0
    count_conflicts_regexps = 0

    # For each regex chunk
    for chunk in list_regex_chunks:
        # Convert to an OR statement
        chunk = re.compile(fr'({"|".join(chunk)})')
        # For each domain in gravity
        for domain in set_gravity_domains:
            # If it matches the regexp
            if re.search(chunk, domain):
                set_removal_domains.add(domain)
                count_conflicts_regexps += 1

    # If there were matches
    if count_conflicts_regexps > 0:
        print(f'[i] --> {count_conflicts_regexps} matches found in gravity')
        # Remove domains from gravity set
        set_gravity_domains.difference_update(set_removal_domains)
    else:
        print('[i] --> 0 matches found')
else:
    print('[i] --> No regexps found')

# If there are domains remaining post-processing and it's less than the the initial count
if set_removal_domains:

    if db_exists:
        print('[i] Prepping for DB update')

        # Split domains into chunks
        chunk_size = 1000
        list_removal_chunks = [list(set_removal_domains)[x:x + chunk_size] for x in range(0, len(set_removal_domains), chunk_size)]

        # For each chunk
        print('[i] Running deletions')
        for chunk in list_removal_chunks:
            c.executemany('DELETE FROM gravity '
                          'WHERE domain IN (?)', [(x,) for x in chunk])

        # Commit Changes
        conn.commit()

        # Query actual DB count
        c.execute('SELECT COUNT(DISTINCT domain) FROM gravity')
        print(f'[i] --> {c.fetchall()[0][0]} domains remain in the gravity database')

        conn.close()
    else:
        print('[i] Outputting updated gravity.list')

        # Output gravity set to gravity.list
        with open(path_legacy_gravity, 'w') as fWrite:
            for line in sorted(set_gravity_domains):
                fWrite.write(f'{line}\n')

        print(f'[i] --> {len(set_gravity_domains)} domains remain in gravity.list')

    print('[i] Restarting Pi-hole')
    subprocess.run(['pihole', 'restartdns', 'reload'], stdout=subprocess.DEVNULL)
else:
    print('[i] No optimisation required')