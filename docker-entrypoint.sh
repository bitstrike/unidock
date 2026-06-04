#!/usr/bin/env bash

# -- Start MongoDB ------------------------------------------------------------─
echo "[entrypoint] Starting mongod..."
mkdir -p /data/db /var/log/mongodb
chown -R mongodb:mongodb /data/db /var/log/mongodb

su -s /bin/bash mongodb -c \
    "mongod --dbpath /data/db \
            --logpath /var/log/mongodb/mongod.log \
            --logappend \
            --bind_ip 127.0.0.1 \
            --port 27017 \
            --fork"

# Wait for mongod's UNIX socket - no mongo client needed
echo "[entrypoint] Waiting for MongoDB to be ready..."
for i in $(seq 1 60); do
    if [ -S /tmp/mongodb-27017.sock ]; then
        echo "[entrypoint] MongoDB is up (${i}s)."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[entrypoint] ERROR: MongoDB socket never appeared."
        cat /var/log/mongodb/mongod.log
        exit 1
    fi
    sleep 1
done

# -- Start UniFi --------------------------------------------------------------─
echo "[entrypoint] Starting UniFi controller..."
service unifi start

# -- Tail logs ----------------------------------------------------------------─
mkdir -p /usr/lib/unifi/logs
touch /usr/lib/unifi/logs/server.log \
      /usr/lib/unifi/logs/mongod.log \
      /var/log/mongodb/mongod.log

echo "[entrypoint] UniFi UI will be available at https://<host>:8443"
exec tail -F \
    /usr/lib/unifi/logs/server.log \
    /var/log/mongodb/mongod.log
