# connect to https://localhost:443  after running

build:
	docker build -t unifi .

run:
	docker run -d \
	--name unifi \
	-p 8080:8080 \
	-p 8443:8443 \
	-p 3478:3478/udp \
	-p 10001:10001/udp \
	-v unifi-data:/usr/lib/unifi/data \
	-v unifi-logs:/usr/lib/unifi/logs \
	--restart unless-stopped \
	unifi

# vim: noexpandtab filetype=make:
