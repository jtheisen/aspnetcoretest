#!/bin/sh

wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
add-apt-repository universe -y
apt-get update -y
apt-get install apt-transport-https -y
apt-get update -y
apt-get install dotnet-sdk-3.1 -y
cd /var/www-src
echo "About to compile"
dotnet publish --configuration Release -o /var/www
echo "Compiling done"
cp scripts/kestrel.service /etc/systemd/system/kestrel.service
systemctl --now enable kestrel
