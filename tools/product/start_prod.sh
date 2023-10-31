#!/bin/bash

if [[ ! -e .secret_key_base ]]; then
	head /dev/urandom | tr -dc A-Za-z0-9 | head -c 128 > .secret_key_base
fi

if [[ ! -e .guardian_secret ]]; then
	head /dev/urandom | tr -dc A-Za-z0-9 | head -c 64 > .guardian_secret
fi

if [[ ! -e .stripe_secret ]]; then
	echo "No .stripe_secret file found for stripe secret key"
	exit 1
fi

if [[ ! -e .stripe_public ]]; then
	echo "No .stripe_public file found for stripe public  key"
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
export STRIPE_SECRET_KEY=$(cat .stripe_secret)
export STRIPE_PUBLIC_KEY=$(cat .stripe_public)
export BOILERPLATE_DOMAIN=$(cat .boilerplate_domain)
export BOILERPLATE_SSL_KEY_PATH=$(cat .ssl_basepath)/privkey.pem
export BOILERPLATE_SSL_CACERT_PATH=$(cat .ssl_basepath)/chain.pem
export BOILERPLATE_SSL_CERT_PATH=$(cat .ssl_basepath)/cert.pem
export MIX_ENV=prod

# Dependencies
echo Y | mix local.hex
echo Y | mix local.rebar
mix deps.get
# Assets
cd assets && /usr/local/bin/npm install && /usr/local/bin/npm run deploy && cd ..
mix phx.digest
# Database
if [[ $1 == "--drop" ]]; then
	mix ecto.drop --force
	mix ecto.setup
else
	mix ecto.migrate

	# The server
	./run_prod.sh
fi
