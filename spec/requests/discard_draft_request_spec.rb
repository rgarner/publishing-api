require "rails_helper"

RSpec.describe "Discard draft requests", type: :request do
  let(:content_id) { SecureRandom.uuid }
  let(:base_path) { "/vat-rates" }

  describe "POST /v2/content/:content_id/discard-draft" do
    context "when a draft content item exists" do
      let!(:draft_content_item) do
        FactoryGirl.create(:draft_content_item,
          content_id: content_id,
          title: "draft",
          base_path: base_path,
        )
      end

      it "does not send to the live content store" do
        expect(PublishingAPI.service(:live_content_store)).to receive(:put_content_item).never
        expect(WebMock).not_to have_requested(:any, /[^-]content-store.*/)

        post "/v2/content/#{content_id}/discard-draft", {}.to_json

        expect(response.status).to eq(200)
      end

      it "deletes the content item from the draft content store" do
        expect(PublishingAPI.service(:draft_content_store)).to receive(:delete_content_item)
          .with(base_path)

        post "/v2/content/#{content_id}/discard-draft", {}.to_json

        expect(response.status).to eq(200), response.body
      end

      describe "optional locale parameter" do
        let(:french_base_path) { "/tva-tarifs" }

        let!(:french_draft_content_item) do
          FactoryGirl.create(:draft_content_item,
            content_id: content_id,
            title: "draft",
            locale: "fr",
            base_path: french_base_path,
          )
        end

        before do
          stub_request(:delete, Plek.find('draft-content-store') + "/content#{french_base_path}")
        end

        it "does not send to the live content store" do
          expect(PublishingAPI.service(:live_content_store)).to receive(:put_content_item).never
          expect(WebMock).not_to have_requested(:any, /[^-]content-store.*/)

          post "/v2/content/#{content_id}/discard-draft", {}.to_json

          expect(response.status).to eq(200)
        end

        it "only deletes the French content item from the draft content store" do
          expect(PublishingAPI.service(:draft_content_store)).to receive(:delete_content_item)
            .with(french_base_path)

          expect(PublishingAPI.service(:draft_content_store)).not_to receive(:delete_content_item)
            .with(base_path)

          post "/v2/content/#{content_id}/discard-draft", { locale: "fr" }.to_json
        end
      end
    end

    context "when a draft content item does not exist" do
      it "responds with 404" do
        post "/v2/content/#{content_id}/discard-draft", {}.to_json

        expect(response.status).to eq(404)
      end

      it "does not send to either content store" do
        expect(WebMock).not_to have_requested(:any, /.*content-store.*/)
        expect(PublishingAPI.service(:draft_content_store)).not_to receive(:put_content_item)
        expect(PublishingAPI.service(:live_content_store)).not_to receive(:put_content_item)

        post "/v2/content/#{content_id}/discard-draft", {}.to_json
      end

      context "and a live content item exists" do
        before do
          FactoryGirl.create(:live_content_item,
            content_id: content_id,
          )
        end

        it "returns a 422" do
          post "/v2/content/#{content_id}/discard-draft", {}.to_json

          expect(response.status).to eq(422)
        end

        it "does not send to either content store" do
          expect(WebMock).not_to have_requested(:any, /.*content-store.*/)
          expect(PublishingAPI.service(:draft_content_store)).not_to receive(:put_content_item)
          expect(PublishingAPI.service(:live_content_store)).not_to receive(:put_content_item)

          post "/v2/content/#{content_id}/discard-draft", {}.to_json
        end
      end
    end
  end
end
