require "rails_helper"

RSpec.describe Queries::DependentExpansionRules do
  describe "#expansion_fields" do
    context "for a link_type with custom expansion rules" do
      let(:link_type) { :topical_event }

      it "returns the custom fields for that link_type" do
        expect(subject.expansion_fields(link_type)).to include(:details)
      end
    end

    context "for a generic link_type" do
      let(:link_type) { :foo }

      it "returns the default fields" do
        expect(subject.expansion_fields(link_type)).to eq([
          :analytics_identifier,
          :api_url,
          :base_path,
          :content_id,
          :description,
          :locale,
          :title,
          :web_url,
        ])
      end
    end
  end

  describe "#recurse?" do
    specify { expect(subject.recurse?(:parent)).to eq(true) }
    specify { expect(subject.recurse?(:foo)).to eq(false) }
  end

  describe "#reverse_name_for(link_type)" do
    specify { expect(subject.reverse_name_for(:parent)).to eq("children") }
  end
end
