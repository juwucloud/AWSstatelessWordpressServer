#! /bin/bash
sudo dnf update -y

# installing mysql cli
sudo dnf install -y mariadb1011-server-utils

# installing tools for analysis
dnf install -y nmap traceroute 

# installing jq for easier json parsing
dnf install -y jq