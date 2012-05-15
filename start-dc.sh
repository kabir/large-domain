#!/bin/bash

#Update this when the version changes
BUILT_JBOSS=jboss-as-7.1.2.Final-SNAPSHOT

cd ../jboss-as/build/target/$BUILT_JBOSS/bin
./domain.sh  -Djboss.bind.address.management=0.0.0.0 -Djboss.bind.address=0.0.0.0
