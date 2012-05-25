large-domain
============

Setting up the AMI
================

These are the steps required to set up the AMI - in case my shared image does not work
64 bit Amazon Linux AMI 2012.03 x86_64
-> New images seem to need the 'aki-88aa75e1' KernelID

sudo yum install git
sudo yum install java-1.6.0-openjdk-devel

wget http://mirrors.ukfast.co.uk/sites/ftp.apache.org/maven/binaries/apache-maven-3.0.4-bin.zip
sudo unzip apache-maven-3.0.4-bin.zip -d /opt
sudo ln -s /opt/apache-maven-3.0.4/bin/mvn /usr/bin/mvn
rm apache-maven-3.0.4-bin.zip

mkdir slave
echo aaa > slave/current-rev.txt
mkdir checkouts
cd checkouts
git clone git://github.com/kabir/large-domain.git
git clone git://github.com/kabir/jboss-as.git

enable ssh forwarding in /etc/ssh_config by uncommenting:
Host *
ForwardAgent yes

bash_profile:

JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk.x86_64
export EC2_PRIVATE_KEY=/home/ec2-user/.ec2/pk-IBQKCUTFRPS42YXSDRHDRYPMHDCSDBQP.pem
export EC2_CERT=/home/ec2-user/.ec2/cert-IBQKCUTFRPS42YXSDRHDRYPMHDCSDBQP.pem
export MAVEN_OPTS="-Xmx1024m -Xms512m -XX:MaxPermSize=256m"
PATH=$JAVA_HOME/bin/$PATH:$HOME/bin


(EC2_PRIVATE_KEY and EC2_CERT are the certificates needed for the EC2 command-line tools to work as mentioned in http://aws.amazon.com/developertools/351 so you need to obtain those and set those to whatever yours are)

Once your instance is all set up, find its associated EBS volume and create a snapshot. Once the snapshot is created create an image from that making sure you use aki-88aa75e1
as the kernel id and x86_64 as the architecture.

Setting up your computer and initial EC2 setup
==================================
Install the EC2 command line tools on your computer.

The first EC2 instance you create asks you to create a key pair used to authenticate with your instance to SSH in, I've stored mine as ~/.ssh/kkhan-ec2.pem. When sshing in to the instances I use a script called ~/ec2-agent:
-----
#!/bin/bash
ssh-agent
ssh-add /Users/kabir/.ssh/kkhan-ec2.pem
ssh -i /Users/kabir/.ssh/kkhan-ec2.pem -AX ec2-user@$1
------
So I can ssh into the DC using that script and then from there ssh into the other instances without needing to reauthenticate

On EC2 you also you need a security group opening ports. THis is accessible from the Security Groups menu on the left, or you can create it on the Configure Firewall screen when creating instances. The important thing is to open ports 22 for ssh, I then also opened 9999 and 9990 for mgmt, and 8080 and 8230 for the 2 servers on each host. When creating instances make sure you select the correct key pair and security group or you will have to start again :-)

General starting up an instance guidelines
==============================
Right click on the image you created
Check "launch instance" or "request spot instances" on the AMI
1) Instance Details Screens: Select the instance type and the number of instances you want. I have been using type=m1.medium
If it is a spot instance you need to put in a bid price. $.12 seems to get the m1.medium spot instances up and running quickly and the actual price normally works out about .04 per instance
Keep the default kernel id and ram disk ids
Leave the tags empty
2) Key pair screen: Choose the key pair you created earlier, in my case kkhan-ec2
3) Configure firewall: Choose the security group you created earlier
"Launch instance" will launch right away, "Request spot instances" will take a few minutes

Create/set up the domain controller
===============================
I like to keep this instance hanging around since this is where everything is built so it is nice not to have to start totally from scratch every time. You can guard yourself against accidental termination (which removes the instance) by checking "Termination Protection" on the Instance Details screen. So for this I use "launch instance" when creating from the AMI.

Once the instance is created it needs tagging, go to the tags section in the console and use Name=DC and Type=DC

Once the instance is up and running ssh into it using the ssh-agent script.
Update the origin for ~/checkouts/large-domain and ~/checkouts/jboss-as to your github

