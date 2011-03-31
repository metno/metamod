#!/bin/sh

if [ ! -w /etc/apache2 ]; then
    echo "Please run this script as root (sudo)."
    exit 1
fi

if [ "[==VIRTUAL_HOST==]" = "" ]; then
    ln -s [==TARGET_DIRECTORY==]/etc/httpd.conf  /etc/apache2/conf.d/[==APPLICATION_ID==]
else
    ln -s [==TARGET_DIRECTORY==]/etc/httpd.conf  /etc/apache/sites-available/[==VIRTUAL_HOST==]
    a2ensite [==VIRTUAL_HOST==]
fi

# install catalyst job
catalyst_app="catalyst-[==APPLICATION_ID==]"
ln -s [==TARGET_DIRECTORY==]/etc/default/catalyst-myapp     /etc/default/$catalyst_app
ln -s [==TARGET_DIRECTORY==]/etc/init.d/metamod-catalyst    /etc/init.d/$catalyst_app
# start Catalyst at boot
ln -s /etc/init.d/$catalyst_app                             /etc/rc2.d/$catalyst_app


# install metamodInit.sh job
cat > /etc/init.d/metamodServices-[==APPLICATION_ID==] <<EOT
#! /bin/sh
su -c "[==TARGET_DIRECTORY==]/metamodInit.sh $*" -s /bin/sh [==APPLICATION_USER==]
EOT

# install config link
mkdir /etc/metamod-[==MAJORVERSION==]
ln -s [==TARGET_DIRECTORY==]/master_config.txt  /etc/metamod-[==MAJORVERSION==]/[==APPLICATION_ID==].cfg
