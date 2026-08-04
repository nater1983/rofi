#!/usr/bin/env bash
notify-send "Getting list of available Wi-Fi networks..."

connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
	toggle="睊  Disable Wi-Fi"
elif [[ "$connected" =~ "disabled" ]]; then
	toggle="直  Enable Wi-Fi"
fi

# Terse, colon-separated output -- stable regardless of field width/content.
# Escaped colons in SSIDs (nmcli escapes ':' as '\:') are left alone here.
wifi_list=$(nmcli -t --fields SECURITY,SSID device wifi list | \
	awk -F: '
		{
			ssid = $2
			for (i = 3; i <= NF; i++) ssid = ssid ":" $i  # rejoin if SSID had a colon
			if (ssid == "") next
			sec = $1
			icon = (sec == "" || sec == "--") ? "  " : "  "
			print icon ssid
		}
	' | awk '!seen[$0]++')   # dedupe by full display line, order-preserving

chosen_network=$(echo -e "$toggle\n$wifi_list" | rofi -dmenu -i -selected-row 1 -p "Wi-Fi SSID: ")
chosen_id=$(echo "${chosen_network:3}" | xargs)

if [ "$chosen_network" = "" ]; then
	exit
elif [ "$chosen_network" = "直  Enable Wi-Fi" ]; then
	nmcli radio wifi on
elif [ "$chosen_network" = "睊  Disable Wi-Fi" ]; then
	nmcli radio wifi off
else
	success_message="You are now connected to the Wi-Fi network \"$chosen_id\"."
	saved_connections=$(nmcli -g NAME connection)

	if [[ $(echo "$saved_connections" | grep -Fxw "$chosen_id") = "$chosen_id" ]]; then
		nmcli connection up id "$chosen_id" | grep "successfully" && notify-send "Connection Established" "$success_message"
	else
		security=$(nmcli -t --fields SECURITY,SSID device wifi list | awk -F: -v s="$chosen_id" '$2==s{print $1; exit}')
		if [[ -n "$security" && "$security" != "--" ]]; then
			wifi_password=$(rofi -dmenu -p "Password: ")
			nmcli device wifi connect "$chosen_id" password "$wifi_password" | grep "successfully" && notify-send "Connection Established" "$success_message"
		else
			nmcli device wifi connect "$chosen_id" | grep "successfully" && notify-send "Connection Established" "$success_message"
		fi
	fi
fi
