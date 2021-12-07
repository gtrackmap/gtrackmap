require "athena-console"
require "./trackmap-cli/run.cr"

module Trackmap::Cli
  VERSION = "0.1.0"

  application = ACON::Application.new("Trackmap")
  application.add(Run.new)
  application.default_command("run", true)
  application.run
end
