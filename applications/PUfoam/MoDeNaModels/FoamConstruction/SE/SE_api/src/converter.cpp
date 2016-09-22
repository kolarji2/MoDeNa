#include "converter.hpp"

using namespace std;

Converter::Converter()
{
	//init const
	xmin = 0;
	ymin = xmin;
	zmin = xmin;
	xmax = 1;
	ymax = xmax;
	zmax = xmax;
	threshold = 0.00001;
}

bool Converter::LoadGeo (ifstream &fin)
{
	/*
	* Load .geo file to converter
	* Makes it periodic and transform to local data structure
	*/

	string line;
	string val;
	vector<string> sl;

	//Cache mem size
	int cacheMem = 50;
	//Structure alloc
	bool reservedVRaw = false;
	bool reservedVUnique = false;
	bool reservedE = false;
	bool reservedSurf = false;
	bool reservedVol = false;
	bool reservedEMap = false;
	bool reservedSMap = false;
	int i = 0;
	int id = 0;
	float num;
	if (!fin.is_open()) {
		cout << "Can not open input file." << endl;
		return false;
	}
	cout << "Loading input file..." << endl;
	//loading structure
	while (getline (fin, line)) {
		//allocation
		if (!reservedVRaw && vertexListRaw.size() % cacheMem == 0) {
			vertexListRaw.reserve (vertexListRaw.size() + cacheMem);
			vertexListMapping.reserve (vertexListRaw.size() + cacheMem);
			reservedVRaw = true;
		}
		if (!reservedVUnique && vertexListUnique.size() % cacheMem == 0) {
			vertexListUnique.reserve (vertexListUnique.size() + cacheMem);
			reservedVUnique = true;
		}
		if (!reservedE && edgeList.size() % cacheMem == 0) {
			edgeList.reserve (edgeList.size() + cacheMem);
			reservedE = true;
		}
		if (!reservedEMap && edgeListMap.size()  % cacheMem == 0) {
			edgeListMap.reserve (edgeListMap.size() + cacheMem);
			reservedEMap = true;
		}

		if (!reservedSurf && surfaceList.size() % cacheMem == 0) {
			surfaceList.reserve (surfaceList.size() + cacheMem);
			reservedSurf = true;
		}

		if (!reservedSMap && surfaceListMap.size()  % cacheMem == 0) {
			surfaceListMap.reserve (surfaceListMap.size() + cacheMem);
			reservedSMap = true;
		}

		if (!reservedVol && volumeList.size() % cacheMem == 0) {
			volumeList.reserve (volumeList.size() + cacheMem);
			reservedVol = true;
		}

		//parsing line

		sl = ParseLnGeo (line);
		if (sl.size()>0) {
		if (sl[0] == "Point") {
			reservedVRaw = false;
			if (sl.size()<5) throw length_error("Error in input file: section Point");
			if (stoi(sl[1])!=vertexListRaw.size()+1) throw length_error("Inconsistent order of in section Point");
			Vertex v = Vertex (stod (sl[2]) - 1, stod (sl[3]) - 1, stod (sl[4]) - 1);
			reservedVUnique = AddVertex (v);
		} else if (sl[0] == "Line") {
			if (sl.size()<4) throw length_error("Error in input file: section Line");
			reservedEMap = false;
			int v0 = stoi (sl[2]) - 1;
			int v1 = stoi (sl[3]) - 1;
			if (v0<0 || v1<0 || v0>=vertexListRaw.size() || v1>=vertexListRaw.size())
				throw out_of_range("Index of vertex out of range");
			WrappingCont wrappingCont = ComputeWrappingCont (v0, v1);
			v0 = vertexListMapping[v0] + 1;
			v1 = vertexListMapping[v1] + 1;
			Edge e (v0, v1, wrappingCont);
			reservedE = AddEdge (e);
		} else if (sl[0] == "Line Loop") {
			reservedSMap = false;
			if (sl.size() - 2<=0 ) throw length_error("Error in Line Loop section");
			if ( stoi(sl[1])!=surfaceListMap.size() +1 ) throw length_error("Inconsistent order of in section Line Loop");
			Surface srf (sl, edgeListMap);
			reservedSurf = AddSurface (srf);
		} else if (sl[0] == "Surface Loop") {
			if (sl.size() - 2<=0) throw length_error("Error in Surface Loop section");
			if ( stoi(sl[1])!=volumeListMap.size() +1) throw length_error("Inconsistent order of in section Surface Loop");
			Volume vol (sl, surfaceListMap);
			AddVolume (vol);
		}
		}
	}
	return true;
}

