require "rails_helper"

RSpec.describe "Commands controller", :type => :request do
  let(:content_item) {
    {
      "content_id" => "b65478c3-9744-4537-a5d2-b5ee6648df3b",
      "title" => "Original title",
      "details" => {
        "something" => "detailed"
      }
    }
  }

  context "No authenticated user" do
    let(:headers) { { format: :json } }

    specify "POST /create-draft gets a 401 unauthorized error" do
      post "/create-draft", content_item.to_json, headers

      expect(response.status).to eq(401)
      expect(response.body).to eq({error: {code: 401, message: "unauthorized"}}.to_json)
    end
  end

  let(:user) { User.create(name: "Example user") }

  let(:headers) {
    { 'X-Govuk-Authenticated-User' => user.id, format: :json }
  }

  describe "POST /create-draft" do
    it "creates a draft and logs the event" do
      post "/create-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", details: {}}.to_json, headers
      expect(DraftContentItem.count).to eq(1)
      expect(Event.count).to eq(1)
      expect(response.body).to eq(%Q({"event_id":#{Event.first.id}}))
    end
  end

  describe "POST /publish" do
    context "a draft exists" do
      before do
        post "/create-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", details: {}}.to_json, headers
      end

      it "converts the draft to a live document and removes the draft" do
        post "/publish", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
        expect(DraftContentItem.count).to eq(0)
        expect(Event.count).to eq(2)
        expect(LiveContentItem.count).to eq(1)
        expect(response.body).to eq(%Q({"event_id":#{Event.last.id}}))
      end
    end
  end

  describe "POST /redraft" do
    context "a published document exists" do
      before do
        post "/create-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", details: {}}.to_json, headers
        post "/publish", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
      end

      it "redrafting a published document" do
        post "/redraft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
        expect(Event.count).to eq(3)
        expect(DraftContentItem.count).to eq(1)
        expect(LiveContentItem.count).to eq(1)
        expect(DraftContentItem.first.attributes).to eq(LiveContentItem.first.attributes.except("version"))
      end
    end
  end

  describe "POST /modify-draft" do
    context "a draft exists" do
      before do
        post "/create-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", title: "Original title", details: {something: "detailed"}}.to_json, headers
      end

      it "updates top level attributes only, leaving details unchanged" do
        post "/modify-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", title: "New title"}.to_json, headers
        expect(Event.count).to eq(2)
        expect(DraftContentItem.count).to eq(1)
        expect(LiveContentItem.count).to eq(0)
        attributes = DraftContentItem.first.attributes
        expect(attributes['title']).to eq("New title")
        expect(attributes['details']['something']).to eq("detailed")
      end

      it "replaces the details hash entirely" do
        post "/modify-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", details: {something_else: "detailed"}}.to_json, headers
        expect(DraftContentItem.count).to eq(1)
        attributes = DraftContentItem.first.attributes
        expect(attributes['title']).to eq("Original title")
        expect(attributes['details']).not_to have_key("something")
        expect(attributes['details']['something_else']).to eq("detailed")
      end
    end
  end

  describe "GET /draft" do
    context "no draft exists" do
      it "returns a 404" do
        get "/draft/b65478c3-9744-4537-a5d2-b5ee6648df3b"
        expect(response.status).to eq(404)
        expect(response.body).to eq({error: {code: 404, message: "not found"}}.to_json)
      end
    end

    context "draft exists" do
      let(:draft_content_item) {
        JSON.parse({content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", title: "Original title", details: {something: "detailed"}}.to_json)
      }

      before do
        post "/create-draft", draft_content_item.to_json, headers
      end

      it "returns the draft" do
        get "/draft/b65478c3-9744-4537-a5d2-b5ee6648df3b"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)
        draft_content_item.each do |k,v|
          expect(parsed[k]).to eq(v)
        end
      end
    end
  end

  describe "GET /live/:content_id" do
    context "no published item exists" do
      it "returns a 404" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b"
        expect(response.status).to eq(404)
        expect(response.body).to eq({error: {code: 404, message: "not found"}}.to_json)
      end
    end

    context "draft exists" do
      before do
        post "/create-draft", content_item.to_json, headers
      end

      it "returns a 404" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b"
        expect(response.status).to eq(404)
        expect(response.body).to eq({error: {code: 404, message: "not found"}}.to_json)
      end
    end

    context "published document exists" do
      before do
        post "/create-draft", content_item.to_json, headers
        post "/publish", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
      end

      it "returns the published document" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)
        content_item.each do |k,v|
          expect(parsed[k]).to eq(v)
        end
      end
    end
  end

  describe "GET /live/:content_id/:version_number" do
    context "a document which has been published once" do
      before do
        post "/create-draft", content_item.to_json, headers
        post "/publish", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
      end

      it "returns the document by version number" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b/1"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)
        content_item.each do |k,v|
          expect(parsed[k]).to eq(v)
        end
      end
    end

    context "a document which has been published twice" do
      before do
        post "/create-draft", content_item.to_json, headers
        post "/publish", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
        post "/redraft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
        post "/modify-draft", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b", title: "New title"}.to_json, headers
        post "/publish", {content_id: "b65478c3-9744-4537-a5d2-b5ee6648df3b"}.to_json, headers
      end

      it "returns the first published document for version 1" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b/1"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)
        expect(parsed['title']).to eq(content_item['title'])
      end

      it "returns the second published document for version 2" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b/2"
        expect(response.status).to eq(200)
        parsed = JSON.parse(response.body)
        expect(parsed['title']).to eq('New title')
      end

      it "returns a 404 error for version 3" do
        get "/live/b65478c3-9744-4537-a5d2-b5ee6648df3b/3"
        expect(response.status).to eq(404)
      end
    end
  end
end
