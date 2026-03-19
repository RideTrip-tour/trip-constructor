FROM kartoza/postgis:18-3.6

COPY create-service-db.sh /usr/local/bin/create-service-db.sh
COPY init-multi-db.sh /docker-entrypoint-initdb.d/init-multi-db.sh

RUN chmod +x /usr/local/bin/create-service-db.sh \
    /docker-entrypoint-initdb.d/init-multi-db.sh