vector<string> Converter::ParseLnGeo (string line)
{
	//Parse line from .geo file
	//Dodelat get_token() a parsovani, at nemuze spadnout
	bool id = false;
	bool order = false;
	bool value = false;
	int i = 0;
	int previ = 0;
	string val;
	vector<string> strVec;
	while (previ<line.size() && line[previ] == ' ') previ++;
	for (i = previ; i < line.size(); i++) {
		if (!id && line[i] == '(') {
			val = line.substr (previ, i - previ - 1);
			if (val == "Volume") {
				while (i<line.size() && line[i] != ';') i++;
				i++;
				if (i >= line.size()) {
					strVec.push_back (val);
					break;
				}
				while (i<line.size() && line[i] == ' ') i++;
				i--;
			} else {
				id = true;
				strVec.push_back (val);
			}
			previ = i + 1;
		} else if (!order && id && line[i] == ')') {
			order = true;
			strVec.push_back (line.substr (previ, i - previ));
		} else if (order && id && line[i] == '{') {
			previ = i + 1;
		} else if (line[i] == ';') {
			stringstream valStream (line.substr (previ, i - previ - 1));
			while (getline (valStream, val, ',')) {
				strVec.push_back (val);
			}
		}
		if (previ>=line.size())	break;
			
	}
	return strVec;
}

bool Converter::LoadCmdFiles (string csvCmdfiles)
{
	//Load cmd files, only names.
	int iprev = 0;
	for (int i = 0; i <= csvCmdfiles.length(); i++) {
		if (i == csvCmdfiles.length() || csvCmdfiles[i] == ',') {
			cmdFiles.push_back (csvCmdfiles.substr (iprev, i - iprev));
			iprev = i + 1;
		}
	}

}

bool Converter::AddVertex (Vertex v)
{
	vertexListRaw.push_back (v);
	bool vertExist = false;
	int i = 0;
	//check if added vertex is already in list if is outside the box

	//correction, to place vertex inside the box
	if (v.X < xmin) v.X = v.X + xmax;
	if (v.X > xmax) v.X = v.X - xmax;
	if (v.Y < ymin) v.Y = v.Y + ymax;
	if (v.Y > ymax) v.Y = v.Y - ymax;
	if (v.Z < zmin) v.Z = v.Z + zmax;
	if (v.Z > zmax) v.Z = v.Z - zmax;
	//find if there already exists same vertex;
	vertExist = false;
	for (i = 0; i < vertexListUnique.size(); i++) {
		Vertex *vOld = &vertexListUnique[i];
		if ( (Abs (vOld->X - v.X) < threshold) &&
		     (Abs (vOld->Y - v.Y) < threshold) &&
		     (Abs (vOld->Z - v.Z) < threshold)) {
			vertExist = true;
			break;
		}
	}
	vertexListMapping.push_back (i);
	if (!vertExist) {
		vertexListUnique.push_back (v);
		return true;
	}
	return false;
}
bool Converter::AddEdge (Edge e)
{
	int id = 1;
	bool edgeExist = false;
	for (int i = 0; i < edgeList.size(); i++) {
		Edge *eOld = &edgeList[i];
		if (eOld->Equal (e)) {
			edgeExist = true;
			break;
		}
		if (eOld->EqualInv (e)) {
			edgeExist = true;
			id = -id;
			break;
		}
		id++;
	}
	edgeListMap.push_back (id);
	if (!edgeExist) {
		edgeList.push_back (e);
		return true;
	}
	return false;
}

bool Converter::AddSurface (Surface s)
{
	int id = 1;
	bool surfExist = false;
	for (int i = 0; i < surfaceList.size(); i++) {
		int result = CompareSurfaces (s.edgeList, surfaceList[i].edgeList);
		if (result == 1 || result == -1) {
			id = id * result;
			surfExist = true;
			break;
		}
		id++;
	}
	surfaceListMap.push_back (id);
	if (!surfExist) {
		surfaceList.push_back (s);
		return true;
	}
	return false;
}



void Converter::AddVolume (Volume v)
{
	bool volExist = false;
	sort (v.surfaceList.begin(), v.surfaceList.end());
	int  i=0;
	for (i = 0; i < v.surfaceList.size(); i++) {
		int result = CompareSurfaces (v.surfaceList, volumeList[i].surfaceList);
		if (result == 1 || result == -1) {
			volExist = true;
			break;
		}
	}
	volumeListMap.push_back(i);
	if (!volExist)	volumeList.push_back (v);
}

int Converter::CompareSurfaces (vector<int> &a, vector<int> &b)
{
	if (a.size() != b.size()) return 0;
	int match = 0;
	bool inv = false;
	for (int i = 0; i < a.size(); i++) {
		//find if all lines matches
		for (int j = 0; j < a.size(); j++) {
			if (a[i] == b[j]) {
				match++;
				break;
			}
			if (a[i] == -b[j]) {
				match++;
				inv = true;
				break;
			}
		}
	}
	if (match == a.size()) {
		if (inv) return -1;
		return 1;
	}
	return 0;
}

