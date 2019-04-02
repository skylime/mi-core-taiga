#!/usr/bin/env bash

log "simple fix for hostname setup because of rabbitmq requirements"
FQDN=$(hostname)
gsed -i "s|${FQDN}|${FQDN} ${FQDN%%.*}|g" /etc/hosts

log "update SMF manifests for rabbitmq and epmd to listen only on localhost"
svccfg -s svc:/pkgsrc/rabbitmq addpropvalue method_context/environment \
	astring: '"RABBITMQ_NODE_IP_ADDRESS=127.0.0.1"'
svccfg -s svc:/pkgsrc/epmd addpropvalue method_context/environment \
	astring: '"ERL_EPMD_ADDRESS=127.0.0.1"'
svcadm refresh svc:/pkgsrc/epmd svc:/pkgsrc/rabbitmq

log "modify rabbitmq-env.conf to force localhost for EPMD if started by rabbitmq"
echo 'export ERL_EPMD_ADDRESS=127.0.0.1' >> /opt/local/etc/rabbitmq/rabbitmq-env.conf

log "enable rabbitmq service with all requirements"
svcadm enable -r svc:/pkgsrc/rabbitmq:default

export HOME=/var/db/rabbitmq

log "waiting for the rabbitmq cookie file to appear"
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

export RABBITMQ_ERLANG_COOKIE=$(cat /var/db/rabbitmq/.erlang.cookie)
export LC_CTYPE=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8

log "waiting for rabbitmq to show up"
COUNT="0"
while ! rabbitmqctl status 2>&1; do
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

log "check if taiga user exists on local rabbitmq"
if ! rabbitmqctl list_users | grep -q "^taiga" >/dev/null 2>&1; then
	log "create taiga rabbitmq account and password"
	if TAIGA_RMQ_PW=$(/opt/core/bin/mdata-create-password.sh -m taiga_rabbitmq_pw 2>/dev/null); then
		rabbitmqctl add_user taiga ${TAIGA_RMQ_PW}
		rabbitmqctl add_vhost taiga
		rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"
	fi
fi

log "create rabbitmq admin user"
if ! rabbitmqctl list_users | grep -q "^admin" >/dev/null 2>&1; then
	if RMQ_PW=$(/opt/core/bin/mdata-create-password.sh -m rabbitmq_pw 2>/dev/null); then
		rabbitmqctl add_user admin ${RMQ_PW}
		rabbitmqctl set_user_tags admin administrator
		rabbitmqctl set_permissions admin ".*" ".*" ".*"
	fi
fi

log "remove default guest user for security reasons"
if rabbitmqctl list_users | grep -q "^guest" >/dev/null 2>&1; then
	rabbitmqctl delete_user guest
fi
