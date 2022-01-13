#!/bin/bash

set -eo pipefail

do_all() {
    internet_check
    vnstat_current
    vnstat_install
    vnstat_current
    _done
}

_colors() {
    ansi_red="\033[0;31m"
    ansi_green="\033[0;32m"
    ansi_yellow="\033[0;33m"
    ansi_raspberry="\033[0;35m"
    ansi_error="\033[1;37;41m"
    ansi_reset="\033[m"
}

_status() {
    case $1 in
        0)
        echo -e "[$ansi_green \u2713 ok $ansi_reset] $2"
        ;;
        1)
        echo -e "[$ansi_red \u2718 error $ansi_reset] $ansi_error $2 $ansi_reset"
        _notdone
        ;;
        2)
        echo -e "[$ansi_yellow \u26a0 warning $ansi_reset] $2"
        ;;
    esac
}

_done() {
    echo
    read -r -p < /dev/tty "Completed, reboot? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            sudo reboot
    esac
    echo
    exit 0
}

_notdone() {
    echo
    read -r -p < /dev/tty "Failed, press any key to exit... " -n1 -s
    echo
    exit 1
}

internet_check() {
    for i in {1..60}; do
        if ping -c1 www.google.com &>/dev/null ; then
            break
        else
            echo "Waiting for an internet connection..."
            sleep 1
        fi
        if [ "${i}" -gt 59 ] ; then
            _status 2 "Not connected to the internet, waiting..."
            echo
            _status 1 "Unable to connect to the internet"
        fi
    done
}

vnstat_current() {
    vnstat_version="${dpkg-query -l | grep "vnstat" | tr -s " " | cut -d " " -f 3}"
    case "${vnstat_version}" in
        '' )
            echo "vnStat ${vnstat_version} installed..."
        ;;
        * )
            echo "vnStat not installed..."
        ;;
    esac
}

vnstat_install() {
    sudo wget -q -O "/tmp/vnstat_2.6-3_armhf_buster.deb" "https://raw.githubusercontent.com/minimaded/vnstat-install/main//vnstat_2.6-3_armhf_buster.deb" || _status 1 "Unable to download vnStat"
    sudo dpkg -i "/tmp/vnstat_2.6-3_armhf.deb" || _status 1 "Failed to install vnStat"
    sudo apt-get -f install || _status 1 "Failed to install dependencies"
    sudo rm "/tmp/vnstat_2.6-3_armhf.deb" || _status 1 "Failed to remove deb pakage"
}

do_all
