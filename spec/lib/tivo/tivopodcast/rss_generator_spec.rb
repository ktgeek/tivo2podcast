# frozen_string_literal: true

require "tivo/tivopodcast/rss_generator"

describe Tivo2Podcast::RssGenerator do
  describe "#item_title" do
    let(:show) do
      show = double("TiVo2Podcast::Db::Show")
      allow(show).to receive(:name) { "Show" }
      allow(show).to receive(:episode_title) { "Title" }
      show
    end
    let(:builder) { Tivo2Podcast::RssGenerator.new(nil) }

    it "returns the episode title if the size is 1" do
      title = builder.send(:item_title, 1, show)
      expect(title).to eql "Title"
    end

    it "returns the show prepended to the title when size is > 1" do
      title = builder.send(:item_title, 2, show)
      expect(title).to eql "Show: Title"
    end
  end

  context "make the rss content" do
    let(:maker) { RSS::Maker["2.0"].new }
    let(:rss_file) do
      rss_file = double("Tivo2Podcast::RssFile")
      allow(rss_file).to receive(:feed_title) { "Title" }
      allow(rss_file).to receive(:feed_description) { "description" }
      allow(rss_file).to receive(:link) { "http://example.com" }
      allow(rss_file).to receive(:owner_name) { "owner" }
      allow(rss_file).to receive(:owner_email) { "example@example.com" }
      rss_file
    end
    let(:builder) { Tivo2Podcast::RssGenerator.new(rss_file) }

    describe "#configure_channel" do
      let(:channel) { maker.channel }

      it "fills out rss channel with expected information" do
        builder.send(:configure_channel, channel)

        expect(channel.title).to eql("Title")
        expect(channel.description).to eql("description")
        expect(channel.link).to eql("http://example.com")
        expect(channel.itunes_author).to eql("Title")
        expect(channel.itunes_owner.itunes_name).to eql("owner")
        expect(channel.itunes_owner.itunes_email).to eql("example@example.com")
      end
    end

    # TODO: finishing testing othre methodsZ
    #    describe "#make_item" do
    #      let(:item)
    #    end
  end
end