$cd ~/checkouts/large-domain
$export JBOSS_VERSION=7.1.3.Final-SNAPSHOT (or whatever the branch you are building uses - used for copying build/target/jboss-as-$VERSION)
$export GIT_BRANCH=7.1 (or whichever branch you want)
$./update-dc.sh clean build
THis will compare the head revisions of your local branch and build the AS checkout in ~/checkouts/jboss-as/. If your head revision is the same but you want to build anyway, you can do ./update-dc.sh force clean build. 
You'll end up with a zipped version of as in ~/build/target/jboss-as.zip and an unzipped version in ~/slave/jboss-as

To start the DC:
$cd ~/checkouts/large-domain
$./start-dc.sh
This starts the DC instance in ~/slave/jboss-as

THE USERNAME/PASSWORD for the DC admin interface is kabir/test.

Start the slaves
==============================
You need a local checkout of git clone git://github.com/kabir/large-domain.git
Create the number of instances you want and once they all show up in the console as started, from your local machine
$cd /path/to/checkout/large-domain.git/client-scripts/
$./tag-started-slaves.sh
This will find all the untagged instances and tag them all with Type=Slave, and then Name=Slave001, Name=Slave002 etc.

Once they are all tagged, ssh into the DC box again using the ec2-agent.sh script, and then
$./start-slaves.sh
By default this will check ~/slave/current-rev.txt on each slave to see if it is the same as the current revision of the DC's copy of the AS. If they are different it will copy the AS over to the slave's ~/slave/jboss-as folder. It will also killall -9 java on each box and then start the AS instance.

Later to manage the slave AS instances you want to save a bit of time by avoiding the version check, so when invoking operations you do:
$./start-slaves.sh skip.copy <OTHER COMMANDS>
(there is a force.copy as well to force a fresh AS instance on to the slaves but it isn't very useful since this script does all slaves in one loop)

The other commands are kill, stop and start
If none are given the default is to do a 'kill' followed by a 'start' for each slave instance
kill - does a killall -9 java on the remote slave instance
stop - does a kill <PC ProcessId> on each remote slave instance triggering a graceful shutdown
start - starts the remote DC instance

By default the slaves will be managed sequentially. To make stuff happen in parallel, pass in 'parallel' along with the other commands, e.g.
$./start-slave.sh kill start parallel

Check the slaves are running
=============================
On your local machine:
$cd /path/to/checkout/large-domain.git/client-scripts/
$./check-servers-running.sh 
This attempts to connect to each server so you will see something like:
========================================================
Check servers running
========================================================
Checking servers on each slave...
----------------------------------------
Host Slave001
checking http://ec2-50-17-95-253.compute-1.amazonaws.com:8080/ ...
reached
checking http://ec2-50-17-95-253.compute-1.amazonaws.com:8230/ ...
reached
----------------------------------------
Host Slave002
checking http://ec2-107-20-45-108.compute-1.amazonaws.com:8080/ ...
reached
checking http://ec2-107-20-45-108.compute-1.amazonaws.com:8230/ ...
reached

…..
If there was a problem, instead of 'reached' it will say 'Failed <HTTP Error code>

To check if a war deployed properly pass in a valid page from that app, e.g:
$./check-servers-running.sh jboss-as-helloworld/index.html
========================================================
Check servers running
========================================================
Checking servers on each slave...
----------------------------------------
Host Slave001
checking http://ec2-50-17-95-253.compute-1.amazonaws.com:8080/jboss-as-helloworld/index.html ...
reached
checking http://ec2-50-17-95-253.compute-1.amazonaws.com:8230/jboss-as-helloworld/index.html ...
reached
----------------------------------------
Host Slave002
checking http://ec2-107-20-45-108.compute-1.amazonaws.com:8080/jboss-as-helloworld/index.html ...
reached
checking http://ec2-107-20-45-108.compute-1.amazonaws.com:8230/jboss-as-helloworld/index.html ...
reached




Grabbing dumps and logs
===============================
On your local machine:
$cd /path/to/checkout/large-domain.git/client-scripts/
$./grab-logs-and-dumps.sh

This will grab the thread dumps and logs for every instance and put it inside the client-scripts/work folder

To only grab the logs:
$./grab-logs-and-dumps.sh log

To only grab the thread dumps:
$./grab-logs-and-dumps.sh dump

To only grab the logs and thread dumps for some instances use the Name tag values for the instances you want
$./grab-logs-and-dumps.sh DC Slave001 Slave049
Or to only get the logs for some instances:
$./grab-logs-and-dumps.sh log DC Slave001 Slave049
Or to only get the dumps for some instances:
$./grab-logs-and-dumps.sh dump DC Slave001 Slave049


