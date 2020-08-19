/
	title: Query Camden database of Penalty Charge Notices and parking bays for
	       PCNs issued to ice-cream vans at corner of South Hill Park and and South End Road, NW3
	author: sjt@hillsiders.org

	sources:
		- PCNs for past years: "https://opendata.camden.gov.uk/browse?tags=parking&utf8=T"
		- Camden parking bays: bays.csv
		- PCNs for current financial year: "https://opendata.camden.gov.uk/resource/4k7m-4gkk.csv"
		- metadata: "https://dev.socrata.com/foundry/opendata.camden.gov.uk/4k7m-4gkk"
\
ce:count each
tc:til count@ / indexes of a list

// CONSTANTS
/ Locate corner of South Hill Park and South End Road
bays:("SJSSSSSSSSSJSSSFFSSJSPS";enlist csv)0:`:bays.csv
STATION:first select from bays where bays[`$"Unique Identifier"] = 46049151 / parking bay opposite Hampstead Heath station
CORNER:STATION`Longitude`Latitude
STREETS:`$upper("South End Road";"South Hill Park")
FOCUS:.001 / 1/1000 degree of latitude roughly = 100m

/ Possible Vehicle Category values for an ice-cream van
VANS:`$("1n/A";"Box Van";"Large Van";"Light Van";"Luton Van";"Van";"Unknown";"Other";
	"Van - Side Windows";"Specially Fitted Van";"Special Purpose";"Not Recorded";"Not Codeable";"Mpv")

// PENALTY CHARGE NOTICES
system"z 1" / parse dates as dd/mm/yyyy
DT:"PS*S*F*SPJ" where 1 17 1 6 2 2 1 1 1 1 / data types for CSV columns
// local column names to replace Camden's
LC:`cd`week`ttype`tdesc`ccode`csuffix`cdesc`cctv`zone`street`vcat`vremoved`status`band,
	`err`cancelled`wo`reason`rdesc`foreign`country`appeal`formal,
	`ward`wardname`east`north`long`lat`location`accuracy`upload`socrata
DYLO:1 2 / contravention codes for parking on double yellow lines

localise:{[lc;t] / local column names; table
  update
	date:"d"$cd,
	time:"u"$cd,
	ccode:"J"$2#'string ccode,
	zone:`$3_'string zone
	from lc xcol t }

/ mark records with financial year
loadsrc:{[dt;y;year] update fyr:year from(dt;enlist csv)0:y}

import:{
  yrs:2019 2018 2017;
  csvs:`$":pcn-",/:("-"sv'string{x,'x-1999}yrs),\:".csv";

  dts:3#enlist DT;
  dts[2]:dts[2]where tc[DT]<>LC?`rdesc; / 2017-18 has no Cancellation Reason Description
  `pcn set localise[LC,`fyr;](uj)over loadsrc'[dts;csvs;yrs];
  save `pcn }

/ CURRENT: "https://opendata.camden.gov.uk/resource/4k7m-4gkk.csv" / source of current-year PCNs
refresh:{`pcn set pcn uj localise[LC,`fyr;]loadsrc[DT;;2020] system "curl -s ",CURRENT }

// ACTION
load `pcn
curr:localise[LC,`fyr;]loadsrc[DT;;2020] `$":pcn-current.csv"
/ refresh[]

// QUERIES
/ select records within 100m of station parking bay
inarea:{scope:CORNER+\:-1 1*FOCUS;select from x where long within scope[0],lat within scope[1],street in STREETS}
/ select records on summer days within daylight
onsummerday:{select from x where (null date) or $[`mm;date] within 4 9}

/ qry::select fyr,date,time,ccode,cdesc,street,vcat,status,east,north,long,lat,location,accuracy,socrata
/ 	from (onsummerday inarea pcn)
/ 	where
/ 		vcat in VANS,
/ 		/ ccode in DYLO,
/ 		status<>`Cancelled,
/ 		foreign=`No
qry:{`date`time xdesc select fyr,date,time,ccode,cdesc,street,vcat,status,east,north,long,lat,location,accuracy,socrata
	from (onsummerday inarea x)
	where
		vcat in VANS,
		status<>`Cancelled }

local:select from qry pcn,curr
save `local.csv

show select from local where ccode in DYLO