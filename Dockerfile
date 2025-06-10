FROM ubuntu:22.04

RUN apt-get -y update && \
    apt-get install -y --no-install-recommends memcached mariadb-server python3-dev python3-pip python3-setuptools git-core gcc
RUN git clone --branch 27.0.0 --single-branch --depth 1 https://github.com/openstack/keystone.git /usr/local/src/keystone && \
    pip install --upgrade setuptools pymysql uwsgi && \
    cd /usr/local/src/keystone && python3 setup.py develop
RUN apt-get remove -y --purge git-core git gcc && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY keystone.conf /etc/keystone/keystone.conf
COPY keystone.sql /keystone.sql

COPY bootstrap.sh /bootstrap.sh
RUN chmod a+x /bootstrap.sh

EXPOSE 5000 35357
ENTRYPOINT ["/bootstrap.sh"]