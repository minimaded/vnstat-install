#!/bin/bash

set -eo pipefail

os_version() {
    osversion=$(cat /etc/os-release | grep VERSION_CODENAME | cut -f2 -d'=')
    case "$osversion" in
        buster | bullseye )
            echo "OS version is ${osversion}"
            echo
        ;;
        * )
            echo "OS version ${osversion} is not supported"
            echo
            install_notdone
        ;;
    esac
}

stop_clean() {
    if /bin/systemctl is-active -q vnstat.service ; then
        echo "Stopping vnstat.service"
        echo
        sudo /bin/systemctl stop vnstat.service || install_notdone
        sudo /bin/systemctl disable vnstat.service || install_notdone
    fi
}

get_vnstat() {

    for i in {1..60}; do
        if ping -c1 www.google.com &>/dev/null ; then
            break
        else
            echo "Waiting for an internet connection..."
            sleep 1
        fi
        if [ "${i}" -gt 59 ] ; then
            echo "Not connected to the internet..."
            echo
            install_notdone
        fi
    done

    echo "Getting vnstat 2.6..."
    echo
    sudo mkdir -p "/tmp/vnstat-install" || install_notdone
    sudo wget -q -O "/tmp/vnstat-install/vnstat-2.6-${osversion}.tar.gz" "https://github.com/minimaded/vnstat-install/raw/main/vnstat-2.6-${osversion}.tar.gz" || install_notdone
    sudo tar zxvf "/tmp/vnstat-install/vnstat-2.6-${osversion}.tar.gz" -C "/tmp/vnstat-install" || install_notdone
}

install_vnstat() {
    echo "Installing vnstat 2.6..."
    echo
    sudo cp -f "/tmp/vnstat-install/vnstat-2.6-${osversion}/examples/systemd/vnstat.service" "/etc/systemd/system/" || install_notdone
    sudo /usr/bin/install -c -m 644 "/tmp/vnstat-install/vnstat-2.6-${osversion}/man/vnstat.1" "/tmp/vnstat-install/vnstat-2.6-${osversion}/man/vnstati.1" "/usr/share/man/man1" || install_notdone
    sudo /usr/bin/install -c -m 644 "/tmp/vnstat-install/vnstat-2.6-${osversion}/man/vnstat.conf.5" "/usr/share/man/man5" || install_notdone
    sudo /usr/bin/install -c -m 644 "/tmp/vnstat-install/vnstat-2.6-${osversion}/man/vnstatd.8" "/usr/share/man/man8" || install_notdone
    sudo /usr/bin/install -c "/tmp/vnstat-install/vnstat-2.6-${osversion}/vnstat" "/usr/bin" || install_notdone
    sudo /usr/bin/install -c "/tmp/vnstat-install/vnstat-2.6-${osversion}/vnstatd" "/usr/sbin" || install_notdone

    if [ -f "/usr/share/man/man1/vnstatd.1" ] ; then sudo rm -f "/usr/share/man/man1/vnstatd.1"  || install_notdone ; fi
    sudo /usr/bin/mkdir -p "/etc"  || install_notdone
    /usr/bin/vnstat --showconfig | sudo -u root -g vnstat tee "/etc/vnstat.conf" || install_notdone
}

clear_vnstat() {
    echo "Cleaning vnstat..."
    echo
    sudo rm "/var/lib/vnstat/*" || install_notdone
    sudo rm -r "/tmp/vnstat-install" || install_notdone
}

enable_vnstat() {
    echo "Enabling vnstat..."
    echo
    sudo /bin/systemctl enable vnstat.service || install_notdone
    sudo /bin/systemctl start vnstat.service || install_notdone
    sudo -u vnstat /usr/bin/vnstatvnstat -i eth0 -u || install_notdone
    sudo -u vnstat /usr/bin/vnstatvnstat -i wlan0 -u || install_notdone
    sudo -u vnstat /usr/bin/vnstatvnstat -i wlan1 -u || install_notdone
}

install_done() {
    read -r -p < /dev/tty "Install completed, reboot? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            sudo reboot
    esac
    exit 0
}

install_notdone() {
    echo
    read -r -p < /dev/tty "Install failed, press any key to exit... " -n1 -s
    echo
    exit 1
}

os_version
stop_clean
get_vnstat
install_vnstat
clear_vnstat
enable_vnstat
install_done
