#!/bin/sh
#SE installation
sudo cp -r evolver.1 /usr/local/man/man1/
sudo chmod +r /usr/local/man/man1/evolver.1
cd src
make
sudo cp evolver /usr/local/bin/
