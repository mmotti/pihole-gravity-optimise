#!/usr/bin/env bash
# shellcheck disable=SC2034  # Unused variables left for readability

# Set file variables
db_gravity='/etc/pihole/gravity.db'
dir_dnsmasq='/etc/dnsmasq.d'
file_gravity_tmp='/etc/pihole/gravity.list.tmp'

# Functions
function fetchTable {

	local table queryStr

	table="${1}"
	queryStr="Select domain FROM vw_${table};"

	sqlite3 ${db_gravity} "${queryStr}"

	return
}

function updateGravity {

	# Code here is adapted from /opt/pihole/gravity.sh

	local file_gravity_tmp table

	file_gravity_tmp="${1}"
	table='gravity'

	# Another conditional exit
	if [[ ! -e "${file_gravity_tmp}" ]] || [[ ! -s "${file_gravity_tmp}" ]]; then
		echo "[i] Unable to process ${file_gravity_tmp}"
		exit 1
	fi

	# Truncate gravity table
	output=$( { sudo sqlite3 ${db_gravity} "DELETE FROM ${table}"; } 2>&1 )
	status="$?"

	[[ "${status}" -ne  0 ]] && echo '[i] Failed to truncate gravity DB' && exit 1

	# Upload optimised gravity
	output=$( { printf ".mode csv\\n.import \"%s\" %s\\n" "${file_gravity_tmp}" "${table}" | sudo sqlite3 "${db_gravity}"; } 2>&1 )
	status="$?"

	[[ "${status}" -ne  0 ]] && echo '[i] Unable to load entries into gravity' && exit 1

	# Remove temp gravity file
	sudo rm -f "${file_gravity_tmp}"

	return
}

# Conditional exit
if [[ ! -e "${db_gravity}" ]] || [[ ! -s "${db_gravity}" ]]; then
	echo '[i] You have not yet migrated to the pi-hole database. Please run the old script.'; exit 1
fi

# Update gravity.list
echo '[i] Updating gravity.list'
pihole updateGravity > /dev/null

# Save gravity to temp file
str_gravity=$(fetchTable "gravity")

# Output if result returned
if [[ -n "${str_gravity}" ]]; then
	echo "${str_gravity}" | sudo tee "${file_gravity_tmp}" > /dev/null
else
	echo '[i] No results returned from gravity db'; exit 1;
fi

# Save regex in str
str_regex=$(fetchTable "regex")

# Grab gravity count pre-processing
num_gravity_before=$(wc -l < "$file_gravity_tmp")

# Identify existing local wildcards
echo '[i] Parsing existing wildcard config (DNSMASQ)'
existing_wildcards=$(find "${dir_dnsmasq}" -type f -name '*.conf' -print0 |
	xargs -r0 grep -hE '^address=\/.+\/(([0-9]{1,3}\.){3}[0-9]{1,3}|::|#)?$' |
		cut -d '/' -f2 |
			sort -u)

if [[ -n "${existing_wildcards}" ]]; then
	# If there are existing wildcards
	echo '[i] Removing wildcard matches in gravity.list'
	# Convert exact domains (pattern source) - something.com -> ^something.com$
	match_exact=$(sed 's/^/\^/;s/$/\$/' <<< "${existing_wildcards}")
	# Convert wildcard domains (pattern source) - something.com - .something.com$
	match_wildcard=$(sed 's/^/\./;s/$/\$/' <<< "${existing_wildcards}")
	# Convert target - something.com -> ^something.com$
	match_target=$(sed 's/^/\^/;s/$/\$/' "${file_gravity_tmp}")
	# Compile the exact and wildcard match patterns
	match_patterns=$(printf '%s\n' "${match_exact}" "${match_wildcard}")
	# Invert match patterns
	str_gravity=$(grep -vFf <(echo "${match_patterns}") <<< "${match_target}" | sed 's/[\^$]//g')

	# Conditional exit
	if [[ -n "${str_gravity}" ]]; then
		echo "${str_gravity}" | sudo tee "${file_gravity_tmp}" > /dev/null
	else
		echo '[i] 0 domains remain after wildcard removals'; exit 0;
	fi
fi

if [[ -n "${str_regex}" ]]; then
	echo '[i] Removing regex.list matches'
	# Remove comments from regex file
	regexps=$(grep '^[^#]' <<< "${str_regex}")
	# Invert match regex.list
	str_gravity=$(grep -vEf <(echo "${regexps}") <(echo "{$str_gravity}"))

	# Conditional exit
	if [[ -n "${str_gravity}" ]]; then
		echo "${str_gravity}" | sudo tee "${file_gravity_tmp}" > /dev/null
	else
		echo '[i] 0 domains remain after regex removals'; exit 0;
	fi
fi

# Update gravity DB
echo '[i] Updating gravity table'
updateGravity "${file_gravity_tmp}"

# Some status
str_gravity=$(fetchTable "gravity")
num_gravity_after=$(wc -l <<< "${str_gravity}")
echo "[i] $((num_gravity_before-num_gravity_after)) gravity entries removed"

# Refresh pi-hole
echo "[i] Sending SIGHUP to Pihole"
sudo killall -SIGHUP pihole-FTL
