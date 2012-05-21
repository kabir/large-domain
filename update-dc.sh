#!/bin/bash

#Update this when the version changes
BUILT_JBOSS=jboss-as-7.2.0.Alpha1-SNAPSHOT

for var in "$@"
do
    if [[ $var == "build" ]] ; then
        VAR_BUILD=1
    elif [[ $var == "clean" ]] ; then
        VAR_CLEAN=1
    elif [[ $var == "force" ]] ; then
        VAR_FORCE=1        
    else
        echo $var not supported, supported options: build,clean,force
    fi
done

if [[ -z "${GIT_BRANCH+x}" ]] ; then
    GIT_BRANCH=master
fi

echo $GIT_BRANCH

ORIGINAL_PATH=`pwd`
echo $ORIGINAL_PATH

cd ../jboss-as
git checkout $GIT_BRANCH
CURRENT_REV=`git rev-parse HEAD`

echo Refreshing the source checkout...
git fetch --quiet origin
UPDATED_REV=`git rev-parse origin/$GIT_BRANCH`

echo My revision:       $CURRENT_REV
echo Upstream revision: $UPDATED_REV

if [[ $CURRENT_REV != $UPDATED_REV ]] || [[ $VAR_FORCE == "1" ]]
then
#   echo Current copy up to date
#else
   echo Getting the most recent sources
   git reset --hard origin/$GIT_BRANCH
   echo Building project
   if [[ $VAR_CLEAN == "1" ]] ; then
       mvn clean -pl build -am 
   fi
   if [[ $VAR_BUILD == "1" ]] ; then
       mvn install -pl build -am
   fi

   cp ../large-domain/config/host-slave.xml build/target/$BUILT_JBOSS/domain/configuration
   cp ../large-domain/config/host.xml build/target/$BUILT_JBOSS/domain/configuration
   cp ../large-domain/config/mgmt-users.properties build/target/$BUILT_JBOSS/domain/configuration
   cd build/target
   rm jboss-as.zip
   zip -qr jboss-as.zip $BUILT_JBOSS
   cd ../..
fi

echo Writing current rev...
echo $CURRENT_REV > build/target/current-rev.txt


cd $ORIGINAL_PATH

