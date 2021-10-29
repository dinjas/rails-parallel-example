require 'spec_helper'

RSpec.describe "Eighth spec" do
  formatted = caller.map { |l| l[/^(.*?):\d+/] }
  LOGGER1.info(class: self.class.name, caller: formatted, attrs: KEYS.to_json)
  LOGGER2.info(attrs: KEYS.to_json)

  it "runs in parallel" do
    expect(1).to eql(1)
  end
end