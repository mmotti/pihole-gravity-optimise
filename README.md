# Optimise Pihole's gravity.list

If you are making use of Pihole's [regex](https://github.com/mmotti/pihole-regex) filtering and/or DNSMASQ wildcards, then it's likely that your `gravity.list` contains far more domains than necessary.

### Example

**Regex:**

`^(.+[-_.])??ad[sxv]?[0-9]*[-_.]` matches **19,268** unnecessary entries in my `gravity.list` file.

**DNSMASQ Wildcard:**

`address=/302br.net/0.0.0.0` matches **16,327** unnecessary entries in my `gravity.list` file.

### What does the script do?
1. Identifies `gravity.list` entries that do not match items in your `regex.list`
1. Identifies `gravity.list` entries that do not match items in any `DNSMASQ` conf files.
1. Creates a new, optimised `gravity.list`



### Instructions
* All commands will need to be entered via Terminal (PuTTY or your SSH client of choice) after logging in. 
* Each time `pihole -g` is ran, either through updates, automatic cron or manually, any entries that were previously removed by this script will be re-added.

#### Installation
```
sudo bash
wget -qO /usr/local/bin/gravityOptimise.sh https://raw.githubusercontent.com/mmotti/pihole-gravity-optimise/master/gravityOptimise.sh
chmod +x /usr/local/bin/gravityOptimise.sh
exit
```

#### Sample cron file
`45 3   * * 7   root    PATH="$PATH:/usr/local/bin/" gravityOptimise.sh`

#### Manually running the gravityOptimise script
`gravityOptimise.sh`

#### Add entries back to `gravity.list`
`pihole -g`

#### Removing the script
```
sudo rm -f /usr/local/bin/gravityOptimise.sh
pihole -g
```