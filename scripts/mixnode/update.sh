#!/bin/bash

###############
## VARIABLES ##
###############

nym_path=$1
node_path="$nym_path/mixnodes"
nym_node_id=$(find "$node_path" -mindepth 1 -maxdepth 1 -type d \
	-printf "%f\n" | head -n1)
nym_config_file=$node_path/$nym_node_id/config/config.toml
check_mark="\xE2\x9C\x93"
fail_x="\xE2\x9C\x97"
set_bold="\033[1m"
set_normal="\033[22m"
announce_ip=$(curl -4 ifconfig.me)
[ -z "$announce_ip" ] && announce_ip=$(curl ipinfo.io/ip)
#Load text into associative array
translations=$(jq -r ".\"$EXPLORE_NYM_LANG\"" $EXPLORE_NYM_PATH/../text/update.json)
if [[ "$translations" == "null" ]]; then
	echo -e "No translation for $EXPLORE_NYM_LANG available for this part of the" \
		"script, If you're able to translate the text displayed on the script" \
		"please contribute here https://github.com/ExploreNYM/bash-tool\n"
	translations=$(jq -r ".\"en-us\"" ../text/check-vps.json)
fi
declare -A text
while IFS=':' read -r key value; do
	key=$(echo "${key//\"/}" | xargs)
	value=$(echo "${value//\"/}" | xargs -0 | sed 's/,$//')
    text["$key"]="$value"
done <<< "$translations"

###############
## FUNCTIONS ##
###############

setup_binary() {
	binary_name="nym-mixnode"
	nym_url="https://github.com/nymtech/nym/releases/latest/download/$binary_name"

	echo "${text[checking]}"
	wget -q -O $binary_name "$nym_url"
	chmod u+x $binary_name
	installed_version=$(nym-mixnode --version 2> /dev/null | grep "Build Version" | awk '{print $3}')
	remote_version=$(./nym-mixnode --version 2> /dev/null | grep "Build Version" | awk '{print $3}')
	if [[ $installed_version == $remote_version ]]; then
		echo "${text[up_to_date]}"
		rm nym-mixnode
		sleep 2 ; exit
	else
		echo "${text[outdated]}" ; sleep 2
	fi
	sudo mv $binary_name /usr/local/bin/
}

init_binary() {
	nym-mixnode init --id $nym_node_id --host $announce_ip > ne-output.txt
}

display_status() {
	nym_version=$(grep "version" "$nym_config_file" | awk -F "'" '{print $2}')
	
	if [[ `service nym-mixnode status | grep active` =~ "running" ]]
	then
		$EXPLORE_NYM_PATH/display-logo.sh ; sleep 1
		echo -e "${set_bold}${text[updated]} $nym_version ${text[and]}\n$set_normal"
		sleep 2 ; sudo systemctl status nym-mixnode --no-pager
		echo -e "\n\n${text[restart]}"
		$EXPLORE_NYM_PATH/cleanup.sh
		sudo reboot
	else
		echo -e "$fail_x ${text[fail]}"
		sleep 10
		exit 1
	fi
}

##############################
## MAIN EXECUTION OF SCRIPT ##
##############################

$EXPLORE_NYM_PATH/display-logo.sh
echo -e "${set_bold}${text[welcome_message]}\n$set_normal"
setup_binary
sudo systemctl stop nym-mixnode
init_binary
sudo systemctl start nym-mixnode
display_status
