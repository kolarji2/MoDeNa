set body[1].facet color red
set body[2].facet color red
set body[3].facet color red
set body[4].facet color red
set body[5].facet color red
set body[6].facet color red
set body[7].facet color red
set body[8].facet color red
set body[9].facet color red
set body[10].facet color red
set body[11].facet color red
set body[12].facet color red
set body[13].facet color red
set body[14].facet color red
set body[15].facet color red
set body[16].facet color red
set body[17].facet color red
set body[18].facet color red
set body[19].facet color red
set body[20].facet color red
set body[21].facet color red
set body[22].facet color red
set body[23].facet color red
set body[24].facet color red
set body[25].facet color red
set body[26].facet color red
set body[27].facet color red
opt:={nn := 1;while nn < 100 do { g 50;u;g 50;u;j 0.01;;nn:=nn+1}}
function real porosity() {tvol:=1;vol:=0;nn:=1;while nn<27 do {vol:=vol+body[nn].volume;nn:=nn+1};return vol/tvol}
por:={tvol:=1;vol:=0;nn:=1;while nn<27 do {vol:=vol+body[nn].volume;nn:=nn+1};printf "\n Porosity (cells/volume of box): %f \n",vol/tvol};
porC:={tvol:=1;vol:=0;nn:=1;foreach body bb do {vol:=vol+bb.volume};printf "\n Porosity (volume of all structures/volume of box): %f \n",vol/tvol};
acs:={tt:=0;nn:=1;while nn<27 do {tt:=body[nn].volume*3/4/PI;printf "Size of the cell %d: %f \n",nn,2*pow(tt,0.33333333);nn:=nn+1}}
por90:={while porosity()<0.90 do {g;u;u}}
por91:={while porosity()<0.91 do {g;u;u}}
por92:={while porosity()<0.92 do {g;u;u}}
por93:={while porosity()<0.93 do {g;u;u}}
por94:={while porosity()<0.94 do {g;u;u}}
por95:={while porosity()<0.95 do {g;u;u}}
por96:={while porosity()<0.96 do {g;u;u}}
por97:={while porosity()<0.97 do {g;u;u}}
por98:={while porosity()<0.98 do {g;u;u}}
por99:={while porosity()<0.99 do {g;u;u}}
CONNECTED
read "stl.cmd"
do_stl:={detorus;stl >>> "PeriodicRVE.stl"}
