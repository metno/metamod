#!/bin/sh

XSLTPROC=`which xsltproc`
if [ $? != 0 ]
then
    echo STDERR "xsltproc command not installed!"
    exit 1
fi

XMLLINT=`which xmllint`
if [ $? != 0 ]
then
    echo STDERR "xmllint command not installed!"
    exit 1
fi

WGET=`which wget`
echo " <$WGET>"
if [ $? != 0 ]
then
    echo STDERR "wget command not installed!"
    exit 1
fi

$WGET -O P041_gcmd.xml 'http://vocab.ndg.nerc.ac.uk/list/P041/current'
if [ $? != 0 ]
then
    echo STDERR "Download from NERC failed"
    exit 1
fi

$WGET -O P071_cf.xml 'http://vocab.ndg.nerc.ac.uk/list/P071/current'
if [ $? != 0 ]
then
    echo STDERR "Download from NERC failed"
    exit 1
fi

$WGET -O P072_cf.xml 'http://vocab.ndg.nerc.ac.uk/list/P072/current'
if [ $? != 0 ]
then
    echo STDERR "Download from NERC failed"
    exit 1
fi

$XSLTPROC merge.xsl P041_gcmd.xml | $XMLLINT --format - > _keywords.xml
if [ $? != 0 ]
then
    echo STDERR "XSLT processing failed"
    rm _keywords.xml
    exit 1
fi

mv _keywords.xml keywords.xml
echo "keywords.xml generated successfully.\nNow diff file against repository and checkin if necessary."
