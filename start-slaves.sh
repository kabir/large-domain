#!/bin/bash

#ec2-describe-instances --filter "instance-state-code=16" --filter "tag:Type=Slave" > instances.txt

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



	  slave_host=
	  slave_addr=
       fi
    fi
done
