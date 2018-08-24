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

	# Grab unique base domains from dnsmasq conf file
        echo "--> Fetching domains from $file_wildcards"
        domains=$(awk -F '/' '{print $2}' $file_wildcards)

        # Conditional exit
        if [ -z "$domains" ]; then
                echo "--> No wildcards were captured from $file_wildcards"
                return 1
        fi

        echo "--> $(wc -l <<< "$domains") wildcards in $file_wildcards"

	# Read the pihole gravity list
        echo "--> Reading gravity.list"
	gravity=$(cat $file_gravity)

	# Conditional exit
	if [ -z "$gravity.list" ]; then
		echo "--> There is an issue with gravity.list"
		return 1
	fi

	echo "--> $(wc -l <<< "$gravity") domains in gravity.list"

	# Convert something.com to something.com$
	# Convert something.com to ^something.com$
	# for grep fixed-strings match
	echo "--> Fetching removal criteria from $file_wildcards"
	w_domain=$(sed 's/$/\$/g' <<< "$domains")
	e_domain=$(sed 's/^/\^/g;s/$/\$/g' <<< "$domains")

	# Add ^ prefix and $ suffix to gravity (for comparison)
	gravity_ps=$(sed 's/^/\^/g;s/$/\$/g' $file_gravity)

	# Perform fixed string match for subdomains
	echo "--> Identifying subdomains to remove from gravity.list"

	# Find inverted matches for ^something.com$
	# Find inverted matches for something.com$
	# Remove prefix and suffix
	new_gravity=$(grep -vFf <(echo "$e_domain") <<< "$gravity_ps" |
	grep -vFf <(echo "$w_domain") |
	sed 's/^\^//g;s/\$$//g' |
	sort)

	# If there was an error populating new_gravity.list
	if [ -z "$new_gravity" ]; then
		echo "--> An issue occured when recreating gravity.list"
		return 1
	fi

	# Status update
	removal_count=$(($(wc -l <<< "$gravity_ps")-$(wc -l <<< "$new_gravity")))
	echo "--> $removal_count unnecessary domains found"

	# Status update
	echo "--> $(wc -l <<< "$new_gravity") domains in gravity.list"

	# Output gravity.list
	echo "--> Outputting $file_gravity"
	echo "$new_gravity" | sudo tee $file_gravity > /dev/null

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
