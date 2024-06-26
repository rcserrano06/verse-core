# frozen_string_literal: true

require_relative "../service/test_service"

class SampleExposition < Verse::Exposition::Base
  desc "This is a sample exposition"

  use_service test: TestService

  @output = false

  class << self
    attr_accessor :output
  end

  expose on_spec_hook({ data: true }) do
    desc "Does something"

    input do
      field(:name, String).filled
      field(:mode, Symbol).optional
    end

    output do
      field(:name, String).filled
      field(:context, String).filled
      field(:some_data, Hash)
    end
  end
  def do_something
    if params[:mode] != :unchecked
      test.some_action # This is just to test the service
    end

    self.class.output = {
      name: "#{params[:name]} Doe",
      context:,
      some_data:
    }

    self.class.output
  end

  expose on_spec_hook({ data: false }) do
    desc "Test around method"
  end
  def test_around_method
    "ok"
  end

  around :test_around_method do |method|
    auth_context.mark_as_checked!
    self.class.output = "around"
    method.call
  end
end
