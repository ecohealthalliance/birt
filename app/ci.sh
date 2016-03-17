#!/bin/bash

#Reusing from https://github.com/ecohealthalliance/mantle/blob/master/continuous-integration.sh

#Ensure all dependencies are downloaded

echo "Unit Tests *******************************************************************************"
type spacejam || npm install -g spacejam
spacejam test-packages ./
