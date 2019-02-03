#!/bin/bash

# The purpose of this script is to setup the required components for the F5
# automation lab Linux server
#
# This script is processed by cfn-init and will be run as root.
#
# You can monitor the progress of the packages install through
# /var/log/cfn-init-cmd.log. Here you will see all the different commands run
# from the Cloud Formation Template and through this script
#
# It takes approx. 5 min to have the instance fully setup

#ifconfig eth0 10.1.10.100 netmask 255.255.255.0
#ifconfig eth0:1 10.1.10.101 netmask 255.255.255.0
#ifconfig eth0:2 10.1.10.102 netmask 255.255.255.0 
#ifconfig eth0:3 10.1.10.103 netmask 255.255.255.0
#ifconfig eth0:4 10.1.10.252 netmask 255.255.255.0
#ifconfig eth1 10.1.1.250 netmask 255.255.255.0
#ifconfig eth1:1 10.1.1.15 netmask 255.255.255.0

touch /home/ubuntu/alert3-server-install-started-wait-about-10-15min

# Disable SSH Host Key Checking for hosts in the lab
#touch /home/ubuntu/.ssh/config
#cat << 'EOF' >> /home/ubuntu/.ssh/config
#
#Host 10.1.*.*
#   StrictHostKeyChecking no
#   PasswordAuthentication yes
#   UserKnownHostsFile /dev/null
#   LogLevel ERROR
#
#EOF
#chown ubuntu:ubuntu /home/ubuntu/.ssh/config
#chmod 600 /home/ubuntu/.ssh/config


touch /home/ubuntu/.ssh/authorized_keys
cat << 'EOF' >> /home/ubuntu/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDah5XZB0Hqq4akWavsvanbGY19yhVDOkW6VGqr1+PvOmtAH5Wf+YBRyldBOoVDgybMX9Mqw6FAbRYlV9qOR5/HqnKmYuFYmtZmaqbi7fQGE5q0+1s1LVv6nKMHjhWdu39R3lmbDIV701Apt/PnEqmYLx7WlJd88imG86SZEZ79dMhgVwXNsGKdcbcWhyk20bCliTqv+M7gkqWs3ZhlfcA9i3OdGd27gOvtIF66YeOzNCfyQA3eAuGnGZ721e2THPpYCfB20iXHuqi5mRWUXp8VuZ4sTWsF6ZX6Ro6AEenezWP/2eQU6U2RlQfPkSQ2uLovkiYg7MQMis1LYIP9qtQB ubntuserver1
EOF
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys


# Modify SSH to listen only on specific address (optional)
#SERVER_ETH1=`ifconfig eth1 | egrep 'inet addr' | awk '{print tolower($2)}' | awk -F: '{print tolower($2)}'`
#sleep 2
# Change ListenAddress
# sudo sed -i "s/0\.0\.0\.0/$SERVER_ETH1/g" /etc/ssh/ssh_config

# Install some util or ensure latest version

apt-get update
apt-get -y install telnet
apt-get -y instally curl
#Install Apache Bench
apt-get -y install apache2-utils
sleep 2

# Install dnsmasq
apt-get install -y dnsmasq
# these entries are added in template file
#cat << 'EOF' > /etc/dnsmasq.d/f5lab
#listen-address=127.0.0.1,10.1.10.100,10.1.10.101,20.1.10.102,10.1.10.103,10.1.10.252,10.1.1.250,10.1.1.15
#no-dhcp-interface=lo0,eth0,eth0:1,eth0:2,eth0:3,eth0:4,eth1,eth1:1
#EOF
systemctl enable dnsmasq.service
service dnsmasq start

# Install ubuntu docker
#apt-get install -y docker.io
#sleep 2

# Install official docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get install -y docker-ce
sleep 3
apt-get install -y docker-compose
sleep 3
		

	
#Create new lab users
# quietly add user without passwords
adduser --quiet --disabled-password --shell /bin/bash --home /home/f5student --gecos "f5student" f5student
adduser --quiet --disabled-password --shell /bin/bash --home /home/external_user --gecos "external_user" f5student
sleep 5
# set passwords
echo "f5student:supernetops" | chpasswd
echo "external_user:supernetops" | chpasswd
sleep 1

#Change the ubuntu user prompt
sudo sed -i 's|#force_color_prompt|force_color_prompt|g' /home/ubuntu/.bashrc
sleep 2
sudo sed -i 's|01;31m|01;39m|g' /home/ubuntu/.bashrc
sleep 2
sudo sed -i 's|01;32m|01;39m|g' /home/ubuntu/.bashrc
sleep 2
sudo sed -i 's|\\u@\\h|\\u@server1_\\h|g' /home/ubuntu/.bashrc
sleep 2

# Set shutdown daily at midnight - type 'shutdown -c' to cancel
cat << 'EOF' >> /etc/crontab
55 23 * * * root shutdown -h 5

EOF

sleep 5

# Start the Docker containers
cat << 'EOF' >> /etc/rc.local

## Add Web App firewall testing sites
#DamnSmallVulenerableWeb - Jumphost has installer [.py] pointing to ASM VIP
#docker run  -d -p 8008:8000 --restart always -it appsecco/dsvw
docker run -d -p 80:8000 --restart always --name dsvm_f5lab -it gbbaus17/dsvw
#Webgoat
docker run -d -p 8081:8080 -p 81:80 --restart always --name webgoat_f5lab -it danmx/docker-owasp-webgoat
#sudo docker run -d -p 8011:8080 --restart always --name webgoat_f5lab webgoat/webgoat-8.0
#DVWA
docker run -d -p 8082:3306 -p 82:80 --restart always --name dvwa_f5lab -e MYSQL_PASS="supernetops" -it citizenstig/dvwa
#Hackazon
docker run  -d -p 83:80 --restart always --name hackazon_f5lab -it mutzel/all-in-one-hackazon
#App-Sec https://github.com/ArtiomL/f5-app-sec
docker run -d -p 443:8443 --restart always --name f5appsec_f5lab -it artioml/f5-app-sec
## Add Standard Websites for LB Tests
docker run -d -p 8440:443 -p 8000:80 --restart always --name red_f5lab -e F5DEMO_APP=website -e F5DEMO_COLOR=FF0000 -e F5DEMO_NODENAME='Red' -it f5devcentral/f5-demo-httpd
docker run -d -p 8441:443 -p 8001:80 --restart always --name green_f5lab -e F5DEMO_APP=website -e F5DEMO_COLOR=33FF33 -e F5DEMO_NODENAME='Green' -it f5devcentral/f5-demo-httpd
docker run -d -p 8442:443 -p 8002:80 --restart always --name blue_f5lab -e F5DEMO_APP=website -e F5DEMO_COLOR=3333FF -e F5DEMO_NODENAME='Blue' -it f5devcentral/f5-demo-httpd

EOF

sleep 5


# Things are created as root, need to transfer ownership
chown -R ubuntu:ubuntu /home/ubuntu

# Allow ubuntu user to access docker images
chmod 775 -R /var/lib/docker/image

# Ensure NICs are set and persit reboot
cat /home/ubuntu/interfaces > /etc/network/interfaces
touch /home/ubuntu/alert4-setup-finished-reboot-in-30s
echo "alert4-setup-finished-reboot-in-30s"
sleep 30
reboot


