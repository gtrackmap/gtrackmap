require "xml"

module GTrackmap
  class GPX
    NS = "http://www.topografix.com/GPX/1/1"

    class Track
      record Point, latitude : Float64, longitude : Float64

      getter points : Array(Point)

      def initialize(@points)
      end

      def self.from_xml(node : XML::Node)
        points = node.xpath_nodes(".//gpx:trkpt", {"gpx" => NS}).map do |node|
          Point.new(node["lat"].to_f, node["lon"].to_f)
        end

        new(points)
      end
    end

    getter tracks : Array(Track)

    def initialize(@tracks)
    end

    def self.parse(io : IO)
      gpx = XML.parse(io)
      tracks = gpx.xpath_nodes("//gpx:trk", {"gpx" => NS}).map do |node|
        Track.from_xml(node)
      end

      new(tracks)
    end
  end
end
