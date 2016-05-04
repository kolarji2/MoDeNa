#include "converter.hpp"

using namespace std;



Converter::Converter() {}

bool Converter::LoadGeo (ifstream &fin)
{
	string line;
	string val;
	vector<string> sl;
	//init const
	xmin = 0;
	ymin = xmin;
	zmin = xmin;
	xmax = 1;
	ymax = xmax;
	zmax = xmax;
	threshold=0.00001;
	//Cache mem size
	int cacheMem = 50;
	//Structure alloc
	bool reservedVRaw = false;
	bool reservedVUnique=false;
	bool reservedE = false;
	bool reservedSurf = false;
	bool reservedVol = false;
	int i=0;
	int id=0;
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
		if (!reservedSurf && surfaceList.size() % cacheMem == 0) {
			surfaceList.reserve (surfaceList.size() + cacheMem);
			reservedSurf = true;
		}
		if (!reservedVol && volumeList.size() % cacheMem == 0) {
			volumeList.reserve (volumeList.size() + cacheMem);
			reservedVol = true;
		}

		//parsing line
		
		sl = ParseLnGeo (line);
		if (sl[0] == "Point") {
			reservedVRaw = false;
			Vertex v=Vertex (stod (sl[2]) - 1, stod (sl[3]) - 1, stod (sl[4]) - 1);
			AddVertex(v);
		} else if (sl[0] == "Line") {
			reservedE = false;
			int v0 = stoi (sl[2])-1;
			int v1 = stoi (sl[3])-1;			
			WrappingCont wrappingCont =ComputeWrappingCont(v0, v1);			
			v0=vertexListMapping[v0]+1;
			v1=vertexListMapping[v1]+1;
			Edge e(v0, v1, wrappingCont);
			AddEdge(e);
		} else if (sl[0] == "Line Loop") {
			Surface srf(sl,edgeListMap);
			AddSurface(srf);
		} else if (sl[0] == "Surface Loop") {
			Volume vol(sl,surfaceListMap);
			AddVolume(vol);
		}
	}	
	return true;
};
vector<string> Converter::ParseLnGeo (string line)
{
	bool id = false;
	bool order = false;
	bool value = false;
	int i = 0;
	int previ = 0;
	string val;
	vector<string> strVec;

	while (line[previ] == ' ') previ++;
	for (i = previ; i < line.size(); i++) {
		if (!id && line[i] == '(') {
			val = line.substr (previ, i - previ - 1);
			if (val == "Volume") {
				while (line[i] != ';') i++;
				i++;
				if (i >= line.size()) {
					strVec.push_back (val);
					break;
				}
				while (line[i] == ' ') i++;
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
	}
	return strVec;
};

void Converter::AddVertex(Vertex v) {
	vertexListRaw.push_back (v);
	bool vertExist=false;
	int i=0;
	//check if added vertex is already in list if is outside the box
	if (v.X<xmin || v.Y<ymin || v.Z<zmin || v.X>xmax || v.Y>ymax || v.Z>zmax) {
		//correction, to place vertex inside the box
		if (v.X<xmin) v.X=v.X+xmax;
		if (v.X>xmax) v.X=v.X-xmax;
		if (v.Y<ymin) v.Y=v.Y+ymax;
		if (v.Y>ymax) v.Y=v.Y-ymax;
		if (v.Z<zmin) v.Z=v.Z+zmax;
		if (v.Z>zmax) v.Z=v.Z-zmax;
		//find if there already exists same vertex;
		vertExist=false;
		for (i=0;i<vertexListUnique.size();i++) {
			Vertex *vOld=&vertexListUnique[i];
			if ((Abs(vOld->X-v.X)<threshold) && 
				(Abs(vOld->Y-v.Y)<threshold) && 
				(Abs(vOld->Z-v.Z)<threshold)) {
				vertExist=true;
				break;
			}
		}
		if (!vertExist) vertexListUnique.push_back(v);
		vertexListMapping.push_back(i);
	} else {
		vertexListMapping.push_back(vertexListUnique.size());
		vertexListUnique.push_back(v);
	}
}
void Converter::AddEdge(Edge e) {
	int id=1;
	bool edgeExist=false;
	for (int i=0;i<edgeList.size();i++) {
		Edge *eOld=&edgeList[i];
		if (eOld->Equal(e)){
			edgeExist=true;
			break;
		}
		if (eOld->EqualInv(e)) {
			edgeExist=true;
			id=-id;
			break;
		}
		id++;
	}
	edgeListMap.push_back(id);
	if (!edgeExist) {
		edgeList.push_back (e);
	}
}

void Converter::AddSurface(Surface s) {
	int id=1;
	bool surfExist=false;
	for (int i=0;i<surfaceList.size();i++) {
		int result=CompareSurfaces(s.edgeList,surfaceList[i].edgeList);
		if (result==1 || result==-1) {
			id=id*result;
			surfExist=true;
			break;
		}
		id++;
	}
	surfaceListMap.push_back(id);
	if (!surfExist) surfaceList.push_back(s);
}



void Converter::AddVolume(Volume v) {
	bool volExist=false;
	sort(v.surfaceList.begin(),v.surfaceList.end());
	for (int i=0;i<v.surfaceList.size();i++) {
		int result=CompareSurfaces(v.surfaceList,volumeList[i].surfaceList);
		if (result==1 || result==-1) {
			volExist=true;
			break;
		}
	}
	if(!volExist)	volumeList.push_back (v);
}

int Converter::CompareSurfaces(vector<int> &a, vector<int> &b) {
	if (a.size()!=b.size()) return 0;
	int match=0;
	bool inv=false;
	for (int i=0;i<a.size();i++) {
		//find if all lines matches
		for (int j=0;j<a.size();j++) {
				if (a[i]==b[j]) {
					match++;
					break;
				}
				if (a[i]==-b[j]) {
					match++;
					inv=true;
					break;
				}
			}
	}
	if (match==a.size()) {
			if (inv) return -1;
			return 1;
	}
	return 0;
}

WrappingCont Converter::ComputeWrappingCont (int v0, int v1)
{
	//compute if an edge goes outside the box
	
	Wrapping x=GetWrapping(vertexListRaw[v0].X,vertexListRaw[v1].X,xmin,xmax);
	Wrapping y=GetWrapping(vertexListRaw[v0].Y,vertexListRaw[v1].Y,ymin,ymax);
	Wrapping z=GetWrapping(vertexListRaw[v0].Z,vertexListRaw[v1].Z,zmin,zmax);
	//cout << vertexListRaw[v0].X << " " << vertexListRaw[v1].X << " " << xmin << " " << xmax << endl;
	//cout << x << y << z << endl;
	return WrappingCont(x,y,z);
}
Wrapping Converter::GetWrapping (double p0,double p1,double min,double max) {
		//compute if an edge of specific position p0-->p1
		// goes outside the plus=plus;
		if (p0 < min && p1>min && p1<max) return Wrapping::plus;
		if (p1 > max && p0>min && p0<max) return Wrapping::plus;
		if (p0 > max && p1>min && p1<max) return Wrapping::minus;
		if (p1 < min && p0>min && p0<max) return Wrapping::minus;		
		return Wrapping::asterix;
	}

bool Converter::SaveFe (ofstream &se_file)
{
	int i;
	int j;
	//Generates input file for SurfaceEvolver
	if (!se_file.is_open())
	{
	cout << "Can not open output file." << endl;
	return false;
	}
	
	cout << "Generating output for Surface Evolver..." << endl;
	
	

	se_file << "TORUS_FILLED" << endl << endl;
	se_file <<"SYMMETRIC_CONTENT" <<  endl;
	//se_file << "PHASEFILE \"foam.phase\"" << endl;
	se_file << "periods" << endl;
	se_file << xmax <<  " 0.000000 0.000000" << endl;
	se_file << "0.000000 " << ymax <<" 0.000000" << endl;
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

	cout << "...Finished" << endl;
	

	return true;
}

bool Converter::SaveCmd(ofstream &cmd_file) {
	if (!cmd_file.is_open()) {
		cout << "Can not open output cmd file." << endl;
		return false;
	}
	cout << "Generating cmd file for Surface Evolver..." << endl;
	
	for(int i=0;i<volumeList.size();i++) {
		cmd_file << "set body[" << i+1 << "].facet color red" << endl;
	}	
	cmd_file << "opt:={nn := 1;while nn < 100 do { g 50;u;g 50;u;j 0.01;;nn:=nn+1}}" << endl;
	cmd_file << "function real porosity() {tvol:="<< xmax*ymax*zmax <<";vol:=0;nn:=1;while nn<"<< volumeList.size() << " do {vol:=vol+body[nn].volume;nn:=nn+1};return vol/tvol}" << endl;
	cmd_file << "por:={tvol:="<< xmax*ymax*zmax <<";vol:=0;nn:=1;while nn<"<< volumeList.size()<< " do {vol:=vol+body[nn].volume;nn:=nn+1};printf \"\\n Porosity (cells/volume of box): %f \\n\",vol/tvol};" << endl;
	cmd_file << "porC:={tvol:="<< xmax*ymax*zmax <<";vol:=0;nn:=1;foreach body bb do {vol:=vol+bb.volume};printf \"\\n Porosity (volume of all structures/volume of box): %f \\n\",vol/tvol};" << endl; //complementary
	//cmd_file << "porCC:={tvol:="<< xmax*ymax*zmax <<";vol:=0;nn:="<< volumeList.size() <<";while nn<"<< nvolumes+1 << " do {vol:=vol+body[nn].volume;nn:=nn+1};printf \"\\n Porosity (cells/volume of box): %f \\n\",vol/tvol};" << endl;
	cmd_file << "acs:={tt:=0;nn:=1;while nn<"<< volumeList.size() << " do {tt:=body[nn].volume*3/4/PI;printf \"Size of the cell %d: %f \\n\",nn,2*pow(tt,0.33333333);nn:=nn+1}}" << endl; //avrage cell size
	cmd_file << "por90:={while porosity()<0.90 do {g;u;u}}" << endl;
	cmd_file << "por91:={while porosity()<0.91 do {g;u;u}}" << endl;
	cmd_file << "por92:={while porosity()<0.92 do {g;u;u}}" << endl;
	cmd_file << "por93:={while porosity()<0.93 do {g;u;u}}" << endl;
	cmd_file << "por94:={while porosity()<0.94 do {g;u;u}}" << endl;
	cmd_file << "por95:={while porosity()<0.95 do {g;u;u}}" << endl;
	cmd_file << "por96:={while porosity()<0.96 do {g;u;u}}" << endl;
	cmd_file << "por97:={while porosity()<0.97 do {g;u;u}}" << endl;
	cmd_file << "por98:={while porosity()<0.98 do {g;u;u}}" << endl;
	cmd_file << "por99:={while porosity()<0.99 do {g;u;u}}" << endl;
	cmd_file << "CONNECTED" <<endl;
	cmd_file << "read \"stl.cmd\""<< endl;
	cmd_file << "do_stl:={detorus;stl >>> \"PeriodicRVE.stl\"}" << endl;

	
	cout << "...Finished"<< endl;
}
