#!/bin/bash

echo ========================================================
echo Tagging all non running servers as Type=Slave, Name=SlaveXX
echo ========================================================

COUNTER=0

function tag {
    if [[ "$1" != "0" ]] ; then 
        let COUNTER=COUNTER+1
        NUM=$COUNTER
	if [ $COUNTER -lt 10 ] ; then
            NUM=00$COUNTER	
	elif [ $COUNTER -lt 100 ] ; then 
            NUM=0$COUNTER
	fi
        echo tagging $1 as Type=Slave,Name=Slave$NUM
	ec2-create-tags $1 --tag Name=Slave$NUM --tag Type=Slave
    fi
}

IFS=$'\n'

#Read the slave entries
echo "Checking servers on each slave..."

INSTANCE_ID="0"

for line in `ec2-describe-instances --filter "instance-state-code=16"` 
do
    if [[ $line == INSTANCE* ]] ; then
       #If the INSTANCE_ID isn't 0 tag the instance
       tag $INSTANCE_ID
       #Line starts with INSTANCE - get the instance id
       INSTANCE_ID=$(echo $line|awk '{print $2}')
    fi
    if [[ $line == TAG* ]] ; then
        INSTANCE_ID="0"
    fi
done

tag $INSTANCE_ID &