WrappingCont Converter::ComputeWrappingCont (int v0, int v1)
{
	//compute if an edge goes outside the box
	Wrapping x = GetWrapping (vertexListRaw[v0].X, vertexListRaw[v1].X, xmin, xmax);
	Wrapping y = GetWrapping (vertexListRaw[v0].Y, vertexListRaw[v1].Y, ymin, ymax);
	Wrapping z = GetWrapping (vertexListRaw[v0].Z, vertexListRaw[v1].Z, zmin, zmax);
	//cout << vertexListRaw[v0].X << " " << vertexListRaw[v1].X << " " << xmin << " " << xmax << endl;
	//cout << x << y << z << endl;
	return WrappingCont (x, y, z);
}
Wrapping Converter::GetWrapping (double p0, double p1, double min, double max)
{
	//compute if an edge of specific direction p0-->p1
	// goes outside the box
	if (p0 < min && p1 > min && p1 < max) return Wrapping::plus;
	if (p1 > max && p0 > min && p0 < max) return Wrapping::plus;
	if (p0 > max && p1 > min && p1 < max) return Wrapping::minus;
	if (p1 < min && p0 > min && p0 < max) return Wrapping::minus;
	return Wrapping::asterix;
}

bool Converter::SaveFe (ofstream &se_file)
{
	//Generates input file for SurfaceEvolver
	int i;
	int j;
	if (!se_file.is_open()) {
		cout << "Can not open output file." << endl;
		return false;
	}
	cout << "Generating output for Surface Evolver..." << endl;
	se_file << "TORUS_FILLED" << endl << endl;
	//se_file <<"SYMMETRIC_CONTENT" <<  endl;
	//se_file << "PHASEFILE \"foam.phase\"" << endl;
	se_file << "periods" << endl;
	se_file << xmax <<  " 0.000000 0.000000" << endl;
	se_file << "0.000000 " << ymax << " 0.000000" << endl;
	se_file << "0.000000 0.000000 " << zmax << endl;

	se_file << endl << "vertices" << endl;
	for (i = 0; i < vertexListUnique.size(); i++) {
		se_file << i + 1 << " " << vertexListUnique[i].X << " " << vertexListUnique[i].Y << " " << vertexListUnique[i].Z << endl;
	}

	se_file << endl << "edges" << endl;
	for (i = 0; i < edgeList.size(); i++) {
		se_file << i + 1 << " " << edgeList[i].V0 << " " << edgeList[i].V1 << " " << edgeList[i].wrappingCont.ToString() << endl;
	}

	se_file << endl << "faces" << endl;
	for (i = 0; i < surfaceList.size(); i++) {
		se_file << i + 1 << " ";
		for (j = 0; j < surfaceList[i].edgeList.size(); j++) {
			se_file << surfaceList[i].edgeList[j] << " ";
		}
		se_file << endl;
	}
	se_file << endl << "bodies" << endl;

	for (i = 0; i < volumeList.size(); i++) {
		se_file << i + 1 << " ";
		for (j = 0; j < volumeList[i].surfaceList.size(); j++) {
			se_file << volumeList[i].surfaceList[j] << " ";
		}
		se_file << endl;
	}
	return true;
}

bool Converter::SaveCmd (ofstream &cmd_file)
{
	if (!cmd_file.is_open()) {
		cout << "Can not open output cmd file." << endl;
		return false;
	}
	cout << "Generating cmd file for Surface Evolver..." << endl;

	for (int i = 0; i < volumeList.size(); i++) {
		cmd_file << "set body[" << i + 1 << "].facet color green" << endl;
	}
	cmd_file << "opt20:={r;nn := 1;while nn < 20 do { g 50;u 10;g 50;u 10;j 0.01;;nn:=nn+1}}" << endl;
	cmd_file << "CONNECTED" << endl;
	cmd_file << "read \"stl.cmd\"" << endl;
	cmd_file << "do_stl:={detorus;stl >>> \"PeriodicRVE.stl\"}" << endl;
	//Other cmd files
	for (int i = 0; i < cmdFiles.size(); i++) {
		cout << "\t" << cmdFiles[i] << " ...loaded" << endl;
		cmd_file << "read \"" << cmdFiles[i] << "\"" << endl;
	}
}

bool Converter::SaveGnuPlot (ofstream &gnu_file)
{
	cout << "Generating output for GnuPlot...";
	cout << " Not implemented for input files... Skipped" << endl;
	return false;
}

