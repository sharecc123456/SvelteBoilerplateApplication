#!/usr/local/bin/bash

mix coveralls.html

tar czvf /tmp/cover.tar.gz cover
scp /tmp/cover.tar.gz boilerplate-eng:/var/www/html/coverage/
ssh boilerplate-eng sudo tar xzvf /var/www/html/coverage/cover.tar.gz -C /var/www/html/coverage
