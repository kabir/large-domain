large-domain
============

This assumes you have an existing AS 7 git checkout at ../jboss-as
and that this file is in a folder called 'large-domain'

Each server must have a folder called ~/slave which is where the 
server gets installed for the slave nodes.

To refresh from kabir's jboss-as github, and build the DC that will be
used on all the slaves run this on the DC box:
./update-dc.sh

To start the DC on the DC box run:
./start-dc.sh &

To copy across and start the slaves on the EC2 instances having Type=Slave, run:
./start-slaves.sh
