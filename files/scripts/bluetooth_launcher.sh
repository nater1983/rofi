#!/usr/bin/env bash

export SUDO_ASKPASS="/usr/bin/rofi-askpass.sh"

notify-send "Getting list of Bluetooth devices..."

# Bluetooth power state
power_state=$(sudo -A bluetoothctl show | grep "Powered:" | awk '{print $2}')
if [[ "$power_state" == "yes" ]]; then
	toggle="  Disable Bluetooth"
else
	toggle="  Enable Bluetooth"
fi

scan_btn="  Scan for Devices"

# Build device list: paired/connected devices always shown,
# plus anything currently visible in bluetoothctl's device cache
device_list=$(sudo -A bluetoothctl devices | while read -r _ mac name; do
	info=$(sudo -A bluetoothctl info "$mac")
	connected=$(echo "$info" | grep "Connected:" | awk '{print $2}')
	paired=$(echo "$info" | grep "Paired:" | awk '{print $2}')

	if [[ "$connected" == "yes" ]]; then
		icon="󰂱"      # connected icon -- paste real glyph
		color="#8BC34A"   # green
	elif [[ "$paired" == "yes" ]]; then
		icon=""      # paired-but-not-connected icon -- paste real glyph
		color="#FFEB3B"   # yellow
	else
		icon="󰂯"      # unpaired/discovered icon -- paste real glyph
		color="#9E9E9E"   # grey
	fi

	printf "<span foreground='%s'>%s  %s</span>\t%s\n" "$color" "$icon" "$name" "$mac"
done)

# Store MAC addresses keyed by display line so we can look them up after selection
display_lines=$(echo "$device_list" | cut -f1)
chosen_network=$(echo -e "$toggle\n$scan_btn\n$display_lines" | rofi -dmenu -i -markup-rows -selected-row 1 -p "Bluetooth: ")

if [ "$chosen_network" = "" ]; then
	exit
elif [[ "$chosen_network" == *"Enable Bluetooth"* ]]; then
	sudo -A bluetoothctl power on
elif [[ "$chosen_network" == *"Disable Bluetooth"* ]]; then
	sudo -A bluetoothctl power off
elif [[ "$chosen_network" == *"Scan for Devices"* ]]; then
	notify-send "Scanning for Bluetooth devices..."
	sudo -A bluetoothctl --timeout 5 scan on
	exec "$0"
else
	# Look up the MAC address matching the chosen display line
	chosen_mac=$(echo "$device_list" | awk -F'\t' -v line="$chosen_network" '$1==line{print $2}')
	chosen_name=$(echo "$chosen_network" | sed -E 's/<[^>]*>//g' | sed -E 's/^\S+\s+//' | xargs)

	if [ -z "$chosen_mac" ]; then
		notify-send "Bluetooth Error" "Could not resolve device address."
		exit 1
	fi

	info=$(sudo -A bluetoothctl info "$chosen_mac")
	connected=$(echo "$info" | grep "Connected:" | awk '{print $2}')
	paired=$(echo "$info" | grep "Paired:" | awk '{print $2}')

	if [[ "$connected" == "yes" ]]; then
		sudo -A bluetoothctl disconnect "$chosen_mac" && notify-send "Bluetooth" "Disconnected from \"$chosen_name\"."
	elif [[ "$paired" == "yes" ]]; then
		sudo -A bluetoothctl connect "$chosen_mac" && notify-send "Bluetooth" "Connected to \"$chosen_name\"."
	else
		sudo -A bluetoothctl pair "$chosen_mac" && sudo -A bluetoothctl trust "$chosen_mac" && sudo -A bluetoothctl connect "$chosen_mac" \
			&& notify-send "Bluetooth" "Paired and connected to \"$chosen_name\"."
	fi
fi
