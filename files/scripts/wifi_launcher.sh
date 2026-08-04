#!/usr/bin/env bash

notify-send "Getting list of available Wi-Fi networks..."

nmcli device wifi rescan 2>/dev/null
sleep 2

connected=$(nmcli -fields WIFI g)
if [[ "$connected" =~ "enabled" ]]; then
	toggle="睊  Disable Wi-Fi"
elif [[ "$connected" =~ "disabled" ]]; then
	toggle="直  Enable Wi-Fi"
fi

# Build colored list using terse output (stable field parsing) + signal-based color/bars
wifi_list=$(nmcli -t --fields SECURITY,SIGNAL,SSID device wifi list | \
	awk -F: '
		{
			ssid = $3
			for (i = 4; i <= NF; i++) ssid = ssid ":" $i   # rejoin SSID if it contained a colon
			if (ssid == "") next

			sec = $1
			if (sec == "" || sec == "--") {
				icon = ""      # open network icon
			} else {
				icon = ""      # locked network icon
		
			signal = $2 + 0

			icon = (sec == "" || sec == "--") ? "直" : "睊"

			# Bars: 4-level block indicator based on signal strength
			if (signal >= 80) { bars = "▂▄▆█"; color = "#8BC34A" }       # excellent - green
			else if (signal >= 60) { bars = "▂▄▆_"; color = "#FFEB3B" } # good - yellow
			else if (signal >= 40) { bars = "▂▄__"; color = "#FF9800" } # fair - orange
			else { bars = "▂___"; color = "#E91E63" }                   # weak - pink/red

			printf "<span foreground=\x27%s\x27>%s  %-4s %3d%%  %s</span>\n", color, icon, bars, signal, ssid
		}
	' | awk '!seen[$0]++')

# Use rofi to select wifi network (markup-rows enables the Pango color spans)
chosen_network=$(echo -e "$toggle\n$wifi_list" | rofi -dmenu -i -markup-rows -selected-row 1 -p "Wi-Fi SSID: ")

# Strip Pango markup, then strip icon/bars/percent columns to get the plain SSID
chosen_id=$(echo "$chosen_network" | sed -E 's/<[^>]*>//g' | sed -E 's/^\S+\s+\S+\s+[0-9]+%\s+//' | xargs)

if [ "$chosen_network" = "" ]; then
	exit
elif [[ "$chosen_network" == *"Enable Wi-Fi"* ]]; then
	nmcli radio wifi on
elif [[ "$chosen_network" == *"Disable Wi-Fi"* ]]; then
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
