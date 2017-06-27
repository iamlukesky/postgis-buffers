
# Topology exception

  ERROR:  GEOSBuffer: TopologyException: depth mismatch at  at 679300 6557900
  ********** Error **********

  ERROR: GEOSBuffer: TopologyException: depth mismatch at  at 679300 6557900
  SQL state: XX000

Det här är precis vid en trafikplats. Troligtvis 3D geometri just där? Testar st_force2d

## resultat

  ERROR:  Column has Z dimension but geometry does not

