require "athena"
require "./gtrackmap/api_controller"

module Trackmap
  VERSION = "0.1.0"

  ATH.run(port: ENV.fetch("GTRACKMAP_PORT", "3000").to_i)
end
