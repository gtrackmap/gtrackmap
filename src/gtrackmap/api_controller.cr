require "mime"
require "athena"
require "baked_file_system"
require "http/client"
require "xml"
require "file_utils"
require "compress/zip"
require "./gpx"

class GTrackmap::APIController < ATH::Controller
  class StaticFiles
    extend BakedFileSystem

    bake_folder "#{__DIR__}/../../resources"
    bake_folder "#{__DIR__}/../../frontend"
  end

  @[ARTA::Get("/")]
  def index : ATH::Response
    file = StaticFiles.get("index.html")
    ATH::Response.new(file.gets_to_end, headers: HTTP::Headers{"content-type" => "text/html"})
  end

  @[ARTA::Get("/{path}", requirements: {"path" => /.*/})]
  def catchall(path : String) : ATH::Response
    file = StaticFiles.get?(path)
    return ATH::Response.new("Not found", status: 404) if file.nil?

    content_type = MIME.from_filename(path)
    ATH::Response.new(file.gets_to_end, headers: HTTP::Headers{"content-type" => content_type})
  end

  @[ARTA::Post("/api/build-overpass-query")]
  def build_overpass_query(request : ATH::Request) : ATH::Response
    tracks = [] of String
    radius = 500

    HTTP::FormData.parse(request.request) do |part|
      case part.name
      when "tracks"
        tempfile = File.tempfile("track", ".gpx") do |file|
          IO.copy(part.body, file)
        end

        tracks << tempfile.path
      when "radius"
        radius = part.body.gets_to_end.to_i
      else
        raise ATH::Exceptions::BadRequest.new("Invalid request body")
      end
    end

    track_data = parse_tracks(tracks, radius)
    query = build_osm_query(track_data, radius)

    ATH::Response.new(query, headers: HTTP::Headers{"content-type" => "text/plain"})
  end

  @[ARTA::Post("/api/build-map")]
  def build_map(request : ATH::Request) : ATH::Response
    map_data = nil
    style = StaticFiles.get("style.zip")
    typ = StaticFiles.get("typ.txt")

    HTTP::FormData.parse(request.request) do |part|
      case part.name
      when "osm-data"
        map_data = File.tempfile("mapdata", ".osm") do |file|
          IO.copy(part.body, file)
        end
      when "style"
        if part.size.try { |size| size > 0 }
          map_style = IO::Memory.new.tap { |io| IO.copy(part.body, io) }
        end
      when "typ"
        if part.size.try { |size| size > 0 }
          typ = IO::Memory.new.tap { |io| IO.copy(part.body, io) }
        end
      else
        raise ATH::Exceptions::BadRequest.new("Invalid request body")
      end
    end

    if map_data.nil?
      raise ATH::Exceptions::BadRequest.new("Missing OSM data")
    end

    style_file = File.tempfile("style", ".zip") do |file|
      IO.copy(style, file)
    end

    typ_file = File.tempfile("typ", ".txt") do |file|
      IO.copy(typ, file)
    end

    raise "Mapdata doesn't exist" unless File.exists?(map_data.not_nil!.path)
    data = IO::Memory.new

    begin
      Compress::Zip::Writer.open(data) do |zip|
        process_map(map_data.not_nil!.path, style_file.path, typ_file.path) do |io|
          puts "Addig #gmapbmap.img"
          zip.add("Garmin/gmapbmap.img", io)
        end
      end
    ensure
      style_file.delete
      typ_file.delete
      map_data.try(&.delete)
    end

    puts "Done building map"

    ATH::Response.new(data.to_s, headers: HTTP::Headers{"content-disposition" => ATH::HeaderUtils.make_disposition(:attachment, "map.zip")})
  end

  private def parse_tracks(track_files, radius)
    track_files.flat_map do |track_file|
      error = IO::Memory.new

      gpsbabel_args = [
        "-i", "gpx",
        "-o", "gpx",
        "-f", track_file,
        "-x", "simplify,crosstrack,error=#{radius / 2_000}k",
        "-F", "-",
      ]

      Process.run("gpsbabel", gpsbabel_args, error: error) do |gpsbabel|
        GPX.parse(gpsbabel.output).tracks
      end.tap { raise error.to_s unless $?.success? }
    end
  end

  private def process_map(osm_data, style_file, typ_file)
    family_id = nil

    File.open(typ_file) do |f|
      f.each_line do |line|
        family_id = line[4..-1] if line.starts_with?("FID=")
      end
    end

    error = IO::Memory.new

    tempdir = File.tempname("mkgmap")
    Dir.mkdir(tempdir)

    begin
      status = Process.run("mkgmap", [
        "--latin1",
        "--style-file=#{style_file}",
        "--family-id=#{family_id}",
        "--output-dir=#{tempdir}",
        "--gmapsupp",
        osm_data,
        typ_file,
      ], error: error)

      unless status.success?
        raise error.to_s
      end

      yield File.open("#{tempdir}/gmapsupp.img")
    ensure
      FileUtils.rm_rf(tempdir)
    end
  end

  private def build_osm_query(tracks, radius)
    String.build do |io|
      io << "[timeout:1800];"
      io << '('
      tracks.each do |track|
        io << "way(around:" << radius
        track.points.each do |point|
          io << ',' << point.latitude << ',' << point.longitude
        end
        io << ");"
      end

      io << ");(._;>;);out;"
    end
  end
end
