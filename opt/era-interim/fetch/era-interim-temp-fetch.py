#!/usr/bin/env python
from api import ECMWFDataServer

server = ECMWFDataServer()

server.retrieve({
    "class"   : "ei",
    "dataset" : "interim",
    "date"    : "1997-01-01/to/2016-06-30",
    "grid"    : "0.75/0.75",
    "levelist": "250/300/400/450/500/550/600/650/700/750/800/850/900/950/1000",
    "levtype" : "pl",
    "param"   : "130.128,129.128",
    "step"    : "0",
    "stream"  : "oper",
    "time"    : "00:00:00/06:00:00/12:00:00/18:00:00",
	'area'    : "-10/110/-45/155",
    "type"    : "an",
	'format'  : "netcdf",
    "target"  : "19970101_20160630_temp_pl.nc",
})
