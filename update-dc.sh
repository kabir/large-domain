#!/bin/bash

#Update this when the version changes
if [[ -z "$JBOSS_VERSION" ]] ; then
    echo Set the target jboss version using the JBOSS_VERSION environment variable
fi
BUILT_JBOSS=jboss-as-$JBOSS_VERSION

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

echo Using branch $GIT_BRANCH. To use another branch set its name in the GIT_BRANCH environment variable.

ORIGINAL_PATH=`pwd`
echo $ORIGINAL_PATH

cd ../jboss-as

echo Refreshing the source checkout...
git fetch --quiet origin
UPDATED_REV=`git rev-parse origin/$GIT_BRANCH`

echo trying to check out branch $GIT_BRANCH. 
git show-ref --verify --quiet refs/heads/$GIT_BRANCH
if [[ $? == "0" ]] ; then
    git checkout $GIT_BRANCH
else
    git checkout -b $GIT_BRANCH origin/$GIT_BRANCH
fi
CURRENT_REV=`git rev-parse HEAD`


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

   mv build/target/$BUILT_JBOSS build/target/jboss-as

   cp ../large-domain/config/host-slave.xml build/target/jboss-as/domain/configuration
   cp ../large-domain/config/host.xml build/target/jboss-as/domain/configuration
   cp ../large-domain/config/mgmt-users.properties build/target/jboss-as/domain/configuration
   cd build/target
   rm jboss-as.zip
   zip -qr jboss-as.zip jboss-as
   cd ../..
fi

echo Writing current rev...
echo $CURRENT_REV > build/target/current-rev.txt


cd $ORIGINAL_PATH

