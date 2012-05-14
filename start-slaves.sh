#!/bin/bash

#Update this when the version changes
BUILT_JBOSS=jboss-as-7.1.2.Final-SNAPSHOT

ec2-describe-instances --filter "instance-state-code=16" --filter "tag:Type=Slave" > instances.txt

myrev=`cat ../jboss-as/build/target/current-rev.txt`
echo My revision: $myrev

IFS=$'\n'
slave_addr=
slave_host=
for line in `cat instances.txt`
do
    if [[ $line == INSTANCE* ]] ; then
       slave_addr=$(echo $line|awk '{print $5}')
    fi
    if [[ $line == TAG* ]] ; then
       tag=$(echo $line|awk '{print $4}')
       if [[ $tag == "Name" ]] ; then
          slave_host=$(echo $line|awk '{print $5}')
	  
	  echo Contacting $slave_host $slave_addr

          #Get the slave's revision
          rm temp-rev.txt
	  scp ec2-user@$1/home/ec2-user/slave/current-rev.txt temp-rev.txt
	  slaverev=`cat temp-rev.txt`

	  if [[ $slaverev != $myrev ]] ; then
	      echo copying files to slave $slave_addr
	      ssh $slave_addr rm -rf slave/*
	      scp ../jboss-as/build/target/current-rev.txt ec2-user@$slave_addr/home/ec2-user/slave/current-rev.txt
	      scp ../jboss-as/build/target/jboss-as.zip $slave_addr/home/ec2-user/slave/jboss-as.zip
	      ssh $slave_addr unzip /home/ec2_user/slave/jboss-as.zip -d /home/ec2_user/slave
	  fi

          echo start slave

	  slave_host=
	  slave_addr=
       fi
    fi
done
