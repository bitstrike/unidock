build:
	docker build -t unifi .

# if already run once, container will already exist
rerun:
	docker stop unifi
	docker start unifi

# need host mode so AP can connect back to LAN IP
run:
	docker run -d \
	--name unifi \
	--network host \
	-p 8080:8080 \
	-p 8443:8443 \
	-p 3478:3478/udp \
	-p 10001:10001/udp \
	-v unifi-data:/usr/lib/unifi/data \
	-v unifi-logs:/usr/lib/unifi/logs \
	--restart unless-stopped \
	unifi

# remove the container, persistent data, MongoDB, etc. Just start over 
realclean:
	@echo "Stopping and removing container..."
	-docker stop unifi
	-docker rm unifi
	@echo "Removing image..."
	-docker rmi unifi
	@echo "Removing volumes..."
	-docker volume rm unifi-data unifi-logs
	@echo "Done. All UniFi container data has been removed."

.PHONY: build run realclean
# vim: noexpandtab filetype=make:
