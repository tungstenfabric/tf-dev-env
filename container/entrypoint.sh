#!/bin/bash

CONTRAIL_REPOSITORY=${CONTRAIL_REPOSITORY:-6667}

sudo sed -i 's/Listen 80/Listen ${CONTRAIL_REPOSITORY}/' /etc/httpd/conf/httpd.conf
sudo sed -i 's/\/var\/www\/html/\/var\/www\/html\/repo/' /etc/httpd/conf/httpd.conf
sudo ln -s /centos/contrail/RPMS /var/www/html/repo
sudo /usr/sbin/httpd -DNO_DETACH -DFOREGROUND
