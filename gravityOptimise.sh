#!/usr/bin/env bash

# Set file variables
file_gravity="/etc/pihole/gravity.list"
dir_wildcards="/etc/dnsmasq.d"
file_regex="/etc/pihole/regex.list"

pihole_update ()
{
	echo "#### Gravity List ####"
	echo "--> Updating gravity.list"
	pihole updateGravity > /dev/null
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

	# Check gravity.list is not empty
	if [ ! -s $file_gravity ]; then
		echo "--> gravity.list is empty or does not exist"
		return 1
	fi

	# Status update
	echo "--> $(wc -l < $file_gravity) gravity.list entries"

	echo "--> Identifying unnecessary domains"

	# For each regex entry
	# Add any regex matches to an array

	new_gravity=$(grep -vEf <(echo "$regexList") $file_gravity)

	if [ -z "$new_gravity" ] || [ $(wc -l <<< "$new_gravity") = 0 ]; then
		echo "--> No unnecessary domains were found"
		return 0
	fi

	# Status update
	echo "--> $(wc -l <<< "$new_gravity") unnecessary hosts identified"

	# Output file
	echo "--> Outputting $file_gravity"
	echo "$new_gravity" | sudo tee $file_gravity > /dev/null

	# Status update
	echo "--> $(wc -l <<< "$new_gravity") domains in gravity.list"

	return 0
}

process_wildcards () {

	echo "#### Wildcard Removals ####"

	# Grab unique base domains from dnsmasq conf files
        echo "--> Fetching domains from $dir_wildcards"
	domains=$(find $dir_wildcards -name "*.conf" -type f -print0 |
		xargs -r0 grep -hE "^address=\/.+\/(0\.0\.0\.0|::)?$" |
			awk -F'/' '{print $2}' |
				sort -u)

	 # Conditional exit
        if [ -z "$domains" ]; then
                echo "--> No wildcards were captured from $dir_wildcards"
                return 1
        fi

        echo "--> $(wc -l <<< "$domains") wildcards in $dir_wildcards"

	# Add ^ prefix and $ suffix to gravity (for comparison)
	echo "--> Processing $file_gravity"
	gravity_ps=$(sed 's/^/\^/g;s/$/\$/g' $file_gravity)

	# Conditional exit
	if [ -z "$gravity_ps" ]; then
		echo "--> There is an issue with gravity.list"
		return 1
	fi

	echo "--> $(wc -l <<< "$gravity_ps") domains in gravity.list"

	# Convert something.com to .something.com$
	# Convert something.com to ^something.com$
	# for grep fixed-strings match
	echo "--> Fetching removal criteria"
	w_domain=$(sed 's/^/\./g;s/$/\$/g' <<< "$domains")
	e_domain=$(sed 's/^/\^/g;s/$/\$/g' <<< "$domains")

	# Perform fixed string match for subdomains
	echo "--> Identifying domains to remove from gravity.list"

	# Find inverted matches for ^something.com$
	# Find inverted matches for something.com$
	# Remove prefix and suffix
	new_gravity=$(grep -vFf <(echo "$w_domain") <<< "$gravity_ps" |
	grep -vFf <(echo "$e_domain") |
	sed 's/[\^$]//g' |
	sort)

	# Status update
        removal_count=$(($(wc -l <<< "$gravity_ps")-$(wc -l <<< "$new_gravity")))

	# If there was an error populating new_gravity.list
	# Or there are no changes to be made
	if [ -z "$new_gravity" ] || [ $removal_count = 0 ]; then
		echo "--> No changes required."
		return 0
	fi

	# Status update
	echo "--> $removal_count unnecessary domains found"

	# Output gravity.list
	echo "--> Outputting $file_gravity"
	echo "$new_gravity" | sudo tee $file_gravity > /dev/null

	# Status update
        echo "--> $(wc -l <<< "$new_gravity") domains in gravity.list"

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
