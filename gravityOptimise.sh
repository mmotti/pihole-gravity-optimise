#!/usr/bin/env bash
# shellcheck disable=SC2034  # Unused variables left for readability

# Set file variables
db_gravity='/etc/pihole/gravity.db'
dir_dnsmasq='/etc/dnsmasq.d'
file_gravity='/etc/pihole/gravity.list'
file_regex='/etc/pihole/regex.list'
usingDB=false

# Check for Pi-hole DB
if [[ -s "${db_gravity}" ]]; then
	echo '[i] Pi-hole DB detected'
	usingDB=true
fi

# Functions
function fetchTable {
	# Define local variables
	local table="${1}" queryStr
	# Set query string
	queryStr="Select domain FROM vw_${table};"
	# Run the query
	sqlite3 ${db_gravity} "${queryStr}" 2>&1
	# Check exit status
	status="$?"
	[[ "${status}" -ne 0 ]]  && { (>&2 echo '[i] An error occured whilst fetching results'); return 1; }

	return 0
}

function updateGravityDB {

	# Code here is adapted from /opt/pihole/gravity.sh

	local file_gravity_tmp="${1}" table='gravity'

	# Another conditional exit
	if [[ ! -s "${file_gravity_tmp}" ]]; then
		echo "[i] Unable to process ${file_gravity_tmp}"
		return 1
	fi

	# Truncate gravity table
	output=$( { sudo sqlite3 ${db_gravity} "DELETE FROM ${table}"; } 2>&1 )
	status="$?"

	[[ "${status}" -ne  0 ]] && echo '[i] Failed to truncate gravity DB' && return 1

	# Upload optimised gravity
	output=$( { printf ".mode csv\\n.import \"%s\" %s\\n" "${file_gravity_tmp}" "${table}" | sudo sqlite3 "${db_gravity}"; } 2>&1 )
	status="$?"

	[[ "${status}" -ne  0 ]] && echo '[i] Unable to load entries into gravity' && return 1

	return 0
}

# Update gravity
echo '[i] Updating gravity'
pihole updateGravity > /dev/null

# Conditional fetch for gravity domains
if [[ $usingDB == true ]]; then
	str_gravity=$(fetchTable "gravity")
else
	str_gravity=$(cat "${file_gravity}")
fi

# If a result is returned
if [[ -n "${str_gravity}" ]]; then
	# Make a temporary file
	file_gravity_tmp=$(mktemp --suffix=.gravity)
	# Output current gravity domains to temp file
	echo "${str_gravity}" > "${file_gravity_tmp}"
else
	echo '[i] No gravity domains were found'; exit 1;
fi

# Grab gravity count pre-processing
num_gravity_before=$(wc -l < "${file_gravity_tmp}")

# Identify existing local wildcards
echo '[i] Parsing existing wildcard config (DNSMASQ)'
existing_wildcards=$(find "${dir_dnsmasq}" -type f -name '*.conf' -print0 |
	xargs -r0 grep -hE '^address=\/.+\/(([0-9]{1,3}\.){3}[0-9]{1,3}|::|#)?$' |
		cut -d '/' -f2 |
			sort -u)

# If there are existing wildcards
if [[ -n "${existing_wildcards}" ]]; then
	echo '[i] Removing wildcard matches from gravity'
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
		echo "${str_gravity}" > "${file_gravity_tmp}"
	else
		echo '[i] 0 domains remain after wildcard removals'; exit 0;
	fi
fi

# Conditional fetch for regex filters
if [[ $usingDB == true ]]; then
	str_regex=$(fetchTable "regex")
else
	[[ -s "${file_regex}" ]] && str_regex=$(grep '^[^#]' "${file_regex}")
fi

# If there are regexps
if [[ -n "${str_regex}" ]]; then
	echo '[i] Removing regex matches from gravity'
	# Invert match regex
	str_gravity=$(grep -vEf <(echo "${str_regex}") "${file_gravity_tmp}")
	# Conditional exit
	if [[ -n "${str_gravity}" ]]; then
		echo "${str_gravity}" > "${file_gravity_tmp}"
	else
		echo '[i] 0 domains remain after regex removals'; exit 0;
	fi
fi

# Save changes to gravity
echo '[i] Updating gravity database'
# Conditional save for gravity
if [[ $usingDB == true ]]; then
	updateGravityDB "${file_gravity_tmp}"
else
	# Overwrite gravity.list
	sudo cp "${file_gravity_tmp}" "${file_gravity}"
	# Remove temp file
	rm -f "${file_gravity_tmp}"
fi

# Remove temp files
echo '[i] Removing temp files'
[[ -e "${file_gravity_tmp}" ]] && rm -f "${file_gravity_tmp}"

# Conditional fetch of updated gravity domains
if [[ $usingDB == true ]]; then
	str_gravity=$(fetchTable "gravity")
else
	str_gravity=$(cat "${file_gravity}")
fi

# Refresh pi-hole
echo "[i] Refreshing Pihole"
pihole restartdns reload > /dev/null

# Some stats
num_gravity_after=$(wc -l <<< "${str_gravity}")
echo "[i] $((num_gravity_before-num_gravity_after)) domains were removed from gravity"
echo "[i] ${num_gravity_after} domains remain in gravity"