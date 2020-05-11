# Optimise Pihole's gravity database

**11/05/2020 Update**

As of yesterday, Pi-hole V5 was released and with that came the move to a database. Due to the way that the domains are now stored (including duplicates if in multiple adlists), the database size not decreasing unless a VACUUM (db rebuild) is run after each optimisation (not efficient) and the fact that a gravity update undoes all of the changes by this script, it is no longer efficient to run. I will perhaps look to tackle this from a different angle in future, but, for now, this repo will be archived.

---

If you are making use of Pihole's [regex](https://github.com/mmotti/pihole-regex) filtering and/or DNSMASQ wildcards, then it's likely that your gravity domain table contains far more domains than necessary.

### What does the script do?
1. Identifies gravity table entries that do not match items in the regex table
1. Identifies gravity table entries that do not match items in any DNSMASQ conf files.
1. Creates a new, optimised gravity table

### Requirements
1. This script requires **Python 3.6+** in order to run. It has been written and tested on Raspbian Buster / DietPi.
2. The script must be run as root (sudo)


### Example Output ###
```
mmotti@ubuntu-server:~$ curl -sSl https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.py | sudo python3
[i] Root user detected
[i] Pi-hole path exists
[i] Updating gravity (this may take a little time)
[i] DB detected
[i] Fetching domains
[i] Connecting to /etc/pihole/gravity.db
[i] Querying DB for gravity domains
[i] --> 113,492 domains found
[i] Scanning /etc/dnsmasq.d for wildcards
[i] --> 35,877 wildcards found
[i] Identifying wildcard conflicts with gravity
[i] --> 41,467 conflicts found
[i] Fetching regexps
[i] --> 16 regexps found
[i] Checking for gravity matches
[i] --> 8,100 matches found in gravity
[i] Running deletions
[i] --> 59,438 domains remain in the gravity database
[i] Restarting Pi-hole
```

### Instructions
* All commands will need to be entered via Terminal (PuTTY or your SSH client of choice) after logging in.
* Each time `pihole -g` is ran, either through updates, automatic cron or manually, any entries that were previously removed by this script will be re-added so you will need to run it regularly.


#### Installations:
Update your list of available packages

`sudo apt-get update`

Make sure the following packages are installed:

`sudo apt-get install python3`

#### Running the optimisation

`curl -sSl https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.py | sudo python3`

#### Running on a schedule
Example cron job that runs each night at 02:45:

1. Edit the root user's crontab (`sudo crontab -u root -e`)

2. Enter the following:
```
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
45 2 * * * /usr/bin/curl -sSl https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.py | /usr/bin/python3
```
3. Save changes
