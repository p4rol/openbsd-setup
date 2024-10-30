#!/bin/ksh

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
cp hostname.axen0 /etc/
check_success "cp hostname.axen0 to /etc/"

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
check_seccess "cp sshd_conf to /etc/ssh/"

# Append IP forwarding setting to sysctl.conf
echo 'net.inet.ip.forwarding=1' >> /etc/sysctl.conf
check_success "IP forwarding setting appended to /etc/sysctl.conf"

# Modify SSH port in sshd_config
sed -i 's/^#Port 22$/Port 22223/' /etc/ssh/sshd_config
check_success "SSH port changed to 22223 in /etc/ssh/sshd_config"

# Enable/disable services using rcctl
rcctl enable dhcpd
check_success "rcctl enable dhcpd"

rcctl enable unbound
check_success "rcctl enable unbound"

rcctl enable ntpd
check_success "rcctl enable ntpd"

rcctl disable resolvd
check_success "rcctl disable resolvd"

# Check if PPPoE username and password are set, and prompt the user if necessary
check_pppoe_credentials

# Add a cron job for ping_watchdog.sh
(crontab -l; echo "*/10 * * * * /root/ping_watchdog.sh -c 3 -i 3 -t 5") | crontab -
check_success "Added cron job for ping_watchdog.sh"

echo "All steps completed successfully."
