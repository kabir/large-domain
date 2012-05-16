#!/bin/bash


function checkurl {
   echo checking http://$1:$2/$3 ...
   response=$(curl --write-out %{http_code} --silent --output /dev/null http://$1:$2/$3)
   if [[ $response == "200" ]] ; then 
       echo reached
   else
       echo Failed: $response
   fi
}

echo ========================================================
echo Check servers running
echo ========================================================

IFS=$'\n'

slave_addr=
slave_host=
#Read the slave entries
echo "Checking servers on each slave..."

for line in `ec2-describe-instances --filter "instance-state-code=16" --filter "tag:Type=Slave"`
do
    if [[ $line == INSTANCE* ]] ; then
       #Line starts with INSTANCE - get the slave internal address
       slave_addr=$(echo $line|awk '{print $4}')
    fi
    if [[ $line == TAG* ]] ; then
       #Line starts with TAG - look for slave name
       tag=$(echo $line|awk '{print $4}')
       if [[ $tag == "Name" ]] ; then
          #Got the slave name
          slave_host=$(echo $line|awk '{print $5}')
	  
	  echo ----------------------------------------
	  echo Host $slave_host
	  #echo Checking http://$slave_addr:8080
	  checkurl $slave_addr 8080 $1
	  checkurl $slave_addr 8230 $1
	  #slave_response==$(curl --write-out %{http_code} --silent --output /dev/null http://'$slave_addr':8230)

       fi
    fi
done

rm -rf work


