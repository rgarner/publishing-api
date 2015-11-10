require 'rails_helper'

RSpec.describe LinkSet do
  def valid_uuid
    "df633bb7-8825-4cf6-96dd-752c9949da69"
  end

  def set_new_attributes(item)
    item.links = { foo: [valid_uuid] }
  end

  def verify_new_attributes_set
    binding.pry
    expect(described_class.last.links).to eq(foo: [valid_uuid])
  end

  def verify_old_attributes_not_preserved
    expect(described_class.last.links[:organisations]).to be_nil
  end

  # We expect links to be hashes of type `{Symbol => [UUID]}`. For example:
  #
  # {
  #   related: [
  #     "8242a29f-8ad1-4fbe-9f71-f9e57ea5f1ea",
  #     "9f99d6d0-8f3b-4ad1-aac0-4811be80de47"
  #   ]
  # }


  it 'allows hashes from strings to lists' do
    links = {"related" => [SecureRandom.uuid]}
    expect(subject.links_valid?(links)).to be true
  end

  it 'allows an empty list of content IDs' do
    links = {"related" => []}
    expect(subject.links_valid?(links)).to be true
  end

  describe "validating keys" do
    it 'rejects nil keys' do
      links = {nil => []}
      expect(subject.links_valid?(links)).to be_falsey
      expect(subject.errors[:links]).to eq(["Invalid link types: "])
    end

    it "allows string keys that are underscored alphanumeric" do
      [
        'word',
        'word2word',
        'word_word',
      ].each do |key|
        links = {key => []}
        expect(subject.links_valid?(links)).to be true
      end
    end

    it "rejects keys keys with non-allowed characters" do
      [
        'Uppercase',
        'space space',
        'dash-ed',
        'punctuation!',
        '',
      ].each do |key|
        links = {key => []}
        expect(subject.links_valid?(links)).to be_falsey
      end
    end

    it "rejects reserved link type available_translations" do
      links = {'available_translations' => []}
      expect(subject.links_valid?(links)).to be_falsey
      expect(subject.errors[:links]).to eq(["Invalid link types: available_translations"])
    end
  end

  describe "validating values" do
    it 'rejects non-list values' do
      links = {"related" => SecureRandom.uuid}
      expect(subject.links_valid?(links)).to be_falsey
      expect(subject.errors[:links]).to eq(["must map to lists of UUIDs"])
    end

    it 'rejects non-UUID content IDs' do
      links = {"related" => [SecureRandom.uuid, "/vat-rates"]}
      expect(subject.links_valid?(links)).to be_falsey
      expect(subject.errors[:links]).to eq(["must map to lists of UUIDs"])
    end

    it 'rejects content IDs which are hashes' do
      links = {"related" => [{}]}
      expect(subject.links_valid?(links)).to be_falsey
      expect(subject.errors[:links]).to eq(["must map to lists of UUIDs"])
    end
  end

  let!(:existing) {
    FactoryGirl.build(:link_set)
  }

  let!(:content_id) { existing.content_id }

  let!(:payload) do
    FactoryGirl.build(:link_set)
    .as_json
    .merge(
      content_id: content_id,
      links: {
        foo: [valid_uuid]
      }
    )
  end

  let!(:another_payload) do
    FactoryGirl.build(:link_set)
    .as_json
    .symbolize_keys
    .merge(
      links: {
        foo: [valid_uuid]
      }
    )
  end

  it_behaves_like Replaceable
end
