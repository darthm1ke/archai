# Networking (Arch / AIos)

## Connect to WiFi (NetworkManager)
nmcli device wifi list
nmcli device wifi connect "<SSID>" password "<password>"

## Show IP addresses
ip addr show

## Show network interfaces
ip link show

## Connect to ethernet (DHCP)
sudo dhcpcd <interface>

## Set static IP
sudo ip addr add 192.168.1.100/24 dev <interface>
sudo ip route add default via 192.168.1.1

## Check DNS
cat /etc/resolv.conf

## Test connectivity
ping -c 4 8.8.8.8

## VPN (OpenVPN)
sudo openvpn --config <file.ovpn>

## Firewall (ufw)
sudo ufw enable
sudo ufw allow <port>
sudo ufw status
