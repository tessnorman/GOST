////////////////////////////////////////////////////////////////////////////////
////////////////Using the OSRM command to calculate travel times////////////////
////////////////Therese Norman 03-31-2017 modified by Keith Garrett/////////////
////////////////Travel times between all subcounty centroids in [country]//////////
////////////////////////////////////////////////////////////////////////////////


***install files (only once)
***find and replace [working path] and [country] with the correct values for your data
net install osrmtime, from("http://www.uni-regensburg.de/wirtschaftswissenschaften/vwl-moeller/medien/osrmtime")

net get osrmtime, from("http://www.uni-regensburg.de/wirtschaftswissenschaften/vwl-moeller/medien/osrmtime")
*** if this link doesn't work, download osrmtime_online.zip and install directly yourself. Furthermore, if you have not already, you will need to install these other packages.
ssc install spmap
ssc install shp2dta
ssc install mif2dta
shell osrminstall.cmd

****Prepare map (already downloaded the OSM data from Geofabrik and put it in this folder: [country]-latest.osm.pbf)
osrmprepare, mapfile("[working path]\[country]\[country]-latest.osm.pbf") profile(car)

****import a shapefile with long and lat coordinates of subcounty centroids and convert to .dta (this could come from anywhere, just needs to be a dataset with long and lat coordinates)
****This will be the file I will work with
clear
cd [working path]\[country]
shp2dta using [shapefile], data("subC")  coor("SubC_coord")
use subC.dta
keep OBJECTID Lat Long POP2014 /*keep only the necessary variables*/
rename Lat lat_origin
rename Long long_origin
rename OBJECTID IDsubC_origin
rename POP2014 POP2014_origin
save subCorigin.dta, replace /*you want one origin dataset...*/
rename lat_origin lat_dest
rename long_origin long_dest
rename IDsubC_origin IDsubC_dest
rename POP2014_origin POP2014
save subCdest.dta, replace /*and one destination dataset (even though they are exactly the same)*/

use subCorigin.dta, clear
cross using subCdest.dta   /*merge on the subCdest data to create pairwise combinations between ALL origins and ALL destinations*/
save subC_origin_dest.dta, replace /*final dataset ready for osrmtime*/


****calculate travel time and distances:
display "$S_TIME  $S_DATE" /*Display the starttime*/
gen datetime_start="$S_TIME  $S_DATE" /*create a new timestamp variable with starting time */
osrmtime lat_origin long_origin lat_dest long_dest , mapfile("[working path]\[country]\[country]-latest.osrm")
display "$S_TIME  $S_DATE" /*Display the end time*/
gen datetime_end="$S_TIME  $S_DATE" /*create a new timestamp variable with ending time */
save subC_origin_dest.dta, replace

****Calculate MP index
gen distKM=(distance+jumpdist1*6+jumpdist2*6)/1000   /*these calculations are arbitrary, my choice to calculate total travel distance this way*/
replace distKM=0 if distance==0
gen distHour=(duration+jumpdist1/10+jumpdist2/10)/3600 /*these calculations are arbitrary, my choice to calculate total travel time this way*/
replace distHour=0 if duration==0
label var IDsubC_origin "Origin ID"
label var IDsubC_dest "Destination ID (subcounty)"
label var distKM "Distance from origin to destination in km"
label var distHour "Travel time from origin to destination in hours"
label var POP2014 "Population 2014 of destination subcounty"
rename POP2014 POP
order IDsubC_origin IDsubC_dest distance duration jumpdist1 jumpdist2 distKM distHour POP Access, first

****calculate travel time index with different lambdas including own subcounty
gen AccessSomik= POP*exp(-distHour/450) /* 2*a^2=450, a= maximum distance possible across the country: 15h*/

****calculate travel time index with different lambdas including own subcounty
gen MP005= POP*exp(-0.05*distHour)
gen MP01= POP*exp(-0.1*distHour)
gen MP05= POP*exp(-0.5*distHour)
gen MP1= POP*exp(-1*distHour)
gen MP3p8= POP*exp(-3.8*distHour)
gen MP5= POP*exp(-5*distHour)
gen MP7p5= POP*exp(-7.5*distHour)

****calculate travel time index with different lambdas excluding own subcounty
gen own =0
replace own=1 if IDsubC_origin==IDsubC_dest
gen MPdom005= POP*exp(-0.05*distHour) if own==0
gen MPdom01= POP*exp(-0.1*distHour) if own==0
gen MPdom05= POP*exp(-0.5*distHour) if own==0
gen MPdom1= POP*exp(-1*distHour) if own==0
gen MPdom3p8= POP*exp(-3.8*distHour) if own==0
gen MPdom5= POP*exp(-5*distHour) if own==0
gen MPdom7p5= POP*exp(-7.5*distHour) if own==0

***collapse dataset and sum up over subcountyID
collapse (sum) AccessSomik MP005 MP01 MP05 MP1 MP3p8 MP5 MP7p5 MPdom005 MPdom01 MPdom05 MPdom1 MPdom3p8 MPdom5 MPdom7p5, by(IDsubC_origin)

label var IDsubC_origin "Origin subcounty ID"

label var AccessSomik "Market Potential (access to pop) using OSM 03-23-2017, a:15, Somik definition"

label var MP005 "Market Potential (access to pop) using OSM March 2017, lambda:0.005"
label var MP01 "Market Potential (access to pop) using OSM March 2017, lambda:0.01"
label var MP05  "Market Potential (access to pop) using OSM March 2017, lambda:0.5"
label var MP1  "Market Potential (access to pop) using OSM March 2017, lambda:1"
label var MP3p8  "Market Potential (access to pop) using OSM March 2017, lambda:3.8"
label var MP5  "Market Potential (access to pop) using OSM March 2017, lambda:5"
label var MP7p5 "Market Potential (access to pop) using OSM March 2017, lambda:7.5"

label var MPdom005 "Market Potential excluding own (access to pop) using OSM March 2017, lambda:0.005"
label var MPdom01 "Market Potential excluding own (access to pop) using OSM March 2017, lambda:0.01"
label var MPdom05  "Market Potential excluding own (access to pop) using OSM March 2017, lambda:0.5"
label var MPdom1  "Market Potential excluding own (access to pop) using OSM March 2017, lambda:1"
label var MPdom3p8  "Market Potential excluding own (access to pop) using OSM March 2017, lambda:3.8"
label var MPdom5  "Market Potential excluding own (access to pop) using OSM March 2017, lambda:5"
label var MPdom7p5 "Market Potential excluding own (access to pop) using OSM March 2017, lambda:7.5"

save MP_OSM_subC.dta, replace
export excel using "[working path]\[country]\[country]GIS\MP_OSM_UgsubC.xlsx", firstrow(variables) replace
