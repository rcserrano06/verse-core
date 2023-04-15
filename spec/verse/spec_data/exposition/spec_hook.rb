# This is a very bare minimum hook implementation,
# which can be called by `SpecHook.trigger_exposition(input)`
class SpecHook < Verse::Exposition::Hook::Base

  attr_reader :some_data

  @@callback = nil

  def self.callbacks
    @@callback
  end

  def self.trigger_exposition(input)
    @@callback.call(input)
  end

  def initialize(exposition_class, some_data)
    super(exposition_class)
    @some_data = some_data
  end

  def register_impl
    @@callback = proc do |input|
      @metablock.process_input(input)

      exposition = create_exposition(
        Verse::Spec::MockContext.all_access,
        context: "This is some contextual information",
        some_data: @some_data
      )

      output = exposition.run do
        @method.bind(exposition).call
      end

      @metablock.process_output(output)
    end
  end
end