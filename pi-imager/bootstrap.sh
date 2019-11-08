#!/bin/bash

###########
## Notes ##
###########
# 1. This file was executed while a monitor was connected to the Raspberry Pi.
# I don't believe this matters, but it may affect whether a default display is
# created by X.
#
# 2. I used Raspbian image 2019-04-08-raspbian-stretch.img.
#
# 3. I attempted to use Raspbian Buster, but the video output did not work.

sudo apt-get -y update
sudo apt-get -y install git ruby ruby-dev

sudo gem install bundler
sudo gem install bundler:1.15.4

wget http://download.processing.org/processing-3.5.3-linux-armv6hf.tgz
gunzip processing-3.5.3-linux-armv6hf.tgz
tar xf processing-3.5.3-linux-armv6hf.tar

mkdir -p /home/pi/.processing
echo "sketchbook.path.three=/home/pi/sketchbook" >> /home/pi/.processing/preferences.txt
mkdir -p /home/pi/sketchbook/libraries
cd sketchbook/libraries
wget https://github.com/processing/processing-video/releases/download/latest/video.zip
unzip video.zip
wget https://github.com/gohai/processing-glvideo/releases/download/latest/processing-glvideo.zip
unzip processing-glvideo.zip
cd ../../

echo 'export DISPLAY=:0' >> /home/pi/.profile

echo '#!/bin/bash' > wistiatron.sh
echo "source /home/pi/.profile > wistiatron.log 2>&1" >> wistiatron.sh
echo "cd /home/pi/wistiatron-server > wistiatron.log 2>&1" >> wistiatron.sh
echo "bundle > wistiatron.log 2>&1" >> wistiatron.sh
echo "bundle exec rackup -o 0.0.0.0 > wistiatron.log 2>&1" >> wistiatron.sh
chmod +x wistiatron.sh

echo '#!/bin/bash' > restart-wistiatron.sh
echo "sudo killall ruby2.3" >> restart-wistiatron.sh
echo 'sudo -E su -c "source /home/pi/.profile && cd /home/pi/wistiatron-server && bundle && bundle exec rackup > /home/pi/wistiatron.log 2>&1 &" pi 2>&1' >> restart-wistiatron.sh
chmod +x restart-wistiatron.sh

ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone git@github.com:wistia/wistiatron.git
git clone git@github.com:wistia/wistiatron-server.git
cd wistiatron-server && git reset --hard origin/rpi && cd ..

(crontab -l 2>/dev/null; echo '@reboot sudo -E su -c "source /home/pi/.profile && cd /home/pi/wistiatron-server && bundle && bundle exec rackup > /home/pi/wistiatron.log 2>&1 &" pi') | sudo crontab -

sudo apt-get -y install nginx
sudo rm /etc/nginx/sites-available/default
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOT
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	listen 443 ssl default_server;
	listen [::]:443 ssl default_server;
	ssl_certificate /home/pi/certbot-route53/letsencrypt/live/wistia.af/fullchain.pem;
	ssl_certificate_key /home/pi/certbot-route53/letsencrypt/live/wistia.af/privkey.pem;
	server_name wistia.af;
	location / {
    proxy_pass http://localhost:9292;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOT

#########################################################
# Note: You must add you AWS creds here for letsencrypt #
#########################################################
echo "export AWS_ACCESS_KEY_ID=" >> /home/pi/.profile
echo "export AWS_SECRET_ACCESS_KEY=" >> /home/pi/.profile
echo "export AWS_REGION=us-east-1" >> /home/pi/.profile
sudo apt-get -y install certbot awscli
git clone https://github.com/jed/certbot-route53.git
cd certbot-route53
sudo -E su -c "./certbot-route53.sh --agree-tos --manual-public-ip-logging-ok --domains wistia.af --email robby@wistia.com" root
sudo tee /etc/cron.monthly/renew-certs.sh > /dev/null <<EOT
#!/bin/bash
sudo -E su -c "source /home/pi/.profile && cd /home/pi/certbot-route53 && ./certbot-route53.sh --agree-tos --manual-public-ip-logging-ok --domains wistia.af --email robby@wistia.com" root
EOT

sudo systemctl restart nginx.service

wget https://gist.githubusercontent.com/inhumantsar/97f951032c6b0e701cca/raw/5eb419583021632a3c329cf2066bea85a14a14a1/update-route53.sh
chmod +x update-route53.sh
sudo tee /etc/cron.hourly/update-ip.sh > /dev/null <<EOT
#!/bin/bash
sudo -E su -c "source /home/pi/.profile && cd /home/pi && ./update-route53.sh -z Z2QIKYY6UPNTXT -r wistia.af -l 300 -t A -i $(hostname -I)" root
EOT

echo "wistiatron" | sudo tee /etc/hostname
echo "127.0.1.1 wistiatron" | sudo tee -a /etc/hosts

sudo reboot