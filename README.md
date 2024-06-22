# Routearr
Alpine based container used for advanced routing inside a Docker network.

tl;dr

Routearr is an alpine based container used for advanced routing inside a Docker network. Per default the container will execute anything inside the `fwrules.sh` and `commands.sh` if they are mounted inside the container via the Docker compose file. Keep in mind that only `/bin/sh` is available.

Please check the `Dockerfile` to see all available packages.

# Usage
Hint: the `docker compose ...` command might not work on your machine, try `docker-compose ...` instead.

## Pull image and run
```bash
sudo docker pull ghcr.io/kontr0x/routearr:main
```

To run the container interactively run:
```bash
sudo docker compose -f ./examples/docker-compose/openvpn-routearr.yml run --rm routearr
```

To run the container:
```bash
sudo docker compose -f ./examples/docker-compose/openvpn-routearr.yml up -d
```

## Build and run locally
To build the container run:
```bash
sudo docker compose -f ./examples/docker-compose/openvpn-routearr-build.yml build # --no-cache # Append --no-cache if you don't trust Docker caching
```

To run the container interactively run:
```bash
sudo docker compose -f ./examples/docker-compose/openvpn-routearr-build.yml run --rm routearr
```

To run the container:
```bash
sudo docker compose -f ./examples/docker-compose/openvpn-routearr-build.yml up -d
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

# Options
These options can be configured by setting environment variables inside the `docker-compose.yml` file or by using the `-e KEY="VALUE"` in the `docker run` command.

| Env | Default | Example | Description |
| - | - | - | - |
| `DEBUG` | `false` | `1` | Enable debug mode. NOTE: This is currently set to `true` by default, otherwise the VPN connection will not work. |
| `TZ` | `-` | `Europe/Berlin` | Set the timezone. |
| `VPN_TYPE` | - | `openvpn` | The type of VPN to use. Currently only `openvpn` and `wireguard` are supported. |
| `VPN_CONFIG` | - | `config.ovpn` | The name of the VPN configuration file. Make sure to mount the file in the correct location. <br> E.g. `/etc/openvpn/config.ovpn` for OpenVPN and `/etc/wireguard/config.conf` for Wireguard. |
| `OPENVPN_USER` | - | `username` | The username for the OpenVPN connection. | 
| `OPENVPN_PASS` | - | `password` | The password for the OpenVPN connection. |
| `OPENVPN_AUTH_FILE` | - | `login.conf` | The name of the OpenVPN auth file. |

# Known issues
- The vpn (openvpn & wireguard) connection only works when the environment variable `DEBUG` is set to `true` or `1`.

- The wireguard connection only works when the container is privileged.

- The wireguard does not work if the interface is named `wg0`.
