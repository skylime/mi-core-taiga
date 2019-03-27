#!/usr/bin/env bash

log "enable rabbitmq service with all requirements"
svcadm enable -r svc:/pkgsrc/rabbitmq:default

log "waiting for the cookie file to show up"
COUNT="0"
while ! ls /var/db/rabbitmq/.erlang.cookie >/dev/null 2>&1; do
	sleep 1
	((COUNT=COUNT+1))
	if [[ $COUNT -eq 60 ]]; then
		log "ERROR Could not talk to RABBITMQ after 60 seconds"
		ERROR=yes
		break 1
	fi
done
[[ -n "${ERROR}" ]] && exit 32
log "(it took ${COUNT} seconds to start properly)"

HOME=/root
RABBITMQ_ERLANG_COOKIE=$(cat /var/db/rabbitmq/.erlang.cookie)
log "create rabbitmq admin user"
if ! rabbitmqctl list_users | grep -q "^admin" >/dev/null 2>&1; then
	if RMQ_PW=$(/opt/core/bin/mdata-create-password.sh -m rabbitmq_pw 2>/dev/null); then
		rabbitmqctl add_user admin ${RMQ_PW}
		rabbitmqctl set_user_tags admin administrator
		rabbitmqctl set_permissions admin ".*" ".*" ".*"
	fi
fi

log "check if taiga user exists on local rabbitmq"
if ! rabbitmqctl list_users | grep -q "^taiga" >/dev/null 2>&1; then
	log "create taiga rabbitmq account and password"
	if TAIGA_RMQ_PW=$(/opt/core/bin/mdata-create-password.sh -m taiga_rabbitmq_pw 2>/dev/null); then
		rabbitmqctl add_user taiga ${TAIGA_RMQ_PW}
		rabbitmqctl add_vhost taiga
		rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"
	fi
fi

log "remove default guest user for security reasons"
if rabbitmqctl list_users | grep -q "^guest" >/dev/null 2>&1; then
	rabbitmqctl delete_user guest
fi
