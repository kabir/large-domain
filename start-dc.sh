#!/bin/bash

cd ../jboss-as/build/target/jboss-as/bin
./domain.sh  -Djboss.bind.address.management=0.0.0.0 -Djboss.bind.address=0.0.0.0
