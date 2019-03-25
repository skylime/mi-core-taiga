#!/usr/bin/env bash

#rabbitmqctl add_user taiga PASSWORD_FOR_EVENTS
#rabbitmqctl add_vhost taiga
#rabbitmqctl set_permissions -p taiga taiga ".*" ".*" ".*"

svcadm enable -r rabbitmq
