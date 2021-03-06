# frozen_string_literal: true

class ActivityPub::ProcessCollectionService < BaseService
  include JsonLdHelper

  def call(body, account)
    @account = account
    @json    = Oj.load(body, mode: :strict)

    return if @account.suspended? || !supported_context?

    return if different_actor? && verify_account!.nil?

    case @json['type']
    when 'Collection', 'CollectionPage'
      process_items @json['items']
    when 'OrderedCollection', 'OrderedCollectionPage'
      process_items @json['orderedItems']
    else
      process_items [@json]
    end
  rescue Oj::ParseError
    nil
  end

  private

  def different_actor?
    @json['actor'].present? && value_or_id(@json['actor']) != @account.uri && @json['signature'].present?
  end

  def process_items(items)
    items.reverse_each.map { |item| process_item(item) }.compact
  end

  def supported_context?
    super(@json)
  end

  def process_item(item)
    activity = ActivityPub::Activity.factory(item, @account)
    activity&.perform
  end

  def verify_account!
    @account = ActivityPub::LinkedDataSignature.new(@json).verify_account!
  end
end
