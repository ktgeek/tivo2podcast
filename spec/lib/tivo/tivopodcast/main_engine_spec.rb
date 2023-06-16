# frozen_string_literal: true

require "tivo/tivopodcast/main_engine"

describe Tivo2Podcast::MainEngine do
  let(:t2pconfig) { instance_double("Tivo2Podcast::AppConfig") }
  let(:main_engine) { Tivo2Podcast::MainEngine.new(t2pconfig) }

  describe "#get_shows_to_process" do
    let(:show_config) do
      show_config = double("Tivo2Podcast::Config")
      allow(show_config).to receive(:show_name) { "Show" }
      show_config
    end
    let(:tivo) do
      tivo = instance_double("TiVo::TiVo")
      allow(tivo).to receive(:get_shows_by_name) do
        ["Show 1", "Show 2", "Show 3", "Show 4", "Show 5"]
      end
      tivo
    end

    it "returns the last X shows for a given number" do
      allow(show_config).to receive(:episodes_to_keep) { 3 }
      shows = main_engine.get_shows_to_process(tivo, show_config)

      expect(shows).to eql ["Show 3", "Show 4", "Show 5"]
    end

    it "returns the all the shows when X > totals shows" do
      allow(show_config).to receive(:episodes_to_keep) { 7 }
      shows = main_engine.get_shows_to_process(tivo, show_config)

      expect(shows).to eql ["Show 1", "Show 2", "Show 3", "Show 4", "Show 5"]
    end
  end

  describe "#create_show_base_filename" do
    let(:show) do
      show = instance_double("TiVo::TiVoVideo")
      allow(show).to receive(:title) { "Show" }
      allow(show).to receive(:time_captured) { Time.new(2015, 7, 10, 22) }
      allow(show).to receive(:episode_title) { nil }
      allow(show).to receive(:episode_number) { nil }
      show
    end

    it "returns a title for a show without episode_title or episode_number" do
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "Show-201507102200"
    end

    it "strips out problematic characters" do
      allow(show).to receive(:title) { "A:b?c;" }
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "A_b_c_-201507102200"
    end

    it "returns a title for a show with an episode_title" do
      allow(show).to receive(:episode_title) { "Title" }
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "Show-201507102200-Title"
    end

    it "returns a title for a show with an episode_number" do
      allow(show).to receive(:episode_number) { "31337" }
      name = main_engine.create_show_base_filename(show)

      expect(name).to eql "Show-201507102200-31337"
    end

    it "returns a title for a show with both an episode title and number" do
      allow(show).to receive(:episode_title) { "Title" }
      allow(show).to receive(:episode_number) { "31337" }

      name = main_engine.create_show_base_filename(show)
      expect(name).to eql "Show-201507102200-Title-31337"
    end
  end
end
