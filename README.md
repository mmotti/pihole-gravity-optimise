# Optimise Pihole's gravity database

If you are making use of Pihole's [regex](https://github.com/mmotti/pihole-regex) filtering and/or DNSMASQ wildcards, then it's likely that your gravity domain table contains far more domains than necessary.

### What does the script do?
1. Identifies gravity table entries that do not match items in the regex table
1. Identifies gravity table entries that do not match items in any DNSMASQ conf files.
1. Creates a new, optimised gravity table

### Example Output ###
```
dietpi@DietPi:/mnt/dietpi_userdata$ sudo python3 test.py
[i] Root user detected
[i] Pi-hole path exists
[i] Updating gravity
[i] DB detected
[i] Fetching domains
[i] Connecting to /etc/pihole/gravity.db
[i] --> 113497 domains found
[i] Scanning /etc/dnsmasq.d for wildcards
[i] --> 37570 wildcards found
[i] Identifying wildcard conflicts with gravity
[i] --> 20275 conflicts found
[i] Fetching regexps
[i] --> 16 regexps found
[i] Checking for gravity matches
[i] --> 20553 matches found in gravity
[i] Prepping for DB update
[i] Running deletions
[i] --> 67389 domains remain in the gravity database
[i] Restarting Pi-hole
```

### Instructions
* All commands will need to be entered via Terminal (PuTTY or your SSH client of choice) after logging in.
* Each time `pihole -g` is ran, either through updates, automatic cron or manually, any entries that were previously removed by this script will be re-added so you will need to run it regularly.

### Requirements
1. This script requires **Python 3** in order to run. It has been written and tested on Raspbian Buster / DietPi.
2. You must also install the following module for Python: **pyahocorasick**
3. The script must be run as root (sudo)

### Installations:
Update your list of available packages

`sudo apt-get update`

Make sure the following packages are installed:

`sudo apt-get install python3 python3-pip python3-dev build-essential`

Make sure the following Python modules are installed:

`sudo pip3 install setuptools wheel`

Install the pyahocorasick Python module:

`sudo pip3 install pyahocorasick`

### Run the optimisation

`curl -sSl https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.py | sudo python3`

### Install and run optimisation locally

Download the script, copy it to `/usr/local/bin/` and give it execution permissions:
```
sudo bash
wget -qO /usr/local/bin/gravityOptimise.py https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.py
chmod +x /usr/local/bin/gravityOptimise.py
exit
```

#### Manually running the gravityOptimise script
Enter `sudo python3 /usr/local/bin/gravityOptimise.py` in Terminal


#### Create a Cron file (running on a schedule)
This example will run the script every morning at 03:45
1. `sudo nano /etc/cron.d/gravityOptimise`
2. Enter: `45 3 * * * root PATH="$PATH:/usr/local/bin/" /usr/bin/python3 /usr/local/bin/gravityOptimise.py`
3. Press `CTRL` + `X`
4. Press `Y`
5. Press `Enter`

#### Add entries back to gravity table
`pihole -g`

#### Removing the script
```
sudo rm -f /usr/local/bin/gravityOptimise.py
sudo rm -f /etc/cron.d/gravityOptimise
pihole -g
