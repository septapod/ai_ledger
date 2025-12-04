# frozen_string_literal: true

class Admin::RssFeedsController < ApplicationController
  before_action :require_logged_in_admin
  before_action :set_feed, only: [:show, :edit, :update, :destroy, :fetch_now]

  def index
    @title = "RSS Feed Management"
    @feeds = RssFeed.order(active: :desc, name: :asc)
    @stats = {
      total: RssFeed.count,
      active: RssFeed.active.count,
      items_pending: RssFeedItem.pending.count,
      items_relevant: RssFeedItem.relevant.count
    }
  end

  def show
    @title = @feed.name
    @recent_items = @feed.rss_feed_items
      .order(created_at: :desc)
      .limit(50)
    @item_stats = {
      total: @feed.rss_feed_items.count,
      pending: @feed.rss_feed_items.pending.count,
      relevant: @feed.rss_feed_items.relevant.count,
      submitted: @feed.rss_feed_items.submitted.count
    }
  end

  def new
    @title = "Add RSS Feed"
    @feed = RssFeed.new
  end

  def create
    @feed = RssFeed.new(feed_params)
    if @feed.save
      flash[:success] = "Feed \"#{@feed.name}\" added successfully."
      redirect_to admin_rss_feeds_path
    else
      @title = "Add RSS Feed"
      render :new
    end
  end

  def edit
    @title = "Edit #{@feed.name}"
  end

  def update
    if @feed.update(feed_params)
      flash[:success] = "Feed updated successfully."
      redirect_to admin_rss_feed_path(@feed)
    else
      @title = "Edit #{@feed.name}"
      render :edit
    end
  end

  def destroy
    name = @feed.name
    @feed.destroy
    flash[:success] = "Feed \"#{name}\" removed."
    redirect_to admin_rss_feeds_path
  end

  def fetch_now
    RssFeedFetchJob.perform_later(@feed.id)
    flash[:success] = "Fetch job queued for \"#{@feed.name}\". Check back in a moment."
    redirect_to admin_rss_feed_path(@feed)
  end

  private

  def set_feed
    @feed = RssFeed.find(params[:id])
  end

  def feed_params
    params.require(:rss_feed).permit(:name, :url, :category, :active)
  end

  def require_logged_in_admin
    if @user.nil?
      flash[:error] = "You must be logged in to access that."
      redirect_to login_path
    elsif !@user.is_admin?
      flash[:error] = "You must be an admin to access that."
      redirect_to root_path
    end
  end
end
