#!/bin/sh

echo 'select companies.id,companies.name FROM companies INNER JOIN users ON companies.id = users.company_id WHERE companies.stripe_customer_id IS NULL and users.verified IS FALSE;' | sudo -u postgres psql -d boilerplate_dev
