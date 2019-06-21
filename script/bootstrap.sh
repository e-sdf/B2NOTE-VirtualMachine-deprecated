#!/usr/bin/env bash

# Prepares VM with web server, opens ports on firewall
# B2NOTE_REPO = https://github.com/EUDAT-B2NOTE/b2note.git
# B2NOTE_BRANCH = master # which branch to checkout
# B2NOTE_PY3 = 1 # configure python 3 env
# B2NOTE_PY2 = 1 # configure python 2 env
# B2NOTE_DATASETVIEW = 1 # configure b2note datasetview poc 

# one of the configuration is syslog - need to restart
service rsyslog restart

# install apache

#chown -R apache:apache /var/www/html
#chmod -R 644 /var/www/html
#find /var/www/html -type d -exec chmod ugo+rx {} \;

yum -y install epel-release
yum-config-manager --save --setopt=epel/x86_64/metalink.skip_if_unavailable=true
yum repolist

yum -y install httpd

systemctl start httpd
systemctl enable httpd

# allow 80 port in firewall
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload

# disable selinux, by default enabled, httpd cannot initiate connection otherwise etc.
setenforce 0
sed -i -e "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

## install mongodb 4.0
yum -y install https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-shell-4.0.9-1.el7.x86_64.rpm
yum -y install https://repo.mongodb.org/yum/redhat/7/mongodb-org/4.0/x86_64/RPMS/mongodb-org-server-4.0.9-1.el7.x86_64.rpm

#mongodb mongodb-server
systemctl start mongod
systemctl enable mongod

# put initial db into mongodb
mongo admin /vagrant/script/bootstrapmongo.js

# create b2note app dir
mkdir /srv/b2note
mkdir /etc/b2note
mkdir -p /opt/b2note
chmod ugo+rwx /srv/b2note
#add permission to allow browse webdav content in /srv/virtualfolder
chmod go+rx /home/vagrant
chown apache:apache /srv/b2note

# build b2note from source code
yum -y install git
cd /home/vagrant

# clone from repository, default from github
if [[ -z "${B2NOTE_REPO}" ]]
then
git clone https://github.com/EUDAT-B2NOTE/b2note.git
else
git clone ${B2NOTE_REPO}
fi

cd b2note
if [[ ${B2NOTE_BRANCH} ]]; then git checkout ${B2NOTE_BRANCH}; fi;
#yum -y install django mongodb
yum -y install python-pip
pip install --upgrade pip
cd /home/vagrant

#############################################################################################################
#################################### PYTHON 3 environment ###################################################
#############################################################################################################
if [[ ${B2NOTE_PY3} && ${B2NOTE_PY3} -eq "1" ]] 
then 
#alternative Python 3 env
sudo yum -y install python36
cd /home/vagrant
python3 -m venv py3
cat <<EOT >> /home/vagrant/py3/bin/activate
# DJANGO B2NOTE variables:
export MONGODB_NAME='b2notedb'
export MONGODB_USR='b2note'
export MONGODB_PWD='b2note'
export SQLDB_NAME='/home/vagrant/b2note/users.sqlite3'
export SQLDB_USR='b2note'
export SQLDB_PWD='b2note'
export VIRTUOSO_B2NOTE_USR='b2note'
export VIRTUOSO_B2NOTE_PWD='b2note'
export B2NOTE_SECRET_KEY='${B2NOTE_SECRET_KEY}'
export B2NOTE_PREFIX_SW_PATH='/home/vagrant/b2note'
#export EMAIL_SUPPORT_ADDR='b2note.temp@gmail.com'
export EMAIL_SUPPORT_ADDR='b2note-support'
export EMAIL_SUPPORT_PWD='some-password'
export SUPPORT_EMAIL_ADDR='b2note@bsc.es'
export SUPPORT_EMAIL_PWD='some-password'
export SUPPORT_DEST_EMAIL='eudat-b2note-support@postit.csc.fi'
EOT
source /home/vagrant/py3/bin/activate
pip install --upgrade pip
cd /home/vagrant/b2note
pip install -r requirements.txt
PY_ENV=py3
#install sqlite
yum -y install sqlite
#replace sqlite 3.7 to newer sqlite 3.11
cp /vagrant/lib/sqlite-3.11/sqlite3 /usr/bin
cp /vagrant/lib/sqlite-3.11/libsqlite3.so.0.8.6 /usr/lib64
#check sqlite version
python -c "import sqlite3; print(sqlite3.sqlite_version)"

