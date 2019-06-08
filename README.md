# Optimise Pihole's gravity database

If you are making use of Pihole's [regex](https://github.com/mmotti/pihole-regex) filtering and/or DNSMASQ wildcards, then it's likely that your gravity domain table contains far more domains than necessary.

### What does the script do?
1. Identifies gravity table entries that do not match items in the regex table
1. Identifies gravity table entries that do not match items in any DNSMASQ conf files.
1. Creates a new, optimised gravity table

### Example Output ###
```
pi@raspberrypi:~ $ gravityOptimise.sh
[i] Pi-hole DB detected
[i] Updating gravity
[i] Parsing existing wildcard config (DNSMASQ)
[i] Removing wildcard matches from gravity
[i] Removing regex matches from gravity
[i] Updating gravity database
[i] Removing temp files
[i] Refreshing Pihole
[i] 55205 domains were removed from gravity
[i] 58103 domains remain in gravity
```

### Instructions
* All commands will need to be entered via Terminal (PuTTY or your SSH client of choice) after logging in. 
* Each time `pihole -g` is ran, either through updates, automatic cron or manually, any entries that were previously removed by this script will be re-added so you will need to run it regularly.

#### Installation
Download the script, copy it to `/usr/local/bin/` and give it execution permissions:
```
sudo bash
wget -qO /usr/local/bin/gravityOptimise.sh https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.sh
chmod +x /usr/local/bin/gravityOptimise.sh
exit
```

#### Manually running the gravityOptimise script
Enter `gravityOptimise.sh` in Terminal


#### Create a Cron file (running on a schedule)
This example will run the script every morning at 03:45
1. `sudo nano /etc/cron.d/gravityOptimise`
2. Enter: `45 3   * * *   root    PATH="$PATH:/usr/local/bin/" gravityOptimise.sh`
3. Press `CTRL` + `X`
4. Press `Y`
5. Press `Enter`

#### Add entries back to gravity table
`pihole -g`

#### Removing the script
```
sudo rm -f /usr/local/bin/gravityOptimise.sh
sudo rm -f /etc/cron.d/gravityOptimise
pihole -g
