#ifndef converter_hpp
#define converter_hpp
#include <vector>
#include <algorithm>
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <memory>
#include "voro++.hh"
#include "structure.hpp"

using namespace std;
using namespace voro;

class Converter
{
private:
	//Inner data
	vector<Vertex> vertexListRaw; // also vertices outside the periodic box
	vector<int> vertexListMapping; //maps vertices from Raw to Periodic
	vector<int> edgeListMap;
	vector<int> surfaceListMap;
	vector<int> volumeListMap;
	vector<string> cmdFiles;
	//box size
	double xmin, xmax, ymin, ymax, zmin, zmax, threshold;
public:
	//Public data structures (recommendation:read only)
	vector<Volume> volumeList;
	vector<Surface> surfaceList;
	vector<Edge> edgeList;
	vector<Vertex> vertexListUnique; //  only unique vertices
	Converter();
	// Main functions to control the program
	//Load or generate data
	bool LoadGeo (ifstream &fin);
	bool Generate (string gen, int ncell, bool p, string gnu_file);
	bool LoadCmdFiles (string csvCmdfiles);
	//Save loaded data to output files
	bool SaveFe (ofstream &fe_file);
	bool SaveCmd (ofstream &cmd_file);
	bool SaveGnuPlot (ofstream &gnu_file);

private:
	//Updating of local data
	bool AddVertex (Vertex v);
	bool AddEdge (Edge e);
	bool AddSurface (Surface s);
	void AddVolume (Volume v);
	//Parsing
	vector<string> ParseLnGeo (string line);
	//generate structure
	void gen_random (vector<double> &centerx, vector<double> &centery, vector<double> &centerz, int ncell);
	void gen_cubic (vector<double> &centerx, vector<double> &centery, vector<double> &centerz, int ncell);
	void gen_hexab (vector<double> &centerx, vector<double> &centery, vector<double> &centerz, int ncell);
	//Inner computing functions
	WrappingCont ComputeWrappingCont (int v0, int v1);
	Wrapping GetWrapping (double p0, double p1, double min, double max);
	int CompareSurfaces (vector<int> &a, vector<int> &b);
	inline double Abs (double a) {
		return a > 0 ? a : -a;
	}
};


#endif
