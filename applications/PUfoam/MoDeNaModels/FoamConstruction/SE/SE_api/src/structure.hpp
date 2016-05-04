#ifndef structure_hpp
#define structure_hpp
#include <vector>
#include <iostream>
#include <string>
using namespace std;

enum Wrapping {plus=0,minus=1,asterix=2};
enum Coor {x,y,z};

class WrappingCont 
{
public:
		Wrapping x;
		Wrapping y;
		Wrapping z;
		
		inline WrappingCont() {}
		inline WrappingCont(Wrapping x,Wrapping y,Wrapping z) {
			this->x=x;
			this->y=y;
			this->z=z;
			}
		inline string ToString() {

			return GetStr(x)+GetStr(y)+GetStr(z);
		}
		inline string GetStr(Wrapping &w) {
			switch (w)
			{
				case Wrapping::plus: return " +";
				case Wrapping::minus: return " -";
				case Wrapping::asterix: return " *";
				default: return " _";				
			}
		}
		inline bool Equal(WrappingCont &wc) {
				if (wc.x==x && wc.y==y && wc.z==z) return true;
				return false;
			}
		inline bool EqualInv(WrappingCont &wc) {
				if (wc.x==GetInv(x) && wc.y==GetInv(y) && wc.z==GetInv(z)) return true;
				return false;
			}
		inline Wrapping GetInv(Wrapping &w) {
			switch (w)
			{
				case Wrapping::plus: return Wrapping::minus;
				case Wrapping::minus: return Wrapping::plus;
				default: return Wrapping::asterix;				
			}
		}
};

class Vertex
{
public:
	double X;
	double Y;
	double Z;
	int id;
	inline Vertex (double x, double y, double z)
	{
		this->X = x;
		this->Y = y;
		this->Z = z;
	}
	
};

class Edge
{
public:
	int V0;
	int V1;
	int id;
	//enumerate Wrap[3]
	WrappingCont wrappingCont;
	inline Edge (int v0, int v1, WrappingCont wc)
	{
		this->V0 = v0;
		this->V1 = v1;
		this->wrappingCont=wc;
	}
	inline bool Equal(Edge &e) {
			
			if (this->V0==e.V0 && this->V1 ==e.V1) {				
				if (wrappingCont.Equal(e.wrappingCont)) return true;
				}			
			return false;
			}
	inline bool EqualInv(Edge &e) {
			if (this->V0==e.V1 && this->V1 ==e.V0) {				
				if (wrappingCont.EqualInv(e.wrappingCont)) return true;
			}
			return false;
		
		}
};
class Surface
{
public:
	vector<int> edgeList;
	inline Surface (vector<string> &data,vector<int> &edgeListMap) {
		edgeList.reserve (data.size() - 2);
		for (int i = 2; i < data.size(); i++) {
			int edge=stoi (data[i]);
			if (edge>0) edgeList.push_back (edgeListMap[edge-1]);	
			if (edge<0) edgeList.push_back (-edgeListMap[-edge-1]);
		}
	}
};

class Volume
{
public:
	vector<int> surfaceList;
	inline Volume (vector<string> &data,vector<int> &surfaceListMap)
	{
		surfaceList.reserve (data.size() - 2);		
		for (int i = 2; i < data.size(); i++) {
			int srf=stoi (data[i]);
			if (srf>0) surfaceList.push_back (surfaceListMap[srf-1]);
			if (srf<0) surfaceList.push_back (-surfaceListMap[-srf-1]);
			
		}
	}
};

#endif

