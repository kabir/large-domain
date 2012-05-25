#!/bin/bash

echo ========================================================
echo Start slave script
echo ========================================================

for var in "$@"
do
    if [[ "$var" == "skip.copy" ]] ; then
       SKIP_COPY=1
    elif [[ "$var" == "force.copy" ]] ; then
       FORCE_COPY=1
    elif [[ "$var" == "start" ]] ; then
       START=1
    elif [[ "$var" == "stop" ]] ; then
       STOP=1
    elif [[ "$var" == "kill" ]] ; then
       KILL=1
    elif [[ "$var" == "parallel" ]] ; then
       PARALLEL=1
    else
        echo $var not supported, supported options: skip.copy, force.copy, start, stop, kill
    fi
done

if [[ $STOP != "1" ]] && [[ $START != "1" ]] && [[ $KILL != "1" ]] ; then
    START=1
    KILL=1
fi

#Delete the work dir
rm -rf work
mkdir work

#Clean out the known_hosts to avoid spurious weird messages about changed server identity
rm -f ~/.ssh/known_hosts

myrev=`cat ../jboss-as/build/target/current-rev.txt`
echo My revision: $myrev


function manageSlave {
    slave_addr=$1
    slave_host=$2

    if [ "$SKIP_COPY" != "1" ] ; then

        #Get the slave's revision
        rm -f work/temp-rev.txt
        scp -o "StrictHostKeyChecking no" ec2-user@$slave_addr:~/slave/current-rev.txt work/temp-rev.txt
        slaverev=`cat work/temp-rev.txt`
        echo slave rev: $slaverev

        if [[ $slaverev != $myrev ]] || [[ $FORCE_COPY == "1" ]] ; then
            #Slave revision was different - copy files to slave
	    echo copying files to slave $slave_addr
	    #Remove the existing files in the slave folder
	    ssh $slave_addr rm -rf slave/*
	    #Copy the current rev to the slave
	    scp ../jboss-as/build/target/current-rev.txt ec2-user@$slave_addr:~/slave/current-rev.txt
	    #Copy the zipped AS installation to the slave
	    scp ../jboss-as/build/target/jboss-as.zip $slave_addr:~/slave/jboss-as.zip
	    #Unzip the zipped AS installation
	    echo unzipping as installation on $slave_addr
	    ssh $slave_addr 'unzip -q ~/slave/jboss-as.zip -d ~/slave'
	 fi

         #Overwrite the host name in host-slave.xml with the name of this slave from $slave_host (i.e. from the Name tag)
	 rm -f work/$slave_host-host-slave.xml
	 cp config/host-slave.xml work/$slave_host-host-slave.xml
	 perl -pi -e 's/__HOST_NAME__/'$slave_host'/g' work/$slave_host-host-slave.xml
	 scp work/$slave_host-host-slave.xml $slave_addr:~/slave/jboss-as/domain/configuration/host-slave.xml
    fi 

    #Go to the slave's bin directory, kill all running java processes and start the domain in the background

    if [[ $KILL == "1" ]] ; then 
        echo kill slave
        ssh  -o "StrictHostKeyChecking no" $slave_addr 'killall -9 java'
    fi
    if [[ $STOP == "1" ]] ; then 
        echo stop slave
	remote_pid=$(ssh  -o "StrictHostKeyChecking no" $slave_addr 'ps aux | grep process-controller | grep java' | grep process-controller | grep java  | awk '{print $2}' | sort | awk 'NR==1{print $1}')
	echo $remote_pid
	ssh $slave_addr 'kill '$remote_pid''
    fi
    if [[ $START == "1" ]] ; then 
        echo start slave $slave_host
        ssh  -o "StrictHostKeyChecking no" $slave_addr 'cd ~/slave/jboss-as/bin; nohup ./domain.sh --host-config=host-slave.xml -Djboss.bind.address.management=0.0.0.0 -Djboss.bind.address=0.0.0.0 -Djboss.domain.master.address='$dc_addr' < /dev/null > /dev/null 2>/dev/null &'
    fi
}


IFS=$'\n'

if [[ $START == "1" ]] ; then
    dc_addr=
    #Read the DC
    echo "Determining the domain controller's (i.e. me) internal address..."


    for line in `ec2-describe-instances --filter "instance-state-code=16" --filter "tag:Type=DC"`
    do
        if [[ $line == INSTANCE* ]] ; then
            #Line starts with INSTANCE - get the slave internal address
            dc_addr=$(echo $line|awk '{print $15}')
        fi
    done
    echo My internal address: $dc_addr
fi


#Read the slave entries
echo "Reading/configuring/starting each slave..."

for line in `ec2-describe-instances --filter "instance-state-code=16" --filter "tag:Type=Slave"`
do
    if [[ $line == INSTANCE* ]] ; then
       #Line starts with INSTANCE - get the slave internal address
       slave_addr=$(echo $line|awk '{print $15}')
    fi
    if [[ $line == TAG* ]] ; then
       #Line starts with TAG - look for slave name
       tag=$(echo $line|awk '{print $4}')
       if [[ $tag == "Name" ]] ; then
          #Got the slave name
          slave_host=$(echo $line|awk '{print $5}')
	  
	  echo ----------------------------------------
	  echo Contacting $slave_host $slave_addr

          if [[ $PARALLEL == "1" ]] ; then
              manageSlave $slave_addr $slave_host & 
          else
              manageSlave $slave_addr $slave_host
	  fi
       fi
    fi
done

