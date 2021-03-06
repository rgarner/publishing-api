require "rails_helper"

RSpec.describe "Redirecting content items that are redrafted" do
  let(:put_content) { Commands::V2::PutContent }
  let(:publish) { Commands::V2::Publish }

  let(:draft_payload) do
    {
      content_id: SecureRandom.uuid,
      base_path: "/foo",
      title: "Title",
      publishing_app: "publisher",
      rendering_app: "frontend",
      format: "guide",
      routes: [{ path: "/foo", type: "exact" }],
    }
  end

  let(:moved_payload) do
    draft_payload.merge(
      base_path: "/bar",
      routes: [{ path: "/bar", type: "exact" }],
    )
  end

  let(:publish_payload) do
    {
      content_id: draft_payload.fetch(:content_id),
      update_type: "major",
    }
  end

  before do
    stub_request(:put, %r{.*content-store.*/content/.*})
  end

  context "when a published item's base path is updated" do
    before do
      put_content.call(draft_payload)
      publish.call(publish_payload)
      put_content.call(moved_payload)
    end

    it "sets up the content items in the expected initial state" do
      expect(ContentItem.count).to eq(3)

      content_item = ContentItem.first
      expect(content_item.format).to eq("guide")
      expect(state(content_item)).to eq("published")
      expect(path(content_item)).to eq("/foo")
      expect(version(content_item)).to eq(1)

      content_item = ContentItem.second
      expect(content_item.format).to eq("guide")
      expect(state(content_item)).to eq("draft")
      expect(path(content_item)).to eq("/bar")
      expect(version(content_item)).to eq(2)

      content_item = ContentItem.third
      expect(content_item.format).to eq("redirect")
      expect(state(content_item)).to eq("draft")
      expect(path(content_item)).to eq("/foo")
      expect(version(content_item)).to eq(1)
    end

    context "when the item is published" do
      before do
        publish.call(publish_payload)
      end

      it "transitions the states of the content items correctly" do
        expect(ContentItem.count).to eq(3)

        content_item = ContentItem.first
        expect(content_item.format).to eq("guide")
        expect(state(content_item)).to eq("unpublished"),
          "This content item is eligible for both superseding and unpublishing.
          When this happens, the 'unpublished' state should be chosen."
        expect(path(content_item)).to eq("/foo")
        expect(version(content_item)).to eq(1)

        content_item = ContentItem.second
        expect(content_item.format).to eq("guide")
        expect(state(content_item)).to eq("published")
        expect(path(content_item)).to eq("/bar")
        expect(version(content_item)).to eq(2)

        content_item = ContentItem.third
        expect(content_item.format).to eq("redirect")
        expect(state(content_item)).to eq("published")
        expect(path(content_item)).to eq("/foo")
        expect(version(content_item)).to eq(1)
      end
    end
  end

  context "when a redrafted item's base path is updated" do
    before do
      put_content.call(draft_payload)
      publish.call(publish_payload)
      put_content.call(draft_payload)
      put_content.call(moved_payload)
    end

    it "sets up the content items in the expected initial state" do
      expect(ContentItem.count).to eq(3)

      content_item = ContentItem.first
      expect(content_item.format).to eq("guide")
      expect(state(content_item)).to eq("published")
      expect(path(content_item)).to eq("/foo")
      expect(version(content_item)).to eq(1)

      content_item = ContentItem.second
      expect(content_item.format).to eq("guide")
      expect(state(content_item)).to eq("draft")
      expect(path(content_item)).to eq("/bar")
      expect(version(content_item)).to eq(2)

      content_item = ContentItem.third
      expect(content_item.format).to eq("redirect")
      expect(state(content_item)).to eq("draft")
      expect(path(content_item)).to eq("/foo")
      expect(version(content_item)).to eq(1)
    end

    context "when the redrafted item is published" do
      before do
        publish.call(publish_payload)
      end

      it "transitions the states of the content items correctly" do
        expect(ContentItem.count).to eq(3)

        content_item = ContentItem.first
        expect(content_item.format).to eq("guide")
        expect(state(content_item)).to eq("unpublished"),
          "This content item is eligible for both superseding and unpublishing.
          When this happens, the 'unpublished' state should be chosen."
        expect(path(content_item)).to eq("/foo")
        expect(version(content_item)).to eq(1)

        content_item = ContentItem.second
        expect(content_item.format).to eq("guide")
        expect(state(content_item)).to eq("published")
        expect(path(content_item)).to eq("/bar")
        expect(version(content_item)).to eq(2)

        content_item = ContentItem.third
        expect(content_item.format).to eq("redirect")
        expect(state(content_item)).to eq("published")
        expect(path(content_item)).to eq("/foo")
        expect(version(content_item)).to eq(1)
      end

      it "does not raise an error on subsequent redrafts and publishes" do
        expect {
          put_content.call(draft_payload)
          publish.call(publish_payload)
        }.not_to raise_error

        expect {
          put_content.call(draft_payload)
          publish.call(publish_payload)
        }.not_to raise_error
      end
    end
  end

  def path(content_item)
    Location.find_by!(content_item: content_item).base_path
  end

  def version(content_item)
    UserFacingVersion.find_by!(content_item: content_item).number
  end

  def state(content_item)
    State.find_by!(content_item: content_item).name
  end
end
