#!/usr/bin/env bash

# Set file variables
file_gravity='/etc/pihole/gravity.list'
dir_dnsmasq='/etc/dnsmasq.d'
file_regex='/etc/pihole/regex.list'

# Update gravity.list
echo "[i] Updating gravity.list"
pihole updateGravity > /dev/null
num_gravity_before=$(cat $file_gravity | wc -l)

# Conditional exit if gravity.list is empty
[ ! -s "$file_gravity" ] && echo 'gravity.list is empty / not found' && exit

# Identify existing local wildcards
echo '[i] Parsing existing wildcard config (DNSMASQ)'
existing_wildcards=$(find $dir_dnsmasq -type f -name '*.conf' -not -name 'filter_lists.conf' -print0 |
	xargs -r0 grep -hE '^address=\/.+\/(([0-9]{1,3}\.){3}[0-9]{1,3}|::|#)?$' |
		cut -d '/' -f2 |
			sort -u)
			
if [ ! -z "$existing_wildcards" ]; then
	# If there are existing wildcards
	echo '[i] Removing wildcard matches in gravity.list'
	# Convert exact domains (pattern source) - something.com -> ^something.com$
	match_exact=$(sed 's/^/\^/;s/$/\$/' <<< "$existing_wildcards")
	# Convert wildcard domains (pattern source) - something.com - .something.com$
	match_wildcard=$(sed 's/^/\./;s/$/\$/' <<< "$existing_wildcards")
	# Convert target - something.com -> ^something.com$
    match_target=$(sed 's/^/\^/;s/$/\$/' <(cat $file_gravity))
	# Compile the exact and wildcard match patterns
	match_patterns=$(printf '%s\n' "$match_exact" "$match_wildcard")
	# Invert match patterns	
	new_gravity=$(grep -vFf <(echo "$match_patterns") <<< "$match_target" | sed 's/[\^$]//g')
	# Output to gravity.list
	echo "$new_gravity" | sudo tee $file_gravity > /dev/null
fi

if [ -s "$file_regex" ]; then
	echo '[i] Removing regex.list matches'
	# Remove comments from regex file
	regexps=$(grep '^[^#]' $file_regex)
	# Invert match regex.list
	new_gravity=$(grep -vEf <(echo "$regexps") $file_gravity)
	# Output to gravity.list
	echo "$new_gravity" | sudo tee $file_gravity > /dev/null
fi

# Some status
num_gravity_after=$(cat $file_gravity | wc -l)
echo "[i] $(($num_gravity_before-$num_gravity_after)) gravity.list entries removed"

# Refresh pi-hole
echo "[i] Sending SIGHUP to Pihole"
sudo killall -SIGHUP pihole-FTL