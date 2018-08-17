#!/usr/bin/env bash

# Set gravity.list location
file_out="/etc/pihole/gravity.list"

# Set regex.list location
file_regex="/etc/pihole/regex.list"

# Read regex config
echo "--> Reading regex criteria"

# Only read it if it exists and is not empty
if [ -s $file_regex ]; then
	regexList=$(cat $file_regex | sort -u)
else
	echo "--> Regex list is empty or does not exist."
	exit
fi

# Status update
echo "--> $(wc -l <<< "$regexList") regexps found"

# Read the pihole gravity list
echo "--> Reading gravity.list"

# Only read it if it exists and is not empty
if [ -s $file_out ]; then
	gravityList=$(cat $file_out | sort -u)
else
	echo "--> gravity.list is empty or does not exist"
	exit
fi

# Status update
echo "--> $(wc -l <<< "$gravityList") gravity.list entries"

# Create empty variable to store garbage
garbage_hosts=

echo "--> Identifying unnecessary domains"

# For each regex entry
# Add any regex matches to an array
while read -r regex; do
	garbage_hosts+=$(grep -E $regex $file_out)
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
echo "--> Outputting $file_out"
echo "$cleaned_hosts" | sudo tee $file_out > /dev/null

# Refresh Pihole
echo "--> Sending SIGHUP to Pihole"
sudo killall -SIGHUP pihole-FTL
