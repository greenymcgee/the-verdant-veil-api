require "./test/support/igdb_api_test_helper.rb"

module GameEngineLogoRefreshTestHelper
  include IgdbApiTestHelper

  def stubbed_game_engine_logo_ids
    [67]
  end

  def stub_successful_game_engine_logo_refresh_responses
    stubbed_game_engine_logo_ids.each do |id|
      stub_successful_igdb_api_request(
        "game_engine_logos/#{id}",
        json_mocks("igdb/game_engine_logos/#{id}.refresh.json"),
        stubbed_twitch_bearer_token,
      )
    end
  end

  def stub_game_engine_logo_refresh_request_failures
    stubbed_game_engine_logo_ids.each do |id|
      stub_igdb_api_request_failure("game_engine_logos/#{id}")
    end
  end

  def stub_game_engine_logo_refresh_responses(with_game_engine_logo_failures)
    if with_game_engine_logo_failures
      return stub_game_engine_logo_refresh_request_failures
    end

    stub_successful_game_engine_logo_refresh_responses
  end
end
