#!/bin/sh
# please save this file using tabs instead of spaces for indent

VIRTUAL_HOST="[==VIRTUAL_HOST==]"
CATALYST_APP="catalyst-[==APPLICATION_ID==]"

ordie () {
    if [ $? != 0 ]
    then
        echo "Please remove target file(s) before trying automatic install:"
        echo "sudo rm /etc/default/$CATALYST_APP /etc/init.d/$CATALYST_APP /etc/rc2.d/$CATALYST_APP /etc/apache2/conf.d/[==APPLICATION_ID==]"
        exit 1
    fi
}


if [ "$VIRTUAL_HOST" = "" ]; then
    sudo ln -s [==TARGET_DIRECTORY==]/etc/httpd.conf  /etc/apache2/conf.d/[==APPLICATION_ID==]; ordie
else
    sudo ln -s [==TARGET_DIRECTORY==]/etc/httpd.conf  /etc/apache/sites-available/$VIRTUAL_HOST; ordie
    ${VIRTUAL_HOST:+"sudo a2ensite"} $VIRTUAL_HOST
fi

# install catalyst job
# TODO: check if files already exist (then die)
sudo ln -s [==TARGET_DIRECTORY==]/etc/default/catalyst-myapp /etc/default/$CATALYST_APP; ordie
sudo ln -s [==TARGET_DIRECTORY==]/etc/init.d/metamod-catalyst /etc/init.d/$CATALYST_APP; ordie
# start Catalyst at boot
sudo ln -s /etc/init.d/$CATALYST_APP /etc/rc2.d/$CATALYST_APP; ordie


# install metamodInit.sh job [code copied from Egil]
APPLICATION_USER=[==APPLICATION_USER==]
if [ $APPLICATION_USER ]; then
	cat > metamodServices-[==APPLICATION_ID==] <<- EOT
		#! /bin/sh
		su -c "[==TARGET_DIRECTORY==]/metamodInit.sh $*" -s /bin/sh $APPLICATION_USER
		# not sure if this will work since you need the password for APPLICATION_USER to su (rewrite to sudo?)
	EOT
	# make sure the tabs above are not replaced with spaces (or the script will break)
	sudo mv metamodServices-[==APPLICATION_ID==] /etc/init.d/; ordie
fi

# install config link
sudo mkdir /etc/metamod-[==MAJORVERSION==]
sudo ln -s [==TARGET_DIRECTORY==]/master_config.txt  /etc/metamod-[==MAJORVERSION==]/[==APPLICATION_ID==].cfg; ordie
