#include "converter.hpp"
#include <vector>
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <exception>

// Author: Jiri Kolar
// May 2016

using namespace std;

void arg_check (bool arg, string cmd)
{
	if (arg) throw invalid_argument ("Argument already set: " + cmd);
}

int main (int argc, char* argv[])
{
	try {
		if (argc < 2) {
			throw invalid_argument ("You need to specify at least input file by -i foam.geo or call generator etc. -g random");
		}
		bool dataLoaded = false;
		bool storedFe = false;
		bool storedCmd = false;
		string finName;
		string foutFeName;
		string foutCmdName;
		string gen;
		string csvCmdfiles;
		string foutGnuPlotName = "";
		//cmd
		bool g = false;
		bool in = false;
		bool o = false;
		bool c = false;
		bool n = false;
		bool p = false;
		string fileList;
		string arg;
		string cmd;
		int ncell = 0;

		//load control commands
		//
		// -c"file1.cmd,file2.cmd,file3.cmd" load list of other cmd files, SE will pricess them normally
		// -i foam.geo
		// -g cubic random hexab
		// -o foamSE (optional) // will make foamSE.fe and foamSE.cmd
		//  -n number of cell in generation
		// -p plot gnu plot graph NOT implemented
		for (int i = 1; i < argc; i++) {
			cmd = argv[i];
			if (cmd[0] == '-') {
				if (cmd.length() > 2) {
					arg = cmd.substr (2, cmd.length() - 2);
					cmd = cmd.substr (0, 2);
				} else {
					if (i < argc - 1) {
						arg = argv[i + 1];
					}
					if (i >= argc - 1 || arg[0] == '-') {
						throw invalid_argument ("Value missing after command: " + cmd);
					}
					i = i + 1;
				}
				if (cmd == "-g") {
					arg_check (g, cmd);
					g = true;
					gen = arg;
				} else if (cmd == "-i") {
					arg_check (in, cmd);
					in = true;
					finName = arg;
				} else if (cmd == "-o") {
					arg_check (o, cmd);
					o = true;
					if (arg.substr (arg.length() - 3, 3) == ".fe") {
						arg = arg.substr (0, arg.length() - 3);
					}
					foutFeName = arg + ".fe";
					foutCmdName = arg + ".cmd";
				} else if (cmd == "-c") {
					arg_check (c, cmd);
					c = true;
					csvCmdfiles = arg;
				} else if (cmd == "-n") {
					arg_check (n, cmd);
					n = true;
					ncell = stoi (arg);
				} else if (cmd == "-p") {
					arg_check (p, cmd);
					p = true;
					foutGnuPlotName = arg;
				} else {
					cout << "Cmd was not recognised: " << cmd << endl;
				}
			}
		}

		//call functions according to loaded cmds
		Converter converter;

		if (in) {
			ifstream finGeo (finName);
			dataLoaded = converter.LoadGeo (finGeo);
			finGeo.close();
			if (p) {
				ofstream foutGnuPlot (foutGnuPlotName);
				bool saveGnu = converter.SaveGnuPlot (foutGnuPlot);
			}
		} else if (g) {
			if (!n) ncell = -1;
			dataLoaded = converter.Generate (gen, ncell, p, foutGnuPlotName);
		}
		if (!o) {
			foutFeName = "foam.fe";
			foutCmdName = "foam.cmd";
		}
		if (dataLoaded) {
			ofstream foutFe (foutFeName);
			ofstream foutCmd (foutCmdName);

			if (c) {
				converter.LoadCmdFiles (csvCmdfiles);
			}
			storedFe = converter.SaveFe (foutFe);
			storedCmd = converter.SaveCmd (foutCmd);
			foutFe.close();
			foutCmd.close();

		}
		cout << "Finished" << endl;
	} catch (exception& e) {
		if (string(e.what())=="stoi" || string(e.what())=="stod") {
			cout << "Error, while parsing a number from input file: " << e.what() << endl;
		}else{
			cout << "An exception occurred: " << endl << e.what() << endl;
		}
	}
	return 0;
}
