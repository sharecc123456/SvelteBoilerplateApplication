#!/bin/bash

if [[ ! -e .secret_key_base ]]; then
	echo "No secret key basae found, bailing"
	exit 1
fi

if [[ ! -e .guardian_secret ]]; then
	echo "No guardian secret found, bailing"
	exit 1
fi

if [[ ! -e .boilerplate_domain ]]; then
	echo "No .boilerplate_domain for boilerplate domain"
	exit 1
fi

if [[ ! -e .ssl_basepath ]]; then
	echo "No .ssl_basepath for SSL keys basepath"
	exit 1
fi

export DATABASE_URL="ecto://postgres:postgres@localhost/boilerplate_dev"
export SECRET_KEY_BASE=$(cat .secret_key_base)
export GUARDIAN_SECRET=$(cat .guardian_secret)
export STRIPE_PUBLIC_KEY=$(cat .stripe_public)
export STRIPE_SECRET_KEY=$(cat .stripe_secret)
export BOILERPLATE_DOMAIN=$(cat .boilerplate_domain)
export BOILERPLATE_SSL_KEY_PATH=$(cat .ssl_basepath)/privkey.pem
export BOILERPLATE_SSL_CACERT_PATH=$(cat .ssl_basepath)/chain.pem
export BOILERPLATE_SSL_CERT_PATH=$(cat .ssl_basepath)/cert.pem
export MIX_ENV=prod

# Iptables rules
echo "Setting up iptables: TCP/80 -> TCP/4000"
sudo iptables -t nat -I PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 4000
echo "Setting up iptables: TCP/443 -> TCP/5000"
sudo iptables -t nat -I PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 5000

# The server
mix phx.server
