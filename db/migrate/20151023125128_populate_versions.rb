class PopulateVersions < ActiveRecord::Migration
  class DraftContentItem < ActiveRecord::Base
  end

  class LiveContentItem < ActiveRecord::Base
  end

  def change
    [DraftContentItem, LiveContentItem, LinkSet].each do |versionable|
      versionable.all.each do |item|
        version = Version.find_by(target: item)

        unless version
          version = Version.new(target: item, number: item.version)
          version.save!(validate: false)
        end
      end
    end
  end
end
