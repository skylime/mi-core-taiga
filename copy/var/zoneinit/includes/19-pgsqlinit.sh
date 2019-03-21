#!/usr/bin/env bash

if [ ! /var/pgsql/data ]; then
	sudo -u postgres initdb -U postgres /var/pgsql/data
fi
