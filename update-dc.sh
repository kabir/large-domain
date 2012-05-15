#!/bin/bash

#Update this when the version changes
BUILT_JBOSS=jboss-as-7.1.2.Final-SNAPSHOT

ORIGINAL_PATH=`pwd`
echo $ORIGINAL_PATH

cd ../jboss-as

CURRENT_REV=`git rev-parse HEAD`

echo Refreshing the source checkout...
git fetch --quiet origin
UPDATED_REV=`git rev-parse origin/master`

echo My revision:       $CURRENT_REV
echo Upstream revision: $UPDATED_REV

if [ $CURRENT_REV = $UPDATED_REV ]
then
   echo Current copy up to date
else
   echo Getting the most recent sources
   git reset --hard origin/master
   echo Building project
   #mvn clean -pl build -am 
   #mvn install -pl build -am
   cp ../large-domain/config/host-slave.xml build/target/$BUILT_JBOSS/domain/configuration
   cp ../large-domain/config/host.xml build/target/$BUILT_JBOSS/domain/configuration
   cp ../large-domain/config/mgmt-users.properties build/target/$BUILT_JBOSS/domain/configuration
   cd build/target
   rm jboss-as.zip
   zip -r jboss-as.zip $BUILT_JBOSS
   cd ../..
fi

echo Writing current rev...
echo $CURRENT_REV > build/target/current-rev.txt


cd $ORIGINAL_PATH

