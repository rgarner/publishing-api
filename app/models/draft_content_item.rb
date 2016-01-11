class DraftContentItem < ActiveRecord::Base
  DEFAULT_LOCALE = "en".freeze

  include Replaceable
  include DefaultAttributes
  include SymbolizeJSON

  TOP_LEVEL_FIELDS = LiveContentItem::TOP_LEVEL_FIELDS

  NON_RENDERABLE_FORMATS = %w(redirect gone)

  deprecated_columns :access_limited

  has_one :live_content_item

  scope :renderable_content, -> { where.not(format: NON_RENDERABLE_FORMATS) }

  validates :content_id, presence: true, uuid: true
  validate :content_ids_match
  validates :base_path, presence: true, absolute_path: true, uniqueness: true
  validates :format, presence: true
  validates :publishing_app, presence: true
  validates :title, presence: true, if: :renderable_content?
  validates :rendering_app, presence: true, dns_hostname: true, if: :renderable_content?
  validates :public_updated_at, presence: true, if: :renderable_content?
  validates :locale, inclusion: {
    in: I18n.available_locales.map(&:to_s),
    message: 'must be a supported locale'
  }
  validates :phase, inclusion: {
    in: ['alpha', 'beta', 'live'],
    message: 'must be either alpha, beta, or live'
  }
  validates_with RoutesAndRedirectsValidator

  validates :description, well_formed_content_types: { must_include: "text/html" }
  validates :details, well_formed_content_types: { must_include: "text/html" }

  # Postgres's JSON columns have problems storing literal strings, so these
  # getter/setter wrap the description in a JSON object.
  def description=(value)
    super(value: value)
  end

  def description
    super.fetch(:value)
  end

  def attributes
    attributes = super
    description = attributes.delete("description")

    if description
      attributes.merge("description" => description.fetch("value"))
    else
      attributes
    end
  end

  def self.column_defaults
    super.merge("description" => nil)
  end

  def published?
    live_content_item.present?
  end

  def self.query_keys
    [:content_id, :locale]
  end

private
  def content_ids_match
    if live_content_item && live_content_item.content_id != content_id
      errors.add(:content_id, "id mismatch between draft and live content items")
    end
  end

  def renderable_content?
    NON_RENDERABLE_FORMATS.exclude?(format)
  end
end
