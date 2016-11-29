require "spec_helper"

describe FindfaceApi do
  it "has a version number" do
    expect(FindfaceApi::VERSION).not_to be nil
  end

  it "has an API version number" do
    expect(FindfaceApi::API_VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
