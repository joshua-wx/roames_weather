![roames_weather](https://cloud.githubusercontent.com/assets/16043083/26475962/9ccf9106-41fe-11e7-87f4-f5e27921bdd7.png)

# ROAMES Weather Repo

Roames Weather provides an end-to-end system form ingesting unprocessed radar data to delivering storm tracking and analysis visualisation layers.

![image1](https://cloud.githubusercontent.com/assets/16043083/26476034/2dbb44da-41ff-11e7-80ac-231ecfb0d0ce.png)

## Modules

1. prep    - Realtime data archiving from BoM FTP server
1. process - Radar regridding, interpolation, storm identification, storm analysis and archiving
1. vis     - Rendering of kml and custom png imagery
1. climate - Climatological analysis of long-term archive datasets
1. tc      - Analysis of TC cases using eyewall tracking (dev)
1. opt     - Utilities for ingesting radar data
1. etc     - Global config files
1. docs    - Roames Weather Documentation

### Toolkits applied in Roames Weather

1. Region based dealiasing technique - [pyart](https://github.com/ARM-DOE/pyart/)
1. Single Doppler retrieval - [SingleDop](https://github.com/nasa/SingleDop)
1. 3D interpolation - [mirt3D](https://au.mathworks.com/matlabcentral/fileexchange/24177-3d-interpolation)
1. HDFgroup library - [link](https://www.hdfgroup.org/HDF5/release/obtainsrc.html#conf)
1. BoM rapic Library - [link](https://github.com/bom-radar/rapic)
1. BoM odimh5 Library - [link](https://github.com/bom-radar/odim_h5)
1. json c++ library - [link](https://github.com/nlohmann/json)
1. json matlab c++ wrapper library - [link](https://au.mathworks.com/matlabcentral/fileexchange/59166-c++-json-io)

### Publications applied in Roames Weather

1. Maximum Expected Size of Hail - Wilson, C., Ortega, K., & Lakshmanan, V. (2009). Evaluating multi-radar, multi-sensor hail diagnosis with high resolution hail reports. In Preprints, 25th Conference on IIPS (p. P2.9). Seattle, WA: American Meteorological Society. Retrieved from [link](http://www.caps.ou.edu/reu/reu08/Final Papers/Wilson_final_paper.pdf)
1. Single Doppler retrieval - Xu et al., 2006: Background error covariance functions for vector wind analyses using Doppler-radar radial-velocity observations. Q. J. R. Meteorol. Soc., 132, 2887-2904 [doi](http://doi.org/10.1256/qj.05.202)
1. Extended Watershed transform (identification) - Lakshmanan, V., Hondl, K., & Rabin, R. (2009). An Efficient, General-Purpose Technique for Identifying Storm Cells in Geospatial Images. Journal of Atmospheric and Oceanic Technology, 26(3), 523–537. [doi](http://doi.org/10.1175/2008JTECHA1153.1)
1. Improved Echo Top Method (analysis) - Lakshmanan, V., Hondl, K., Potvin, C. K., & Preignitz, D. (2013). An Improved Method for Estimating Radar Echo-Top Height. Weather and Forecasting, 28(2), 481–488. [doi](http://doi.org/10.1175/WAF-D-12-00084.1)
1. Hybrid Storm Tracking - Lakshmanan, V., & Smith, T. (2010). An Objective Method of Evaluating and Devising Storm-Tracking Algorithms. Weather and Forecasting, 25(2), 701–709. [doi](http://doi.org/10.1175/2009WAF2222330.1)

### Datasets applied in Roames Weather

1. ERA-Interim reanalysis (historical 0C and -20C levels) [link](https://www.ecmwf.int/en/research/climate-reanalysis/era-interim)
1. GFS Analysis (real-time 0C and -20C levels) [link](https://rucsoundings.noaa.gov/)
1. BoM Realtime and Historical Radar Data [link](http://reg.bom.gov.au/reguser/)
