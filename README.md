# UniFi Controller - Docker (Ubuntu 24.04)

Dockerized UniFi Network Application built on Ubuntu 24.04 (Noble), based on
the [unifi_ubuntu_jammy.sh](https://gist.github.com/melchoy/d0cfd6af5a4e39abfcc6c2cd8dacd8ba) install script.

## Stack

| Component | Version |
|-----------|---------|
| Base image | Ubuntu 24.04 (Noble) |
| UniFi Network Application | latest stable (ubiquiti repo) |
| MongoDB | 6.0 |
| Java | OpenJDK 17 |

## Requirements

- Docker
- Docker Compose or `make`

## Usage

```bash
# Build the image
make build

# Start the container
make run

# Follow logs
docker logs -f unifi
```

Once started, the UI is available at **https://\<host-ip\>:8443**.  
Accept the self-signed certificate warning on first visit.

### Full reset

```bash
make realclean
```

This stops and removes the container, removes the image, and deletes both
named volumes. **All adopted device data and site config will be lost.**

Back up the data volume first if you want to preserve your configuration:

```bash
docker run --rm \
  -v unifi-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/unifi-data-backup.tar.gz /data
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8443 | TCP | Web UI (HTTPS) |
| 8080 | TCP | Device communication / inform |
| 3478 | UDP | STUN (device discovery) |
| 10001 | UDP | L2 device discovery |

## Persistent data

Named volumes are used so adoptions, site config, and certificates survive
container restarts and image rebuilds.

| Volume | Container path | Contents |
|--------|---------------|---------|
| `unifi-data` | `/usr/lib/unifi/data` | Device DB, site config, keystore |
| `unifi-logs` | `/usr/lib/unifi/logs` | Application logs |

> **Do not `docker volume rm unifi-data`** unless you intend to start fresh -
> this will unprovision all adopted devices.

## Device adoption

Devices are adopted through the web UI in the normal way. Adoption state
persists in the `unifi-data` volume across restarts.

If your host IP changes, devices may appear as "managed by another controller".
To avoid this, set a static inform URL:

**Settings - System - Advanced - Override Inform Host**

## Notes

- `mongod` is launched directly (no systemd in Docker); the entrypoint waits
  for its UNIX socket before starting UniFi.
- MongoDB 6.0 is built against OpenSSL 3, which ships natively on Noble.
  No `libssl1.1` workaround needed.

## Running as root

The container entrypoint runs as root. This is required because:

- `service unifi start` invokes UniFi's SysV init script, which needs root to
  write PID files to `/var/run`, set file ownership, and bind to ports before
  dropping privileges to the `unifi` system user internally.
- `mongod` is launched via `su -s /bin/bash mongodb -c ...` and drops to the
  `mongodb` system user immediately - it does not run as root at steady state.

Both the `unifi` and `mongodb` system users are created by their respective
packages with no login shell and no password, so the attack surface at runtime
is limited.

### Steps to make this fully rootless

The cleanest path is to split into two containers via Docker Compose, which
removes the need for a root entrypoint entirely:

1. Use the official `mongo:6.0` image - it already runs as the `mongodb` user.
2. Create a minimal UniFi image that runs only `unifi`, with a non-root
   `USER unifi` directive and no init script - start the JVM directly:
   ```
   USER unifi
   CMD ["java", "-jar", "/usr/lib/unifi/lib/ace.jar", "start"]
   ```
3. In `compose.yml`, link the two containers on an internal network so UniFi
   can reach MongoDB by service name rather than `127.0.0.1`.
4. Neither container needs `--privileged` or root.

This also has the side benefit of independent restarts - if MongoDB crashes,
only that container restarts rather than taking UniFi down with it.
