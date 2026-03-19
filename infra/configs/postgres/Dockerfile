FROM kartoza/postgis:18-3.6

COPY init-multi-db.sh /docker-entrypoint-initdb.d/init-multi-db.sh

RUN chmod +x /docker-entrypoint-initdb.d/init-multi-db.sh
