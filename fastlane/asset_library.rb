# Uploads images through the App Store Connect "App Asset Library" API, which fastlane's
# deliver doesn't support yet: iPhone Duo screenshots and the product page header and
# search results images (iOS 27). Used by the upload_asset_library lane in the Fastfile.
#
# Flow per image: reserve it (POST appAssetLibraryImages), PUT the bytes to the upload
# operations, commit (PATCH uploaded: true), wait until processed, then place it on an
# App Store version localization (POST appAssetLibraryPlacements). Placements can't be
# edited, so existing ones in the same group are deleted first.
#
# Placement group IDs are not hard-coded: they are read from the reference data
# (GET /v1/appAssetLibraryRefData) and picked by placement type, display class and the
# exact pixel size of the file, as Apple's "Discovering asset specifications" asks.

require "json"
require "net/http"
require "shellwords"
require "uri"

class AssetLibrary
  API = "https://api.appstoreconnect.apple.com"
  REF_DATA_DUMP = File.expand_path("asset-library-refdata.json", __dir__)

  # token: a Spaceship::ConnectAPI::Token, refreshed when it expires during a long upload
  # jobs: [{ locale:, placement_type:, display_class: (or nil), files: [paths in order] }]
  def initialize(token:, bundle_id:, dry_run: false, log: ->(message) { puts(message) })
    @token = token
    @bundle_id = bundle_id
    @dry_run = dry_run
    @log = log
  end

  def upload(jobs)
    app_id = first(get("/v1/apps", "filter[bundleId]" => @bundle_id))&.dig("id") or raise "App #{@bundle_id} not found"
    version = first(get("/v1/apps/#{app_id}/appStoreVersions",
                        "filter[appStoreState]" => "PREPARE_FOR_SUBMISSION", "filter[platform]" => "IOS"))
    raise "No iOS App Store version is in Prepare for Submission. Create the version in App Store Connect first." unless version
    @log.call("Version #{version.dig('attributes', 'versionString')}")

    localizations = get_all("/v1/appStoreVersions/#{version['id']}/appStoreVersionLocalizations")
                    .to_h { |l| [l.dig("attributes", "locale"), l["id"]] }
    library_id = get("/v1/apps/#{app_id}/assetLibrary").dig("data", "id")
    ref_response = get("/v1/appAssetLibraryRefData")
    # Kept for debugging: the field names of the reference data are only partly documented
    File.write(REF_DATA_DUMP, JSON.pretty_generate(ref_response))
    ref = first(ref_response)["attributes"]

    jobs.each do |job|
      localization_id = localizations[job[:locale]]
      unless localization_id
        @log.call("Skipping #{job[:locale]}: the version has no such localization (run upload_metadata first)")
        next
      end
      next if job[:files].empty?

      size = image_size(job[:files].first)
      extension = File.extname(job[:files].first).downcase
      group = placement_group(ref, job[:placement_type], job[:display_class], size, extension)
      @log.call("#{job[:locale]} #{job[:placement_type]} #{job[:display_class]} #{size.join('x')}: " \
                "group #{group[:id]}, #{job[:files].count} file(s)")
      next if @dry_run

      existing = get_all("/v1/appStoreVersionLocalizations/#{localization_id}/placements",
                         "filter[placementType]" => job[:placement_type], "filter[placementGroup]" => group[:id])
      existing.each { |placement| request(:delete, "/v1/appAssetLibraryPlacements/#{placement['id']}") }

      placements = job[:files].map do |file|
        image_id = upload_image(library_id, file, group[:category])
        placement_body = {
          data: {
            type: "appAssetLibraryPlacements",
            attributes: { placementType: job[:placement_type], placementGroup: group[:id] },
            relationships: {
              image: { data: { type: "appAssetLibraryImages", id: image_id } },
              appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localization_id } }
            }
          }
        }
        request(:post, "/v1/appAssetLibraryPlacements", body: placement_body).dig("data", "id")
      end

      next if placements.count < 2
      ordering_body = {
        data: {
          type: "appAssetLibraryPlacementOrderingRequests",
          attributes: { placementGroup: group[:id] },
          relationships: {
            orderedPlacements: { data: placements.map { |id| { type: "appAssetLibraryPlacements", id: id } } },
            appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: localization_id } }
          }
        }
      }
      request(:post, "/v1/appAssetLibraryPlacementOrderingRequests", body: ordering_body)
    end
  end

  private

  # The placement group for this placement type (and display class, for screenshots) whose
  # specifications accept an image of exactly this size. Apple documents what the reference
  # data holds but not every field name, so entries are matched by their values.
  def placement_group(ref, placement_type, display_class, size, extension)
    type = Array(ref["placementTypes"]).find { |t| strings(t).include?(placement_type) }
    raise "The reference data has no placement type #{placement_type} (see #{REF_DATA_DUMP})" unless type
    specs = Array(ref["imageSpecs"]).to_h { |s| [s["specId"] || s["id"], s] }
    groups = Array(ref["placementProfileGroups"]).to_h { |g| [g["placementProfileGroupId"] || g["groupId"] || g["id"], g] }
    mappings = type.values.find { |v| v.is_a?(Array) && v.first.is_a?(Hash) } || []
    category = type.values.find { |v| v.is_a?(Array) && (v & %w[APP_SCREENSHOTS_AND_PREVIEWS CREATIVE_ASSETS]).any? }&.first

    candidates = mappings.map do |mapping|
      group_id = mapping.values.find { |v| v.is_a?(String) && groups.key?(v) }
      next unless group_id
      group_values = strings(groups[group_id])
      next if display_class && !group_values.include?(display_class)
      spec_ids = mapping.values.find { |v| v.is_a?(Array) && v.all? { |id| id.is_a?(String) } } || []
      { id: group_id, category: category } if spec_ids.any? { |spec_id| fits?(specs[spec_id], size, extension) }
    end.compact

    if candidates.empty?
      raise "No placement group for #{placement_type} #{display_class} accepts a #{size.join('x')} #{extension} (see #{REF_DATA_DUMP})"
    end
    candidates.first
  end

  # Every string value in a hash (one level deep, including strings in arrays)
  def strings(hash)
    hash.values.flat_map { |v| v.is_a?(Array) ? v : [v] }.select { |v| v.is_a?(String) }
  end

  def fits?(spec, (width, height), extension)
    return false unless spec
    d = spec["dimensions"]
    width.between?(d["minWidth"], d["maxWidth"]) && height.between?(d["minHeight"], d["maxHeight"]) &&
      Array(spec["fileExtensions"]).include?(extension)
  end

  def upload_image(library_id, file, category)
    reservation = request(:post, "/v1/appAssetLibraryImages", body: {
      data: {
        type: "appAssetLibraryImages",
        attributes: { fileName: File.basename(file), fileSize: File.size(file), category: category },
        relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: library_id } } }
      }
    })["data"]
    bytes = File.binread(file)
    Array(reservation.dig("attributes", "uploadOperations")).each do |operation|
      uri = URI(operation["url"])
      http_request = Net::HTTPGenericRequest.new(operation["method"], true, true, uri)
      Array(operation["requestHeaders"]).each { |header| http_request[header["name"]] = header["value"] }
      http_request.body = bytes.byteslice(operation["offset"], operation["length"])
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(http_request) }
      raise "Upload of #{file} failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)
    end
    request(:patch, "/v1/appAssetLibraryImages/#{reservation['id']}",
            body: { data: { type: "appAssetLibraryImages", id: reservation["id"], attributes: { uploaded: true } } })

    120.times do
      state = get("/v1/appAssetLibraryImages/#{reservation['id']}").dig("data", "attributes")
      case state["state"]
      when "FAILED" then raise "Apple rejected #{file}: #{state['stateDetails'].inspect}"
      when "AWAITING_UPLOAD", "UPLOAD_COMPLETE" then sleep(2)
      else
        @log.call("Uploaded #{File.basename(file)}")
        return reservation["id"]
      end
    end
    raise "Processing #{file} took too long"
  end

  def image_size(file)
    `magick identify -format "%w %h" #{file.shellescape}`.split.map(&:to_i)
  end

  def first(response)
    Array(response["data"]).first
  end

  def get(path, params = {})
    request(:get, path, params: params)
  end

  def get_all(path, params = {})
    results = []
    response = get(path, params.merge("limit" => 200))
    loop do
      results.concat(Array(response["data"]))
      next_url = response.dig("links", "next") or break
      response = request(:get, next_url.delete_prefix(API))
    end
    results
  end

  def request(method, path, params: {}, body: nil)
    uri = URI(path.start_with?("http") ? path : API + path)
    uri.query = URI.encode_www_form(params) unless params.empty?
    http_request = Net::HTTPGenericRequest.new(method.to_s.upcase, !body.nil?, true, uri)
    @token.refresh! if @token.expired?
    http_request["Authorization"] = "Bearer #{@token.text}"
    if body
      http_request["Content-Type"] = "application/json"
      http_request.body = JSON.generate(body)
    end
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(http_request) }
    raise "#{method.upcase} #{uri.path} failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)
    response.body.to_s.empty? ? {} : JSON.parse(response.body)
  end
end
