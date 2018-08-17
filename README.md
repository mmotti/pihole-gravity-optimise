# Optimise Pihole's gravity.list

The release of Pihole v4 introduces the ability to apply regex filtering alongside standard domain name blocking.

Depending on your [regex entries](https://github.com/mmotti/pihole-regex), it could be that you currently have a significant amount of unnecessary domains in your `gravity.list` file (collation of domains from your host providers).

### Example

`^(.+[-_.])??ad[sxv]?[0-9]*[-_.]` matches **19,268** unnecessary entries in my `gravity.list` file.

**Sample matches:**

```
ads.thumbr.com
ads.thzhost.com
ads.tibaco.net
ads.timesdaily.com
ads.timesink.com
ads.timesunion.com
```

### What does the script do?
1. Extracts the entries from your `regex.list` and `gravity.list` files
1. Runs each regex match against the `gravity.list`
1. Removes matches from `gravity.list`
1. Refreshes Pihole config

### Instructions
1. All commands will need to be entered via Terminal (PuTTY or your SSH client of choice) after logging in. 
1. Each time `pihole -g` is ran, either through updates, automatic cron or manually, any entries that were previously removed by this script will be re-added.

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
