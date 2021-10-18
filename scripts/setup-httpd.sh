#!/bin/bash -e

RPM_REPO_PORT='6667'

mkdir -p $HOME/contrail/RPMS
mkdir -p /run/httpd # For some reason it's not created automatically

sed -i "s/Listen 80/Listen $RPM_REPO_PORT/" /etc/httpd/conf/httpd.conf
sed -i "s/\/var\/www\/html\"/\/var\/www\/html\/repo\"/" /etc/httpd/conf/httpd.conf
rm -f /var/www/html/repo
ln -s $HOME/contrail/RPMS /var/www/html/repo

# The following is a workaround for when tf-dev-env is run as root (which shouldn't usually happen)
chmod 755 -R /var/www/html/repo
chmod 755 /root

if ! pidof httpd ; then
  echo "INFO: start httpd"
  /usr/sbin/httpd
else
  echo "INFO: httpd is already started"
fi
