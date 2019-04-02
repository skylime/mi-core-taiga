#!/bin/bash
UUID=$(mdata-get sdc:uuid)
DDS=zones/${UUID}/data

if zfs list ${DDS} 1>/dev/null 2>&1; then
	zfs create ${DDS}/pgsql    || true
	zfs create ${DDS}/rabbitmq || true

	if ! zfs get -o value -H mountpoint ${DDS}/pgsql | grep -q /var/pgsql; then
		zfs set compression=lz4 ${DDS}/pgsql
		zfs set mountpoint=/var/pgsql ${DDS}/pgsql
	fi
	if ! zfs get -o value -H mountpoint ${DDS}/rabbitmq | grep -q /var/db/rabbitmq; then
		zfs set mountpoint=/var/db/rabbitmq ${DDS}/rabbitmq
		install -d -u rabbitmq -g rabbitmq -m 770 /var/db/rabbitmq
	fi
fi
