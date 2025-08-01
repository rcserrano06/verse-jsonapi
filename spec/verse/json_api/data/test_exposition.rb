# frozen_string_literal: true

require_relative "./spec_data"

class TestService < Verse::Service::Base
  def create(params); end

  def delete(id); end

  def index(filters, included: [], page: 1, items_per_page: 10, sort: nil, query_count: false); end

  def show(id, included: []); end
end

class UuidTestService < Verse::Service::Base
  def create(params); end

  def delete(id); end

  def index(filters, included: [], page: 1, items_per_page: 10, sort: nil, query_count: false); end

  def show(id, included: []); end
end

class TestExposition < Verse::Exposition::Base
  class << self
    attr_accessor :trigger
  end

  http_path "/users"

  use_service TestService

  json_api UserRecord do
    # service :service

    allowed_included "posts"

    show do
      meta nodoc: true # Add nodoc meta to the show route
    end
    update

    create do
      body do |_service, default|
        TestExposition.trigger = true
        default.call
      end
    end
    delete
    index do
      allowed_filters :name__match
    end
  end
end

class UuidTestExposition < Verse::Exposition::Base
  class << self
    attr_accessor :trigger
  end

  http_path "/uuid_records"

  use_service UuidTestService

  json_api UuidRecord do
    create do
      allow_id true

      body do |_service, default|
        UuidTestExposition.trigger = true
        default.call
      end
    end
    show
    index
    update
    delete
  end
end
