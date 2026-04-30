# Web Server Management (AIos)

## Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
# Config: /etc/nginx/nginx.conf
# Sites: /etc/nginx/sites-available/

## Create a VHost
cat > /etc/nginx/sites-available/mysite.conf << EOF
server {
    listen 80;
    server_name mysite.com;
    root /var/www/mysite;
    index index.html;
}
EOF
ln -s /etc/nginx/sites-available/mysite.conf /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

## SSL with Certbot
sudo certbot --nginx -d mysite.com
sudo certbot renew --dry-run

## Apache
sudo systemctl start httpd
# Config: /etc/httpd/conf/httpd.conf
# VHosts: /etc/httpd/conf/extra/httpd-vhosts.conf

## Check listening ports
ss -tlnp