#./manage.py syncdb --noinput
cd /home/vagrant/b2note
if [[ -f "/home/vagrant/b2note/manage.py" ]]
then
./manage.py migrate --noinput
# sqlite3 users.sqlite3

./manage.py migrate --database=users --noinput
fi

fi

#############################################################################################################
#################################### PYTHON 2 environment ###################################################
#############################################################################################################
if [[ ${B2NOTE_PY2} && ${B2NOTE_PY2} -eq "1" ]] 
then 
# Python 2
pip install virtualenv
virtualenv py2 
source /home/vagrant/py2/bin/activate
pip install django mongoengine pymongo pysolr requests django-countries eve-swagger django-simple-captcha beautifulsoup4 rdflib rdflib-jsonld django_mongodb_engine
pip install git+https://github.com/django-nonrel/django@nonrel-1.5
pip install git+https://github.com/django-nonrel/djangotoolbox

put settings into activate script
cat <<EOT >> /home/vagrant/py2/bin/activate
# DJANGO B2NOTE variables:
export MONGODB_NAME='b2notedb'
export MONGODB_USR='b2note'
export MONGODB_PWD='b2note'
export SQLDB_NAME='/home/vagrant/b2note/users.sqlite3'
export SQLDB_USR='b2note'
export SQLDB_PWD='b2note'
export VIRTUOSO_B2NOTE_USR='b2note'
export VIRTUOSO_B2NOTE_PWD='b2note'
export B2NOTE_SECRET_KEY='${B2NOTE_SECRET_KEY}'
export B2NOTE_PREFIX_SW_PATH='/home/vagrant/b2note'
#export EMAIL_SUPPORT_ADDR='b2note.temp@gmail.com'
export EMAIL_SUPPORT_ADDR='b2note-support'
export EMAIL_SUPPORT_PWD='some-password'
export SUPPORT_EMAIL_ADDR='b2note@bsc.es'
export SUPPORT_EMAIL_PWD='some-password'
export SUPPORT_DEST_EMAIL='eudat-b2note-support@postit.csc.fi'
EOT
cd /home/vagrant/b2note
source /home/vagrant/py2/bin/activate
pip install django-simple-captcha
pip install -r requirements.txt
pip uninstall -y django
pip install git+https://github.com/django-nonrel/django@nonrel-1.5
pip install git+https://github.com/django-nonrel/djangotoolbox
pip install git+https://github.com/django-nonrel/mongodb-engine
pip install mongoengine django-countries oic
# fix issue https://stackoverflow.com/questions/35254975/import-error-no-module-named-bson
# fix issue import error decimal128
pip uninstall -y bson
pip uninstall -y pymongo
pip install pymongo
PY_ENV=py2
#install sqlite
yum -y install sqlite
#replace sqlite 3.7 to newer sqlite 3.11
cp /vagrant/lib/sqlite-3.11/sqlite3 /usr/bin
cp /vagrant/lib/sqlite-3.11/libsqlite3.so.0.8.6 /usr/lib64
#check sqlite version
python -c "import sqlite3; print(sqlite3.sqlite_version)"

#./manage.py syncdb --noinput
cd /home/vagrant/b2note

./manage.py syncdb --noinput
# sqlite3 users.sqlite3

./manage.py syncdb --database=users --noinput
fi

#############################################################################################################
#################################### daemon scripts #########################################################
#############################################################################################################

# create run script
if [[ -f "/home/vagrant/b2note/manage.py" ]]
then
cat <<EOT > /home/vagrant/b2note/runui.sh
#!/usr/bin/env bash
source /home/vagrant/${PY_ENV}/bin/activate
cd /home/vagrant/b2note/
./manage.py runserver
EOT
fi

cat <<EOT > /home/vagrant/b2note/runapi.sh
#!/usr/bin/env bash
source /home/vagrant/${PY_ENV}/bin/activate
cd /home/vagrant/b2note/
python b2note_api/b2note_api.py
EOT
chmod +x /home/vagrant/b2note/runui.sh
chmod +x /home/vagrant/b2note/runapi.sh
chown -R vagrant:vagrant /home/vagrant/b2note

