# typed: false

class AvatarsController < ApplicationController
  before_action :require_logged_in_user, only: [:expire]

  ALLOWED_SIZES = [16, 32, 100, 200].freeze

  CACHE_DIR = Rails.public_path.join("avatars/").to_s.freeze

  def expire
    expired = 0

    Dir.entries(CACHE_DIR).select { |f|
      f.match(/\A#{@user.username}-(\d+)\.png\z/)
    }.each do |f|
      # Rails.logger.debug { "Expiring #{f}" }
      File.unlink("#{CACHE_DIR}/#{f}")
      expired += 1
    rescue => e
      # Rails.logger.error "Failed expiring #{f}: #{e}"
    end

    flash[:success] = "Your avatar cache has been purged of #{"file".pluralize(expired)}"
    redirect_to "/settings"
  end

  def show
    username, size = params[:username_size].to_s.scan(/\A(.+)-(\d+)\z/).first
    size = size.to_i

    if !ALLOWED_SIZES.include?(size)
      raise ActionController::RoutingError.new("invalid size")
    end

    if !username.match(User::VALID_USERNAME)
      raise ActionController::RoutingError.new("invalid user name")
    end

    u = User.where(username: username).first!

    av = u.fetched_avatar(size)
    if av.nil?
      # Generate a simple default avatar if Gravatar fails
      av = generate_default_avatar(username, size)
    end

    # the hatchbox pre-build script symlinks this to a shared folder but sister sites will most
    # likely have a single repo they update rather than replace
    if !File.exist?(CACHE_DIR) && !Dir.exist?(CACHE_DIR)
      Dir.mkdir(CACHE_DIR)
    end

    File.open("#{CACHE_DIR}/.#{u.username}-#{size}.png", "wb+") do |f|
      f.write av
    end

    File.rename("#{CACHE_DIR}/.#{u.username}-#{size}.png", "#{CACHE_DIR}/#{u.username}-#{size}.png")

    response.headers["Expires"] = 1.hour.from_now.httpdate
    send_data av, type: "image/png", disposition: "inline"
  end

  private

  def generate_default_avatar(username, size)
    require "zlib"

    # Generate a color based on username hash
    hash = Digest::MD5.hexdigest(username)
    r = hash[0..1].to_i(16)
    g = hash[2..3].to_i(16)
    b = hash[4..5].to_i(16)

    # Create raw image data (each row: filter byte + RGB pixels)
    raw_data = ""
    size.times do
      raw_data << "\x00" # filter byte (none)
      size.times do
        raw_data << r.chr << g.chr << b.chr
      end
    end

    # Compress with zlib
    compressed = Zlib::Deflate.deflate(raw_data)

    # Build PNG
    png = "\x89PNG\r\n\x1a\n" # PNG signature

    # IHDR chunk
    ihdr_data = [size, size, 8, 2, 0, 0, 0].pack("NNCCCCC")
    png << png_chunk("IHDR", ihdr_data)

    # IDAT chunk
    png << png_chunk("IDAT", compressed)

    # IEND chunk
    png << png_chunk("IEND", "")

    png
  end

  def png_chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end
end
