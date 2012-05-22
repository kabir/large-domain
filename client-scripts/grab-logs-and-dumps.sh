#!/bin/bash

echo ========================================================
echo Log and thread dump grabber
echo ========================================================

if [[ -z "$SSH_KEY" ]] ; then
    SSH_KEY=~/.ssh/kkhan-ec2.pem
fi

ALL_INSTANCES=1
for var in "$@"
do
    if [[ "$var" == "DC" ]] || [[ "$var" == "dc" ]] ; then
       #DC temporarily disabled since its server is in another place than standard
       DC=0
       ALL_INSTANCES=0
    elif [[ "$var" == "dump" ]] ; then
       DUMP=1
    elif [[ "$var" == "log" ]] ; then
       LOG=1
    elif [[ "$var" == Slave* ]] ; then
       ALL_INSTANCES=0
    else
        echo $var not supported, supported options: dc, dump, log, Slave'<'NUM'>'
	exit 1
    fi
done

if [[ $DUMP != "1" ]] && [[ $LOG != "1" ]] ; then
   DUMP=1
   LOG=1
fi

rm -rf work
mkdir work


IFS=$'\n'

for line in `ec2-describe-instances --filter "instance-state-code=16"`
do
    if [[ $line == INSTANCE* ]] ; then
       #Line starts with INSTANCE - get the slave internal address
       INSTANCE_ADDR=$(echo $line|awk '{print $14}')
    fi
    if [[ $line == TAG* ]] ; then
       tag=$(echo $line|awk '{print $4}')
       if [[ "$tag" == "Name" ]] ; then 
          tag_value=$(echo $line|awk '{print $5}')
         
	  echo tag $tag_value
          candidate=0

	  if [[ $ALL_INSTANCES -eq 1 ]] ; then 
              if [[ "$tag_value" == Slave* ]] || [[ "$tag_value" == "DC" ]] ; then
                  candidate=1
	      fi
	  else
	      if [[ "$tag_value" == "DC" ]] && [[ $DC -eq 1 ]] ; then
                  candidate=1
	      elif [[ "$tag_value" == Slave* ]] ; then
                  for var in "$@" 
		  do
                      if [[ $var == Slave* ]] && [[ "$var" == "$tag_value" ]] ; then
                          candidate=1 
			  break
	              fi
		  done
	      fi
	  fi
	  
	  if [[ $candidate == "1" ]] ; then
              echo Grabbing information for $tag_value at $INSTANCE_ADDR
	      if [[ $LOG -eq 1 ]] ; then
	          echo Getting logs
                  ssh -i $SSH_KEY -o "StrictHostKeyChecking no" ec2-user@$INSTANCE_ADDR 'cd slave/jboss-as/domain ; rm logs.zip ; zip -r logs.zip log servers/server-*/log/'
		  scp -i $SSH_KEY ec2-user@$INSTANCE_ADDR:~/slave/jboss-as/domain/logs.zip work/$tag_value-logs.zip
	      fi
	      if [[ $DUMP -eq 1 ]] ; then
                  echo Getting thread dumps
		  procs=$(ssh -i $SSH_KEY -o "StrictHostKeyChecking no" ec2-user@$INSTANCE_ADDR 'ps aux | grep java')
                  for proc in $procs 
		  do
		      command=$(echo $proc |  awk '{print $11}')
		      if [[ $command != "grep" ]] && [[ $command != "bash" ]]; then
		          echo =================== DUMP ============= >> work/$tag_value-dumps.txt
                          echo $proc >> work/$tag_value-dumps.txt
		          echo ======================================  >> work/$tag_value-dumps.txt
		          proc_id=$(echo $proc | awk '{print $2}')
		          ssh  -i $SSH_KEY -o "StrictHostKeyChecking no" ec2-user@$INSTANCE_ADDR 'jstack '$proc_id'' >> work/$tag_value-dumps.txt
		      fi
		  done
	      fi
	  fi
       fi
   fi

done
