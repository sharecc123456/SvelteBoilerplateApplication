#!/bin/bash

if [[ ! -e .secret_key_base ]]; then
	echo "No secret key basae found, bailing"
	exit 1
fi

if [[ ! -e .guardian_secret ]]; then
	echo "No guardian secret found, bailing"
	exit 1
fi

export SECRET_KEY_BASE=$(cat .secret_key_base)
export GUARDIAN_SECRET=$(cat .guardian_secret)

# Rest of the variables are coming from Doppler

# Iptables rules
echo "Setting up iptables: TCP/80 -> TCP/4000"
sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 4000
echo "Setting up iptables: TCP/443 -> TCP/5000"
sudo iptables -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 5000

# The server
mix phx.server
