#ifndef converter_hpp
#define converter_hpp
#include <vector>
#include <algorithm>
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <memory>
#include "structure.hpp"

using namespace std;

class Converter
{
private:
	vector<Vertex> vertexListUnique; //  only unique vertices
	vector<Vertex> vertexListRaw; // also vertices outside the periodic box
	vector<int> vertexListMapping; //maps vertices from Raw to Periodic
	vector<Edge> edgeList;
	vector<int> edgeListMap;
	vector<Surface> surfaceList;
	vector<int> surfaceListMap;
	vector<Volume> volumeList;
	vector<int> volumeListMap;
	//box size
	double xmin, xmax, ymin, ymax, zmin, zmax, threshold;
public:
	Converter();

	bool LoadGeo (ifstream &fin);
	void AddVertex(Vertex v);
	void AddEdge(Edge e);
	void AddSurface(Surface s);
	void AddVolume(Volume v);
	vector<string> ParseLnGeo (string line);	
	WrappingCont ComputeWrappingCont (int v0, int v1);
	Wrapping GetWrapping (double p0,double p1,double min,double max);
	int CompareSurfaces(vector<int> &a, vector<int> &b);
	bool SaveFe (ofstream &fout);
	bool SaveCmd(ofstream &cmd_file);
	inline double Abs(double a) {return a>0?a:-a;}
};


#endif
