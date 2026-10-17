# Sets up a product page optimization test (App Store Connect API, v2 experiments) from
# fastlane/ppo/variants.json and the screenshots the ppo_screenshots lane frames for every
# variant. Used by the ppo_create_test lane in the Fastfile.
#
# The test belongs to the app and runs against the live product page, so it only makes
# sense once the version with these screenshots is on the App Store. The script creates the
# test (or reuses one with the same name that hasn't been submitted yet), one treatment per
# variant, a treatment localization per language and places the screenshots on them via
# the App Asset Library. It does not submit or start the test; do that in App Store Connect.

require "json"
require_relative "asset_library"

class PPOExperiment
  # Share of the visitors that see a treatment. 66 splits them evenly: a third each for the
  # original and the two treatments. Apple's docs don't describe the field; their example
  # uses 66 too.
  TRAFFIC_PROPORTION = 66

  def initialize(library:, config:, variants_dir:, log:)
    @library = library
    @config = config
    @variants_dir = variants_dir
    @log = log
  end

  def create(dry_run:)
    name = @config.fetch("experiment")
    experiment = existing_experiment(name)
    if experiment
      state = experiment.dig("attributes", "state")
      raise "Test \"#{name}\" is already #{state}; rename it in variants.json to set up a new one" unless state == "PREPARE_FOR_SUBMISSION"
      @log.call("Reusing test \"#{name}\"")
    elsif dry_run
      @log.call("Would create test \"#{name}\" with #{TRAFFIC_PROPORTION}% of the traffic on the treatments")
    else
      experiment = @library.request(:post, "/v2/appStoreVersionExperiments", body: {
        data: {
          type: "appStoreVersionExperiments",
          attributes: { name: name, platform: "IOS", trafficProportion: TRAFFIC_PROPORTION },
          relationships: { app: { data: { type: "apps", id: @library.app_id } } }
        }
      })["data"]
      @log.call("Created test \"#{name}\"")
    end

    @config.fetch("variants").each do |variant, settings|
      treatment = experiment && treatment_named(experiment["id"], settings["name"])
      if treatment.nil? && !dry_run
        treatment = @library.request(:post, "/v1/appStoreVersionExperimentTreatments", body: {
          data: {
            type: "appStoreVersionExperimentTreatments",
            attributes: { name: settings["name"] },
            relationships: { appStoreVersionExperimentV2: { data: { type: "appStoreVersionExperiments", id: experiment["id"] } } }
          }
        })["data"]
      end
      @log.call("Treatment \"#{settings['name']}\"")

      locales(variant).each do |locale|
        localization = treatment && localization_for(treatment["id"], locale)
        if localization.nil? && !dry_run
          localization = @library.request(:post, "/v1/appStoreVersionExperimentTreatmentLocalizations", body: {
            data: {
              type: "appStoreVersionExperimentTreatmentLocalizations",
              attributes: { locale: locale },
              relationships: { appStoreVersionExperimentTreatment: { data: { type: "appStoreVersionExperimentTreatments", id: treatment["id"] } } }
            }
          })["data"]
        end
        target = { relationship: "appStoreVersionExperimentTreatmentLocalization",
                   type: "appStoreVersionExperimentTreatmentLocalizations",
                   id: localization&.dig("id"), label: "#{variant} #{locale}" }
        # One placement group per device: the files of each pixel size go together
        screenshots(variant, locale).group_by { |file| image_size(file) }.each_value do |files|
          @library.place(target, "APP_SCREENSHOT", nil, files)
        end
      end
    end

    @log.call("Done. Check the test in App Store Connect (Product Page Optimization), then submit and start it there.") unless dry_run
  end

  private

  def existing_experiment(name)
    @library.get_all("/v1/apps/#{@library.app_id}/appStoreVersionExperimentsV2")
            .find { |experiment| experiment.dig("attributes", "name") == name }
  end

  def treatment_named(experiment_id, name)
    @library.get_all("/v2/appStoreVersionExperiments/#{experiment_id}/appStoreVersionExperimentTreatments")
            .find { |treatment| treatment.dig("attributes", "name") == name }
  end

  def localization_for(treatment_id, locale)
    @library.get_all("/v1/appStoreVersionExperimentTreatments/#{treatment_id}/appStoreVersionExperimentTreatmentLocalizations",
                     "filter[locale]" => locale).first
  end

  # Languages with framed screenshots for this variant (the folders are App Store locales)
  def locales(variant)
    Dir.glob(File.join(@variants_dir, variant, "screenshots", "*"))
       .select { |dir| File.directory?(dir) && Dir.glob(File.join(dir, "*_framed.png")).any? }
       .map { |dir| File.basename(dir) }.sort
  end

  def screenshots(variant, locale)
    %w[screenshots screenshots-duo].flat_map do |folder|
      Dir.glob(File.join(@variants_dir, variant, folder, locale, "*_framed.png"))
    end.sort
  end

  def image_size(file)
    @library.send(:image_size, file)
  end
end
