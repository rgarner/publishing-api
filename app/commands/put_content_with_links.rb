module Commands
  class PutContentWithLinks < BaseCommand
    def call(downstream: true)
      if content_item[:content_id]
        draft_content_item = create_or_update_draft_content_item!
        create_or_update_live_content_item!(draft_content_item)
        create_or_update_links!
      end
      UrlReservation.reserve_path!(base_path, content_item[:publishing_app])

      if downstream
        Adapters::DraftContentStore.call(base_path, content_item_without_access_limiting)
        Adapters::ContentStore.call(base_path, content_item_without_access_limiting)

        PublishingAPI.service(:queue_publisher).send_message(content_item_with_base_path)
      end

      Success.new(content_item_without_access_limiting)
    end

  private
    def content_item
      payload.except(:base_path)
    end

    def content_id
      content_item[:content_id]
    end

    def content_item_without_access_limiting
      content_item.except(:access_limited)
    end

    def content_item_with_base_path
      content_item_without_access_limiting.merge(base_path: base_path)
    end

    def content_item_top_level_fields
      LiveContentItem::TOP_LEVEL_FIELDS
    end

    def metadata
      content_item_without_access_limiting.except(*content_item_top_level_fields)
    end

    def create_or_update_live_content_item!(draft_content_item)
      attributes = content_item_attributes.merge(
        draft_content_item: draft_content_item
      )

      LiveContentItem.create_or_replace(attributes) do |item|
        item.assign_attributes_with_defaults(attributes)
      end
    end

    def create_or_update_draft_content_item!
      DraftContentItem.create_or_replace(content_item_attributes) do |item|
        item.assign_attributes_with_defaults(content_item_attributes)
      end
    end

    def content_item_attributes
      content_item_with_base_path
        .slice(*content_item_top_level_fields)
        .merge(metadata: metadata, mutable_base_path: true)
        .except(:version)
    end

    def create_or_update_links!
      LinkSet.create_or_replace(content_id: content_id, links: content_item[:links]) do |link_set|
        link_set.version += 1
      end
    end
  end
end
