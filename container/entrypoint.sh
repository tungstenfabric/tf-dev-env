#!/bin/bash

RPM_REPO_PORT='6667'

mkdir -p $HOME/contrail/RPMS
mkdir -p /run/httpd # For some reason it's not created automatically

sudo sed -i "s/Listen 80/Listen $RPM_REPO_PORT/" /etc/httpd/conf/httpd.conf
sudo sed -i "s/\/var\/www\/html\"/\/var\/www\/html\/repo\"/" /etc/httpd/conf/httpd.conf
sudo ln -s $HOME/contrail/RPMS /var/www/html/repo
sudo /usr/sbin/httpd -DNO_DETACH -DFOREGROUND
