class Api::GamesController < ApplicationController
  include ActionView::Helpers::SanitizeHelper
  include Pagy::Backend

  before_action :set_game, only: %i[show update destroy]

  # 200
  def index
    facade = Api::Games::IndexFacade.new(params)
    @pagy, @games = pagy(facade.games)
  end

  # 200, 404
  def show
    unless @game.present?
      return(
        render(
          json: {
            message: "No games found matching #{params[:slug]}",
          },
          status: :not_found,
        )
      )
    end

    render json: game_cache
  end

  # 200, 207, 400, 401, 403
  def create
    authenticate_user!
    @game = Game.new(game_create_params)
    authorize @game

    begin
      request_igdb_game_data
      if @igdb_game_request_error.present?
        return render_igdb_game_request_failure
      end

      return render_unprocessable_game unless populate_igdb_fields

      add_game_resources
      return render_partial_creation if errors_present?

      render_successful_show_response(:created)
    rescue StandardError => error
      if error.message.include? "duplicate"
        preexisting_game = Game.find_by(igdb_id: game_create_params[:igdb_id])
        return(
          render(
            json: {
              message: "#{preexisting_game.name} already exists",
            },
            status: :unprocessable_entity,
          )
        )
      end

      raise StandardError.new(error)
    end
  end

  def update
    authenticate_user!
    authorize @game
    result = Api::Games::UpdateFacade.call(@game, game_update_params)
    return render_successful_show_response(:ok) if result === :ok

    return render_update_failure(result) if result.is_a?(Array)

    render json: @game.errors, status: :unprocessable_entity
  end

  # 200, 401, 403, 404
  def destroy
    authenticate_user!
    authorize @game
    @game.destroy!
  end

  private

  def populate_igdb_fields
    facade = Api::Games::IgdbFieldsFacade.new(@game, @igdb_game_data)
    facade.populate_game_fields
  end

  def request_igdb_game_data
    facade = Api::Games::IgdbRequestFacade.new(@game.igdb_id)
    game_request = facade.get_igdb_game_data
    @igdb_game_data = game_request[:igdb_game_data]
    @twitch_bearer_token = game_request[:twitch_bearer_token]
    @igdb_game_request_error = game_request[:error]
  end

  def set_game
    @game = Game.find_by(slug: params[:slug])
  end

  def game_update_params
    params.require(:game).permit(
      :banner_image,
      :currently_playing,
      :estimated_first_played_date,
      :featured_video_id,
      :last_played_date,
      :rating,
      :review,
      :review_title,
    )
  end

  def game_create_params
    params.require(:game).permit(:igdb_id, :rating, :review)
  end

  def render_successful_show_response(status)
    render :show, status: status, location: api_game_url(@game)
  end

  def render_igdb_game_request_failure
    render json: @igdb_game_request_error, status: :unprocessable_entity
  end

  def render_partial_creation
    Rails.logger.warn(
      "[GameCreate] Partial success creating game #{@game.slug}: " \
        "#{@game.errors.full_messages.join("; ")}",
    )
    render_successful_show_response(:multi_status)
  end

  def render_unprocessable_game
    render json: @game.errors, status: :unprocessable_entity
  end

  def render_update_failure(reasons)
    render(
      json: {
        message: "The game could not be updated",
        reasons: reasons,
      },
      status: :unprocessable_entity,
    )
  end

  def errors_present?
    @game.errors.present?
  end

  def add_game_resources
    Api::Games::CreateFacade.new(
      game: @game,
      igdb_game_data: @igdb_game_data,
      twitch_bearer_token: @twitch_bearer_token,
    ).add_game_resources
  end

  def game_cache
    Rails
      .cache
      .fetch("game/#{@game.slug}/show", expires_in: 12.hours) do
        Rails.logger.info "[CACHE FETCH] Rendering game ##{@game.slug}"
        ApplicationController.renderer.render(
          template: "api/games/show",
          assigns: {
            game: @game,
          },
          formats: [:json],
        )
      end
  end
end
