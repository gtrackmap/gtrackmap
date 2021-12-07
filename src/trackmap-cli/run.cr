require "./worker"
require "./poi"

module Trackmap::Cli
  class Run < ACON::Command
    @@default_name = "run"
    @@default_description = "Build garmin maps and pois around gpx tracks"

    protected def configure
      argument(
        name: "style",
        mode: ACON::Input::Argument::Mode.flags(REQUIRED),
        description: "The garmin style file to use"
      )

      argument(
        name: "typ",
        mode: ACON::Input::Argument::Mode.flags(REQUIRED),
        description: "The garmin TYP file to use"
      )

      argument(
        name: "track",
        mode: ACON::Input::Argument::Mode.flags(REQUIRED, IS_ARRAY),
        description: "The track(s) to build maps around",
      )

      option(
        name: "poi",
        shortcut: "p",
        value_mode: ACON::Input::Option::Value.flags(REQUIRED, IS_ARRAY),
        description: "Add given poi to output. Valid options are #{Poi.values}",
      )

      option(
        name: "radius",
        shortcut: "r",
        value_mode: ACON::Input::Option::Value.flags(REQUIRED),
        description: "Get map data around given radius (in meters) from tracks",
        default: 500
      )

      option(
        name: "out-dir",
        shortcut: "o",
        value_mode: ACON::Input::Option::Value.flags(REQUIRED),
        description: "Write output to given directory",
        default: "."
      )
    end

    protected def execute(input, output) : Athena::Console::Command::Status
      job = Job.new(
        map_style: input.argument("style", String),
        map_typ: input.argument("typ", String),
        tracks: input.argument("track", Array(String)),
        pois: input.option("poi", Array(String)).map { |poi| Poi.parse(poi) },
        radius: input.option("radius", Int32),
        out_dir: File.expand_path(input.option("out-dir", String)),
      )

      worker = Worker.new(output)
      worker.run(job)

      ACON::Command::Status::SUCCESS
    end
  end
end
