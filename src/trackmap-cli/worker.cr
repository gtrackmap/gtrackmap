require "athena-console"
require "baked_file_system"
require "http/client"
require "xml"
require "file_utils"
require "compress/zip"
require "./gpx"
require "./job"

module Trackmap::Cli
  class Worker
    class Bitmaps
      extend BakedFileSystem

      bake_folder "#{__DIR__}/../../resources/bitmaps"
    end

    private getter output

    def initialize(@output : ACON::Output::Interface)
    end

    def run(job)
      workdir = File.tempname("trackmap")
      output.puts("Creating tempdir #{workdir}", :debug)
      FileUtils.mkdir(workdir)

      begin
        Dir.cd(workdir) do
          output.puts("Parsing tracks", :debug)
          tracks = parse_tracks(job.tracks, job.radius)
          output.puts("Fetching osm data", :debug)
          osm_data = fetch_osm_data(tracks, job.pois, job.radius) do |body|
            File.tempfile("mapdata", ".osm") do |file|
              IO.copy(body, file)
            end
          end

          begin
            output.puts("Processing map", :debug)
            process_map(osm_data.path, job.map_style, job.map_typ)
            output.puts("Processing pois", :debug)
            process_pois(osm_data.path, job.pois)

            out_path = File.join(job.out_dir, "garmin.zip")
            output.puts("Writing output to #{out_path}", :debug)
            File.open(out_path, "w+") do |zip|
              Compress::Zip::Writer.open(zip) do |s|
                job.pois.each do |poi|
                  s.add("Garmin/poi/#{poi.id}.gpi", File.open("#{poi.id}.gpi"))
                end

                s.add("Garmin/gmapbmap.img", File.open("gmapsupp.img"))
              end
            end
          ensure
            osm_data.delete
          end
        end

        output.puts("Done!", :debug)
      ensure
        FileUtils.rm_r(workdir)
      end
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

      begin
        error = IO::Memory.new

        status = Process.run("mkgmap", [
          "--latin1",
          "--style-file=#{style_file}",
          "--family-id=#{family_id}",
          "--gmapsupp",
          osm_data,
          typ_file
        ], error: error)

        unless status.success?
          raise error.to_s
        end
      end
    end

    private def process_pois(osm_data, pois)
      pois.each do |poi|
        poi_file = File.tempfile("#{poi.id}", ".osm") do |file|
          error = IO::Memory.new
          filter = poi.osm_query.map do |query|
            query.includes?('=') ? query : "#{query}="
          end

          status = Process.run(
            "osmfilter", [osm_data, "--keep=#{filter.join(" or ")}"],
            output: file,
            error: error
          )

          unless status.success?
            file.delete
            raise error.to_s
          end
        end

        bitmap_file = File.tempfile("#{poi.id}", ".bmp") do |file|
          IO.copy(Bitmaps.get("#{poi.id}.bmp"), file)
        end

        error = IO::Memory.new
        status = Process.run("gpsbabel", [
          "-i", "osm",
          "-f", poi_file.path,
          "-o", "garmin_gpi,category=#{poi.description},bitmap=#{bitmap_file.path}",
          "-F", "#{poi.id}.gpi"
        ], error: error)

        poi_file.delete
        bitmap_file.delete

        raise error.to_s unless status.success?
      end
    end

    private def fetch_osm_data(tracks, pois, radius)
      query = String.build do |io|
        io << "[timeout:1800];"
        io << '('
        pois.flat_map(&.osm_query).each do |poi_query|
          tracks.each do |track|
            io << "node[" << poi_query << "](around:" << radius
            track.points.each do |point|
              io << ',' << point.latitude << ',' << point.longitude
            end
            io << ");"
          end
        end

        tracks.each do |track|
          io << "way(around:" << radius
          track.points.each do |point|
            io << ',' << point.latitude << ',' << point.longitude
          end
          io << ");"
        end

        io << ");(._;>;);out;"
      end

      body = HTTP::Params.build do |form|
        form.add("data", query)
      end

      HTTP::Client.post("https://overpass-api.de/api/interpreter", body: body) do |response|
        raise response.body_io.gets_to_end unless response.success?
        yield response.body_io
      end
    end
  end
end
