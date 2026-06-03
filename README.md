# UniFi Controller - Docker (Ubuntu 22.04)

Dockerized UniFi Network Application built on Ubuntu 22.04 (Jammy), based on
the [unifi_ubuntu_jammy.sh](https://gist.github.com/melchoy/d0cfd6af5a4e39abfcc6c2cd8dacd8ba) install script.

## Stack

| Component | Version |
|-----------|---------|
| Base image | Ubuntu 22.04 (Jammy) |
| UniFi Network Application | latest stable (ubiquiti repo) |
| MongoDB | 4.4 |
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
- `libssl1.1` is sourced from the Ubuntu 20.04 focal-security repo since it
  was removed in Jammy.
