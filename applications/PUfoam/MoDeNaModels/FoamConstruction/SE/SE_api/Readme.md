
##build
cd voro++-0.4.6
make
cd ../
cmake .
make

##run
main -i PeriodicRVE.geo
main -g cubic

##Description
	-i input.geo
		Load file in geo format
	-g random/cubic/hexab
		Generate structure by using voro++ tesselation
	-n 9
		Specify number of cells to generate
			for g:
				random = number of cells
				cubic = number of cells in one direction
				hexab =  even number of cells in one direction
	-o outputFile
		Specify name for output outputFile.fe and outputFile.cmd
	-c file1.cmd,file2.cmd,file3.cmd
		Comma separated list of cmd files which will be loaded in addition when surface evolver is run with output cmd file.
	-p output.gnu
		Plot the structure in gnuplot format, implemented only for generated structures

#show input
evolver PeriodicRVE.fe
and inner cmd #s

or in gnuplot:
splot "output.gnu" with lines
