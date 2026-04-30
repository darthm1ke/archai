# Service Management (systemd)

## Start a service
sudo systemctl start <service>

## Stop a service
sudo systemctl stop <service>

## Enable service at boot
sudo systemctl enable <service>

## Enable and start now
sudo systemctl enable --now <service>

## Check service status
systemctl status <service>

## View service logs
journalctl -u <service> -f

## Restart a service
sudo systemctl restart <service>

## List all running services
systemctl list-units --type=service --state=running

## List failed services
systemctl --failed
