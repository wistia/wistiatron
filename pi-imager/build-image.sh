#!/usr/bin/env sh

RASPBIAN_URL=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/2019-09-26-raspbian-buster  .zip
RASPBIAN_ARCHIVE=$(echo $RASPBIAN_URL | sed 's:.*/\(.*\):\1:')
RASPBIAN_IMAGE=$(echo $RASPBIAN_ARCHIVE | sed 's:\(.*\)\.zip:\1.img:')

if [ -e ./$RASPBIAN_IMAGE ]
then
  echo "Raspbian image found."
else
  echo "Raspbian image not found."

  if [ -e ./$RASPBIAN_ARCHIVE ]
  then
    echo "Raspbian archive found."
  else
    echo "Raspbian archive not found. Downloading..."
    curl -L -o ./$RASPBIAN_ARCHIVE $RASPBIAN_URL
  fi
fi


echo "Please flash your SD card with ./${RASPBIAN_IMAGE} using a tool like Etcher.io."
echo "When done, ensure the flashed SD card is mounted."
read -p "Press [Enter] to continue."

echo "Enter target wifi network: "
read WIFI_NETWORK
echo "Enter target wifi password: "
read WIFI_PASSWORD

echo "Enabling SSH..."
touch /Volumes/boot/ssh
echo "Done."

echo "Configuring wifi..."
cat >/Volumes/boot/wpa_supplicant.conf <<EOS
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
country=US
update_config=1
ap_scan=1
network={
  ssid="${WIFI_NETWORK}"
  psk="${WIFI_PASSWORD}"
}
EOS
echo "Done."

echo "Configuration complete. Please eject your SD card."

echo "You can look for your Raspberry Pi on your network with:"
echo "    ping -c 1 google.com &> /dev/null ; arp -a | grep b8:27"
echo " or sudo nmap -sP 10.0.1.0/24 | awk '/^Nmap/{ip=\$NF}/B8:27:EB/{print ip}'"