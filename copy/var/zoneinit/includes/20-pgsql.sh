#!/bin/bash

svcadm enable -s svc:/pkgsrc/postgresql:default

log "waiting for the socket to show up"
COUNT="0";
while ! ls /tmp/.s.PGSQL.* >/dev/null 2>&1; do
	sleep 1
	((COUNT=COUNT+1))
	if [[ $COUNT -eq 60 ]]; then
		log "ERROR Could not talk to PGSQL after 60 seconds"
		ERROR=yes
		break 1
	fi
done
[[ -n "${ERROR}" ]] && exit 31
log "(it took ${COUNT} seconds to start properly)"

echo 'postgres' | mdata-put pgsql_pw

sudo -u postgres 


PGPASSWORD=postgres createdb taiga -U postgres -O taiga --encoding='utf-8' --locale='en_US.UTF-8' --template=template0

sm-create-dbuser postgresql taiga changeme taiga