# start django after boot

cat <<EOT > /etc/systemd/system/b2noteapi.service
[Unit]
Description=B2NOTE Service
After=autofs.service

[Service]
Type=simple
PIDFile=/var/run/b2noteapi.pid
User=vagrant
ExecStart=/home/vagrant/b2note/runapi.sh
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=b2noteapi
WorkingDirectory=/home/vagrant/b2note/

[Install]
WantedBy=multi-user.target
EOT

if [[ -f "/home/vagrant/b2note/runui.sh" ]]
then
cat <<EOT > /etc/systemd/system/b2noteui.service
[Unit]
Description=B2NOTE Service
After=autofs.service

[Service]
Type=simple
PIDFile=/var/run/b2noteui.pid
User=vagrant
ExecStart=/home/vagrant/b2note/runui.sh
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=b2noteui
WorkingDirectory=/home/vagrant/b2note/

[Install]
WantedBy=multi-user.target
EOT
fi
chown vagrant:vagrant /tmp/b2note.log
# set debug
sed -i -e "s/^DEBUG =.*$/DEBUG = True/g" /home/vagrant/b2note/b2note_devel/settings.py
# start django now
systemctl start b2noteui
systemctl enable b2noteui
# start eve api now
systemctl start b2noteapi
systemctl enable b2noteapi

# datasetview
if [[ ${B2NOTE_DATASETVIEW} && ${B2NOTE_DATASETVIEW} -eq "1" ]] 
then 
cd /home/vagrant
git clone https://github.com/e-sdf/B2NOTE-DatasetView
chown -R vagrant:vagrant /home/vagrant/B2NOTE-DatasetView
# apache proxy to django and eve, directory to datasetview
cat <<EOT >> /etc/httpd/conf.d/b2note.conf
Alias "/b2note" "/home/vagrant/b2note/b2note_app/dist"
<Directory "/home/vagrant/b2note/b2note_app/dist">
  Header set Access-Control-Allow-Origin "*"
  Require all granted
  Options FollowSymLinks IncludesNOEXEC
  AllowOverride All
</Directory>

Alias "/datasetview" "/home/vagrant/B2NOTE-DatasetView/dist"
<Directory "/home/vagrant/B2NOTE-DatasetView/dist">
  Require all granted
  Options FollowSymLinks IncludesNOEXEC
  AllowOverride All
</Directory>

WSGIDaemonProcess b2note_api user=vagrant group=vagrant processes=1 threads=5 python-home=/home/vagrant/py3-dev python-path=/home/vagrant/b2note/b2note_api
WSGIPassAuthorization On
WSGIScriptAlias /api /home/vagrant/b2note/b2note_api/api.wsgi

    <Directory /home/vagrant/b2note/b2note_api>
        Require all granted
        WSGIProcessGroup b2note_api
        WSGIApplicationGroup %{GLOBAL}
        Order allow,deny
	Allow from all
    </Directory>

  # ProxyPass /api http://127.0.0.1:5000
  # ProxyPassReverse /api http://127.0.0.1:5000
  # ProxyPass / http://127.0.0.1:8000
  # ProxyPassReverse / http://127.0.0.1:8000

  SSLProxyEngine On
  SSLProxyVerify none
  SSLProxyCheckPeerCN off
  SSLProxyCheckPeerName off
  SSLProxyCheckPeerExpire off

# proxy to pcloud WEBDAV  
<Location "/pcloud">
  ProxyPass "https://webdav.pcloud.com"
  Header add "Access-Control-Allow-Origin" "*"
</Location>

# proxy to b2drop WEBDAV  
<Location "/b2drop">
  ProxyPass "https://b2drop.eudat.eu/remote.php/webdav"
  Header add "Access-Control-Allow-Origin" "*"
</Location>  
EOT
yum -y install mod_ssl
service httpd restart
fi

# install nodejs v >8.x required by aurelia
curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
# remove previous nodejs installation
yum -y remove nodejs
yum -y install nodejs
npm install aurelia-cli -g --quiet