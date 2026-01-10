#!/bin/ksh

# This script sets up OpenBSD to run as a firewall
# It also uses a USB attached GPS dongle, model VK172 works just fine

# The dongle reports as: 
# umodem0 at uhub0 port 5 configuration 1 interface 0 "u-blox AG - www.u-blox.com u-blox 7 - GPS/GNSS Receiver" rev 1.10/1.00 addr 2


# Function to check the success of each command
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    else
        echo "Success: $1 completed"
    fi
}

# Function to check if username and password are set in /etc/hostname.pppoe0
check_pppoe_credentials() {
    # Extract authname and authkey values from the file
    authname=$(grep "authname" /etc/hostname.pppoe0 | awk '{print $2}')
    authkey=$(grep "authkey" /etc/hostname.pppoe0 | awk '{print $2}')
    
    # Prompt the user to input credentials if either authname or authkey is not set
    if [ -z "$authname" ] || [ "$authname" = "''" ]; then
        echo "PPPoE username (authname) is not set in /etc/hostname.pppoe0."
        echo -n "Please enter your PPPoE username: "
        read username
        # Update /etc/hostname.pppoe0 with the provided username
        sed -i "s/authname ''/authname '$username'/" /etc/hostname.pppoe0
        check_success "Updated PPPoE username in /etc/hostname.pppoe0"
    fi
    
    if [ -z "$authkey" ] || [ "$authkey" = "''" ]; then
        echo "PPPoE password (authkey) is not set in /etc/hostname.pppoe0."
        echo -n "Please enter your PPPoE password: "
        read password
        # Update /etc/hostname.pppoe0 with the provided password
        sed -i "s/authkey ''/authkey '$password'/" /etc/hostname.pppoe0
        check_success "Updated PPPoE password in /etc/hostname.pppoe0"
    fi

    echo "Success: PPPoE username and password are set in /etc/hostname.pppoe0"
}

# Function to add line to /etc/ttys

add_ldattach_to_ttys() {
    local FILE=/etc/ttys

    # This assumes that the GPS dongle is giving out PPS on the DCD pin:
    local LINE1='cuaU0   "/sbin/ldattach  -h -s 38400 -t !dcd nmea"   unknown on softcar'

    # Only uncomment this if you REALLY want two usb attached GPS devices, it's not adviseable
    # for accuracy reasons (OpenNTPD will average between them, so if one is massively out of
    # sync... Better to have a single GPS timing device on your USB bus
    # local LINE2='cuaU1   "/sbin/ldattach nmea"   unknown on softcar'

    # Process cuaU0
    if grep -Fxq "$LINE1" "$FILE"; then
        echo "Line already exists in $FILE: $LINE1"
    else
        echo "$LINE1" >> "$FILE"
        check_success "Added ldattach line to $FILE: $LINE1"
    fi

    # Process cuaU1
    if grep -Fxq "$LINE2" "$FILE"; then
        echo "Line already exists in $FILE: $LINE2"
    else
        echo "$LINE2" >> "$FILE"
        check_success "Added ldattach line to $FILE: $LINE2"
    fi
}

# Install necessary packages
pkg_add wget unzip
check_success "pkg_add wget unzip"

# Download the zip file using wget
wget https://github.com/p4rol/openbsd-setup/archive/refs/heads/main.zip
check_success "wget download of openbsd-setup"

# Unzip the downloaded file
unzip main.zip
check_success "unzip main.zip"

# Change directory to the unzipped folder
cd openbsd-setup-main
check_success "cd into openbsd-setup-main"

# Copy configuration files to /etc/
cp hostname.igc0 /etc/
check_success "cp hostname.igc0 to /etc/"

cp hostname.vlan10 /etc/
check_success "cp hostname.vlan10 to /etc/"

cp hostname.pppoe0 /etc/
check_success "cp hostname.pppoe0 to /etc/"

cp hostname.em0 /etc/
check_success "cp hostname.em0 to /etc/"

cp dhcpd.conf /etc/
check_success "cp dhcpd.conf to /etc/"

cp pf.conf /etc/
check_success "cp pf.conf to /etc/"

cp resolv.conf /etc/
check_success "cp resolv.conf to /etc/"

cp hosts /etc/
check_success "cp hosts to /etc/"

cp ping_watchdog.sh /root/ping_watchdog.sh
check_success "cp ping_watchdog.sh to /root/ping_watchdog.sh"

cp ntpd.conf /etc/
check_success "cp ntpd.conf to /etc/"

cp unbound.conf /var/unbound/etc/
check_success "cp unbound.conf to /var/unbound/etc/"

cp sshd_config /etc/ssh/
check_success "cp sshd_config to /etc/ssh/"

cp rc.local /etc/rc.local
check_success "cp rc.local /etc/rc.local"

# Call the function to add ldattach line to /etc/ttys
add_ldattach_to_ttys

# Append IP forwarding setting to sysctl.conf
echo 'net.inet.ip.forwarding=1' >> /etc/sysctl.conf
check_success "IP forwarding setting appended to /etc/sysctl.conf"

# Modify SSH port in sshd_config
sed -i 's/^#Port 22$/Port 22223/' /etc/ssh/sshd_config
check_success "SSH port changed to 22223 in /etc/ssh/sshd_config"

# Make sure dhcpd knows to run on igc0
rcctl set dhcpd flags igc0
check_success "rcctl set dhcpd flags igc0"

# Enable the dhcpd service 
rcctl enable dhcpd
check_success "rcctl enable dhcpd"

# Enable the unbound dns service
rcctl enable unbound
check_success "rcctl enable unbound"

# Enable the ntpd service 
rcctl enable ntpd
check_success "rcctl enable ntpd"

# Enable the apmd service 
rcctl enable apmd
check_success "rcctl enable apmd"

# Append apmd settings to the /etc/rc.conf.local configuration file
echo 'apmd_flags="-L" ' >> /etc/rc.conf.local
check_success "Append apmd settings to the /etc/rc.conf.local"

# Disbale the resolvd service, we don't want to use it
rcctl disable resolvd
check_success "rcctl disable resolvd"

# No dhcp client should be runnning on this host
rcctl disable dhcpleased
check_success "rcctl disable dhcpleased"

# No slaacd (i.e. ipv6 ) is requied, disable it
rcctl disable slaacd
check_success "rcctl disable slaacd"

# No MIDI or audio is required, disable it
rcctl disable sndiod
check_success "rcctl disable sndiod"

# Check if PPPoE username and password are set, and prompt the user if necessary
check_pppoe_credentials

# Add a cron job for ping_watchdog.sh
(crontab -l; echo "*/10 * * * * /root/ping_watchdog.sh -c 3 -i 3 -t 5") | crontab -
check_success "Added cron job for ping_watchdog.sh"

echo "All steps completed successfully."

echo "Reboot and test!"


# EOF
