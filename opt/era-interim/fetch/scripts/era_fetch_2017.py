#!/usr/bin/env python
from api import ECMWFDataServer
server = ECMWFDataServer()
server.retrieve({
"class"   : "ei",
"dataset" : "interim",
"date"    : "2017-10-01/to/2017-12-31",
"expver"  : "1",
"grid"    : "0.75/0.75",
"levelist": "250/300/400/450/500/550/600/650/700/750/800/850/900/950/1000",
"levtype" : "pl",
"param"   : "130.128/129.128",
"step"    : "0",
"stream"  : "oper",
"time"    : "00/06/12/18",
"area"    : "-10/110/-45/155",
"type"    : "an",
"format"  : "netcdf",
"target"  : "era_wv_2017.nc",
})