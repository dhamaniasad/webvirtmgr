#!/bin/sh

# Check for root

if [ $USER != 'root' ]; then
echo "Sorry, you need to run this script as root."
exit
fi

# Install prerequisites

apt-get -y install git
apt-get -y install python-pip 
apt-get -y install python-libvirt 
apt-get -y install python-libxml2 
apt-get -y install novnc 
apt-get -y install supervisor 
apt-get -y install nginx

# Get repo and setup

git clone git://github.com/retspen/webvirtmgr.git
cd webvirtmgr
pip install -r requirements.txt
./manage.py syncdb

# Nginx setup

cd ..
mv webvirtmgr /var/www/
## Create webvirtmgr.conf
echo 'server {
    listen 80;

    server_name domain.test;
    #access_log /var/log/nginx/webvirtmgr_access_log;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-for $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $remote_addr;
    }
}' > /etc/nginx/conf.d/webvirtmgr.conf
## Restart nginx
service nginx restart

# WS proxy and Supervisor

service novnc stop
update-rc.d -f novnc remove
rm /etc/init.d/novnc
cp /var/www/webvirtmgr/conf/initd/webvirtmgr-novnc-ubuntu /etc/init.d/webvirtmgr-novnc
service webvirtmgr-novnc start
update-rc.d webvirtmgr-novnc defaults
chown -R www-data:www-data /var/www/webvirtmgr
## Create webvirtmgr.conf
echo '[program:webvirtmgr]
command=/usr/bin/python /var/www/webvirtmgr/manage.py run_gunicorn -c /var/www/webvirtmgr/conf/gunicorn.conf.py
directory=/var/www/webvirtmgr
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/webvirtmgr.log
redirect_stderr=true
user=www-data' > /etc/supervisor/conf.d/webvirtmgr.conf