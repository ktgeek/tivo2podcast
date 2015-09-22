require 'tivo/tivopodcast/main_engine'

describe Tivo2Podcast::MainEngine do
  describe "#create_show_base_filename" do
    let(:config) { instance_double("Tivo2Podcast::Config") }
    let(:main_engine) { Tivo2Podcast::MainEngine.new(config) }
    let(:show) do
      show = instance_double("TiVo::TiVoVideo")
      allow(show).to receive(:title) { "Who: Revisited" }
      allow(show).to receive(:time_captured) { Time.new(2015, 7, 10, 22) }
      allow(show).to receive(:episode_title) { nil }
      allow(show).to receive(:episode_number) { nil }
      show
    end

    it "returns a title for a show without episode_title or episode_number" do
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "Who_ Revisited-201507102200"
    end

    it "returns a title for a show with an episode_title" do
      allow(show).to receive(:episode_title) { "Title?" }
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "Who_ Revisited-201507102200-Title_"
    end

    it "returns a title for a show with an episode_number" do
      allow(show).to receive(:episode_number) { "31337" }
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "Who_ Revisited-201507102200-31337"
    end

    it "returns a title for a show with both an episode title and number" do
      allow(show).to receive(:episode_title) { "Title?" }
      allow(show).to receive(:episode_number) { "31337" }

      name = main_engine.create_show_base_filename(show)
      expect(name).to eql "Who_ Revisited-201507102200-Title_-31337"
    end
  end
end
