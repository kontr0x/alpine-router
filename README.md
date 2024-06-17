# Routearr
Alpine based container used for advanced routing inside a Docker network.

tl;dr

Routearr is an alpine based container used for advanced routing inside a Docker network. Per default the container will execute anything inside the `fwrules.sh` and `commands.sh` if they are mounted inside the container via the Docker compose file. Keep in mind that only `/bin/sh` is available.

Please check the `Dockerfile` to see all available packages.

# Usage
TODO: Rewrite after push ghcr.io workflow is ready.

## Build and run locally
Hint: the `docker compose ...` command might not work on your machine, try `docker-compose ...` instead.

To build the container run:
```bash
sudo docker compose build # --no-cache # Append no cache if you don't trust Docker caching
```

To run the container interactively run:
```bash
sudo docker compose run --rm routearr
```

To run the container:
```bash
sudo docker compose up -d
```

# Example
A example firewall rules script could look like this:
```bash
#!/bin/sh

/sbin/iptables -F

# Add iptable rules here

/sbin/iptables-save

## This is already enabled through the entrypoint.sh
#echo 1 | tee -a /proc/sys/net/ipv4/ip_forward
```
