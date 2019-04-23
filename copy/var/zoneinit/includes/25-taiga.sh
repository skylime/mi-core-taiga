#!/usr/bin/env bash

TAIGA_DIR="/opt/taiga"
TAIGA_DIST_DIR="/opt/taiga_frontend"
TAIGA_EVENTS_DIR="/opt/taiga_events"
TAIGA_HOSTNAME=$(hostname)
TAIGA_RMQ_PW=$(mdata-get taiga_rabbitmq_pw)
TAIGA_PGSQL_PW=$(mdata-get taiga_pgsql_pw)
TAIGA_SECRET_KEY=$(LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c64)


log "taiga create settings/local.py"
cat > ${TAIGA_DIR}/settings/local.py <<-EOF
from .common import *

MEDIA_URL = "https://${TAIGA_HOSTNAME}/media/"
STATIC_URL = "https://${TAIGA_HOSTNAME}/static/"
SITES["api"]["scheme"] = "https"
SITES["api"]["domain"] = "${TAIGA_HOSTNAME}"
SITES["front"]["scheme"] = "https"
SITES["front"]["domain"] = "${TAIGA_HOSTNAME}"

SECRET_KEY = "${TAIGA_SECRET_KEY}"

DEBUG = False
PUBLIC_REGISTER_ENABLED = False

DEFAULT_FROM_EMAIL = "no-reply@${TAIGA_HOSTNAME}"
SERVER_EMAIL = DEFAULT_FROM_EMAIL
FEEDBACK_ENABLED = False
FEEDBACK_EMAIL = ""

CELERY_ENABLED = True

EVENTS_PUSH_BACKEND = "taiga.events.backends.rabbitmq.EventsPushBackend"
EVENTS_PUSH_BACKEND_OPTIONS = {"url": "amqp://taiga:${TAIGA_RMQ_PW}@localhost:5672/taiga"}

INSTALLED_APPS += ["taiga_contrib_email_overrides"]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'taiga',
        'USER': 'taiga',
        'PASSWORD': '${TAIGA_PGSQL_PW}',
        'HOST': '',
        'PORT': '',
    }
}
EOF

if mdata-get mail_smarthost >/dev/null 2>&1 && \
   mdata-get mail_auth_user >/dev/null 2>&1; then
cat >> ${TAIGA_DIR}/settings/local.py <<-EOF
EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_USE_TLS = True
EMAIL_HOST = "$(mdata-get mail_smarthost)"
EMAIL_HOST_USER = "$(mdata-get mail_auth_user)"
EMAIL_HOST_PASSWORD = "$(mdata-get mail_auth_pass)"
EMAIL_PORT = 25
EOF
fi

log "enable trello import if TRELLO_API_KEY and TRELLO_API_SECRET provided"
if TRELLO_API_KEY=$(mdata-get trello_api_key 2>/dev/null) && \
   TRELLO_API_SECRET=$(mdata-get trello_api_secret 2>/dev/null); then
	cat >> ${TAIGA_DIR}/settings/local.py <<-EOF
	IMPORTERS["trello"] = {
	    "active": True,
	    "api_key": "${TRELLO_API_KEY}",
	    "secret_key": "${TRELLO_API_SECRET}"
	}
	EOF
	IMPORTERS="trello"
fi

log "create taiga dist configuration file"
cat > ${TAIGA_DIST_DIR}/conf.json <<-EOF
{
 "api": "https://${TAIGA_HOSTNAME}/api/v1/",
 "eventsUrl": "wss://${TAIGA_HOSTNAME}/events",
 "debug": "true",
 "publicRegisterEnabled": true,
 "feedbackEnabled": true,
 "privacyPolicyUrl": null,
 "termsOfServiceUrl": null,
 "GDPRUrl": null,
 "maxUploadFileSize": null,
 "contribPlugins": [],
 "importers": ["${IMPORTERS}"]
}
EOF

log "configure taiga events"
cat > ${TAIGA_EVENTS_DIR}/config.json <<-EOF
{
    "url": "amqp://taiga:${TAIGA_RMQ_PW}@localhost:5672",
    "secret": "${TAIGA_SECRET_KEY}",
    "webSocketServer": {
        "port": 8888
    }
}
EOF

log "fix configuration file for celery"
sed -i "s|^broker_url.*|broker_url = 'amqp://taiga:${TAIGA_RMQ_PW}@localhost:5672/taiga'|g" \
	${TAIGA_DIR}/settings/celery.py

log "taiga migrate"
pushd ${TAIGA_DIR} >/dev/null
${TAIGA_DIR}/manage.py migrate --noinput

log "check if admin user already exists"
if ! ${TAIGA_DIR}/manage.py shell -c \
     'from django.contrib.auth import get_user_model; \
      User=get_user_model(); \
      User.objects.get(username="admin")' >/dev/null 2>&1; then

	if TAIGA_INIT_ADMIN_PW=$(/opt/core/bin/mdata-create-password.sh -m taiga_init_admin_pw 2>/dev/null); then
		TAIGA_INIT_ADMIN_PW_HASH=$(${TAIGA_DIR}/manage.py shell -c \
			'from django.contrib.auth.hashers import make_password; \
			print(make_password("'${TAIGA_INIT_ADMIN_PW}'"))')
		sed -i 's|"password": ".*",|"password": "'${TAIGA_INIT_ADMIN_PW_HASH}'",|g' \
			${TAIGA_DIR}/taiga/users/fixtures/initial_user.json
	fi
	log "taiga initialise user"
	${TAIGA_DIR}/manage.py loaddata initial_user
	log "taiga initialise project templates"
	${TAIGA_DIR}/manage.py loaddata initial_project_templates
fi

log "taiga compile messages"
${TAIGA_DIR}/manage.py compilemessages
log "taige collect static files"
${TAIGA_DIR}/manage.py collectstatic --noinput

log "fix all permissions"
chown -R taiga:taiga ${TAIGA_DIR}
popd >/dev/null

log "enable taiga gunicorn service"
svcadm enable svc:/network/gunicorn:taiga

log "enable taiga events service"
#svcadm enable svc:/network/coffeescript:taiga-events

log "enable taiga celery service"
#svcadm enable svc:/network/celery:taiga
