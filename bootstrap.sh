#!/usr/bin/env bash
set -x

/usr/sbin/service mariadb start
/usr/sbin/service memcached start

addgroup --system keystone > /dev/null || true
adduser --quiet --system --no-create-home --ingroup keystone --shell /bin/false keystone || true
if [ "$(id -gn keystone)"  = "nogroup" ]
then
    usermod -g keystone keystone
fi

mkdir -p /var/lib/keystone/ /etc/keystone/ /var/log/keystone/
chown keystone:keystone -R /var/lib/keystone/ /etc/keystone/ /var/log/keystone/
chmod 0700 /var/lib/keystone/ /var/log/keystone/ /etc/keystone/

mysql < /keystone.sql

keystone-manage db_sync
keystone-manage db_sync --expand
keystone-manage db_sync --check
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap \
    --bootstrap-password ${ADMIN_PASSWORD} \
    --bootstrap-username ${ADMIN_USERNAME} \
    --bootstrap-project-name ${ADMIN_TENANT_NAME} \
    --bootstrap-role-name admin \
    --bootstrap-service-name keystone \
    --bootstrap-region-id RegionOne \
    --bootstrap-admin-url http://${HOSTNAME}:35357 \
    --bootstrap-public-url http://${HOSTNAME}:5000 \
    --bootstrap-internal-url http://${HOSTNAME}:5000

oslopolicy-policy-generator --namespace keystone --output-file /etc/keystone/policy.yaml
oslopolicy-policy-upgrade --namespace keystone --policy /etc/keystone/policy.yaml --output-file /etc/keystone/policy.yaml

uwsgi --http 0.0.0.0:5000 --threads 2 --uid keystone --wsgi-file $(which keystone-wsgi-public) &
P1=$!
uwsgi --http 0.0.0.0:35357 --threads 2 --uid keystone --wsgi-file $(which keystone-wsgi-admin) &
P2=$!
wait ${P1} ${P2}
