module Trackmap::Cli
  enum Poi
    Peak
    CampSite
    Information
    DrinkingWater
    PicnicTable
    Shop
    Food
    Lodging

    def id
      to_s.underscore
    end

    def description
      case self
      when .camp_site? then "Camp site"
      when .drinking_water? then "Drinking water"
      when .picnic_table? then "Picnic table"
      else to_s
      end
    end

    def osm_query
      case self
      when .peak? then ["natural=peak"]
      when .camp_site? then ["tourism=camp_site"]
      when .information? then ["tourism=information"]
      when .drinking_water? then ["amenity=drinking_water"]
      when .picnic_table? then ["leisure=picnic_table"]
      when .shop? then ["shop"]
      when .food?
        [
          "amenity=restaurant",
          "amenity=fast_food",
          "amenity=biergarten",
          "amenity=pub",
        ]
      when .lodging?
        [
          "tourism=alpine_hut",
          "tourism=apartment",
          "tourism=chalet",
          "tourism=guest_house",
          "tourism=hostel",
          "tourism=hotel",
          "tourism=motel",
          "tourism=wilderness_hut",
        ]
      else raise "NYI"
      end
    end
  end
end
