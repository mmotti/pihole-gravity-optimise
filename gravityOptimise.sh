#!/usr/bin/env bash

# Set file variables
file_gravity="/etc/pihole/gravity.list"
file_wildcards="/etc/dnsmasq.d/filter-lists.conf"
file_regex="/etc/pihole/regex.list"

pihole_update ()
{
	echo "#### Gravity List ####"
	echo "--> Updating gravity.list"
	pihole -g > /dev/null
	echo "--> $(wc -l < $file_gravity) gravity list entries"
}

process_regex ()
{
	echo "#### Regex Removals ####"

	# Only read it if it exists and is not empty
	if [ -s $file_regex ]; then
		regexList=$(sort -u $file_regex)
	else
		echo "--> Regex list is empty or does not exist."
		return 1
	fi

	# Status update
	echo "--> $(wc -l <<< "$regexList") regexps found"

	# Read the pihole gravity list
	echo "--> Reading gravity.list"

	# Only read it if it exists and is not empty
	if [ -s $file_out ]; then
		gravityList=$(sort -u $file_gravity)
	else
		echo "--> gravity.list is empty or does not exist"
		return 1
	fi

	# Status update
	echo "--> $(wc -l <<< "$gravityList") gravity.list entries"

	# Create empty variable to store garbage
	garbage_hosts=

	echo "--> Identifying unnecessary domains"

	# For each regex entry
	# Add any regex matches to an array
	while read -r regex; do
		garbage_hosts+=$(grep -E $regex $file_gravity)
	done <<< "$regexList"

	# Remove any duplicates from unnecessary hosts
	garbage_hosts=$(sort -u <<< "$garbage_hosts")

	# Status update
	echo "--> $(wc -l <<< "$garbage_hosts") unnecessary hosts identified"

	# Remove unnecessary entries
	echo "--> Removing unnecessary domains"
	cleaned_hosts=$(comm -23 <(echo "$gravityList") <(echo "$garbage_hosts"))

	# Status update
	echo "--> gravity.list: $(wc -l <<< "$cleaned_hosts")"

	# Output file
	echo "--> Outputting $file_gravity"
	echo "$cleaned_hosts" | sudo tee $file_gravity > /dev/null

	return 0
}

process_wildcards () {

	echo "#### Wildcard Removals ####"

	# Read the pihole gravity list
        echo "--> Reading gravity.list"
	gravity=$(sort $file_gravity)

	# Conditional exit
	if [ -z "$gravity.list" ]; then
		echo "--> There is an issue with gravity.list"
		return 1
	else
		echo "--> $(wc -l <<< "$gravity") domains in gravity.list"
	fi

	# Grab unique base domains from dnsmasq conf file
	echo "--> Fetching domains from $file_wildcards"
	domains=$(awk -F '/' '{print $2}' $file_wildcards | sort -u)

	# Conditional exit
	if [ -z "$domains" ]; then
		echo "--> No wildcards were captured from $file_wildcards"
		return 1
	else
		echo "--> $(wc -l <<< "$domains") wildcards in $file_wildcards"
	fi

	# Convert something.com to .something.com
	# Convert something.com to something.com.
	# for grep fixed-strings match
	echo "--> Fetching subdomains from $file_wildcards"
	dot_prefix=$(sed 's/^/\./g' <<< "$domains")
	dot_suffix=$(sed 's/$/\./g' <<< "$domains")
	# Perform fixed string match for subdomains
	echo "--> Identifying subdomains to remove from gravity.list"
	# Find all matches for .something.com
	sd_removal=$(grep -Ff <(echo "$dot_prefix") $file_gravity | sort)
	# Exclude matches for something.com.
	sd_removal=$(grep -vFf <(echo "$dot_suffix") <<< "$sd_removal" | sort)

	# If there are no subdomains to remove
	if [ -z "$sd_removal" ]; then
		echo "--> 0 subdomains detected"
	else
		# Status update
		echo "--> $(wc -l <<< "$sd_removal") subdomains to remove"

		# Remove subdomains from gravity array
		echo "--> Removing subdomains from gravity.list"
		gravity=$(comm -23 <(echo "$gravity") <(echo "$sd_removal"))
	fi

	# Remove base domains from gravity
	echo "--> Removing base domains from gravity.list"
	gravity=$(comm -23 <(echo "$gravity") <(echo "$domains"))

	# Status update
	echo "--> $(wc -l <<< "$gravity") domains in gravity.list"

	# Output gravity.list
	echo "$gravity" | sudo tee $file_gravity > /dev/null

	return 0
}

finalise () {

	echo "#### Finalise changes ####"

	# Refresh Pihole
	echo "--> Sending SIGHUP to Pihole"
	sudo killall -SIGHUP pihole-FTL

}

# Run gravity update
pihole_update
# Process regex removals
process_regex
# Process wildcard removals
process_wildcards
# Finish up
finalise
