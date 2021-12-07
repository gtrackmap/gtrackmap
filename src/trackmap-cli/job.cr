require "./poi"

module Trackmap::Cli
  record Job,
    tracks : Array(String),
    map_style : String,
    map_typ : String,
    pois : Array(Poi) = [] of Poi,
    radius : Int32 = 500,
    out_dir : String = "."
end
