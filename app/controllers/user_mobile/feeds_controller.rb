class UserMobile::FeedsController < UserMobile::ApplicationController
  def index
  	@code = params[:code]
    if @current_user.client_centers.present?
      @feeds = Feed.any_in(center_id: @current_user.client_centers.map { |e| e.id.to_s} + [nil]).desc(:created_at)
      if params[:keyword].present?
        @feeds = @feeds.where(name: /#{params[:keyword]}/)
      end
      @feeds = @feeds.limit(10)
    end
  end
end
