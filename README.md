# Optimise Pihole's gravity database

If you are making use of Pihole's [regex](https://github.com/mmotti/pihole-regex) filtering and/or DNSMASQ wildcards, then it's likely that your `gravity` table contains far more domains than necessary.

### What does the script do?
1. Identifies `gravity` table entries that do not match items in the `regex` table
1. Identifies `gravity` table entries that do not match items in any `DNSMASQ` conf files.
1. Creates a new, optimised `gravity` table

### Example Output ###
```
pi@raspberrypi:~ $ gravityOptimise.sh
[i] Pi-hole DB detected
[i] Updating gravity.list
[i] Parsing existing wildcard config (DNSMASQ)
[i] Removing wildcard matches in gravity.list
[i] Removing regex.list matches
[i] Updating gravity table
[i] 57471 gravity entries removed
[i] Sending SIGHUP to Pihole
```

### Instructions
* All commands will need to be entered via Terminal (PuTTY or your SSH client of choice) after logging in. 
* Each time `pihole -g` is ran, either through updates, automatic cron or manually, any entries that were previously removed by this script will be re-added.

#### Installation
```
bash
wget -qO /usr/local/bin/gravityOptimise.sh https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.sh
chmod +x /usr/local/bin/gravityOptimise.sh
exit
```

#### Manually running the gravityOptimise script
`gravityOptimise.sh`


#### Sample cron file
`45 3   * * 7   root    PATH="$PATH:/usr/local/bin/" gravityOptimise.sh`

#### Add entries back to `gravity` table
`pihole -g`

#### Removing the script
```
sudo rm -f /usr/local/bin/gravityOptimise.sh
pihole -g
```