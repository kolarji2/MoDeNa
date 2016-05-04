#!/bin/sh
cd src
make
cd ../
./se_api PeriodicRVE.geo PeriodicRVE.fe PeriodicRVE.cmd
#evolver -f PeriodicRVE.cmd PeriodicRVE.fe
