#include "converter.hpp"
#include <vector>
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <exception>

using namespace std;

int main (int argc, char* argv[])
{
	try {
		if (argc < 3) {
			throw invalid_argument ("Input or output file not defined!");
		}
		bool loaded = false;
		bool saved = false;
		bool cmd= false;
		char* finName = argv[1];
		char* foutFeName = argv[2];
		char* foutCmdName = argv[3];
		ifstream finGeo (finName);
		ofstream foutFe (foutFeName);
		ofstream foutCmd (foutCmdName);
		Converter converter;
		loaded = converter.LoadGeo (finGeo);
		if (loaded) {
			saved = converter.SaveFe (foutFe);
			cmd=converter.SaveCmd(foutCmd);
		}
		finGeo.close();
		foutFe.close();
		foutCmd.close();
	} catch (exception& e) {
		cout << "An exception occurred: " << e.what() << endl;
	}
	return 0;
}
