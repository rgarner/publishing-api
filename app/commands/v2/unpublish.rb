module Commands
  module V2
    class Unpublish < BaseCommand
      def call
        content_id = payload.fetch(:content_id)
        content_item = find_unpublishable_content_item(content_id)

        unless content_item.present?
          message = "Could not find a content item to unpublish"
          raise_command_error(404, message, fields: {})
        end

        unless Location.where(content_item: content_item).exists?
          message = "Cannot unpublish content with no location"
          raise_command_error(422, message, fields: {})
        end

        check_version_and_raise_if_conflicting(content_item, previous_version_number)

        if draft_present?(content_id)
          if payload[:discard_drafts] == true
            DiscardDraft.call(
              {
                content_id: content_id,
                locale: locale,
              },
              downstream: downstream,
              callbacks: callbacks,
              nested: true,
            )
          else
            message = "Cannot unpublish with a draft present"
            raise_command_error(422, message, fields: {})
          end
        end

        case type = payload.fetch(:type)
        when "withdrawal"
          withdraw(content_item)
        when "redirect"
          redirect(content_item)
        when "gone"
          gone(content_item)
        else
          message = "#{type} is not a valid unpublishing type"
          raise_command_error(422, message, fields: {})
        end

        delete_linkable(content_item)

        Success.new(content_id: content_id)
      end

    private

      def withdraw(content_item)
        State.unpublish(content_item,
          type: "withdrawal",
          explanation: payload.fetch(:explanation),
        )

        after_transaction_commit do
          send_content_item_downstream(content_item)
        end
      end

      def redirect(content_item)
        unpublishing = State.unpublish(content_item,
          type: "redirect",
          alternative_path: payload.fetch(:alternative_path),
        )

        redirect = RedirectPresenter.present(
          base_path: Location.find_by(content_item: content_item).base_path,
          publishing_app: content_item.publishing_app,
          destination: unpublishing.alternative_path,
          public_updated_at: Time.zone.now,
        )

        send_downstream(redirect)
      end

      def gone(content_item)
        State.unpublish(content_item,
          type: "gone",
          alternative_path: payload[:alternative_path],
          explanation: payload[:explanation],
        )

        gone = GonePresenter.present(
          base_path: Location.find_by(content_item: content_item).base_path,
          publishing_app: content_item.publishing_app,
          alternative_path: payload[:alternative_path],
          explanation: payload[:explanation],
        )

        send_downstream(gone)
      end

      def delete_linkable(content_item)
        Linkable.find_by(content_item: content_item).try(:destroy)
      end

      def send_downstream(downstream_payload)
        return unless downstream

        PresentedContentStoreWorker.perform_async(
          content_store: Adapters::ContentStore,
          payload: downstream_payload.merge(payload_version: event.id),
          request_uuid: GdsApi::GovukHeaders.headers[:govuk_request_id],
        )
      end

      def locale
        payload.fetch(:locale, ContentItem::DEFAULT_LOCALE)
      end

      def previous_version_number
        payload[:previous_version].to_i if payload[:previous_version]
      end

      def find_unpublishable_content_item(content_id)
        filter = ContentItemFilter.new(scope: ContentItem.where(content_id: content_id))
        filter.filter(locale: locale, state: %w(published unpublished)).first
      end

      def draft_present?(content_id)
        filter = ContentItemFilter.new(scope: ContentItem.where(content_id: content_id))
        filter.filter(locale: locale, state: "draft").exists?
      end

      def send_content_item_downstream(content_item)
        return unless downstream

        PresentedContentStoreWorker.perform_async(
          content_store: Adapters::ContentStore,
          payload: { content_item_id: content_item.id, payload_version: event.id },
          request_uuid: GdsApi::GovukHeaders.headers[:govuk_request_id],
        )
      end
    end
  end
end
