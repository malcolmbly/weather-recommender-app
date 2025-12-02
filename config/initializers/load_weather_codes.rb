# Load the weather codes mapping from the YAML file into a constant.
# This ensures the mapping is loaded only once when the application starts.
MAPPING_FILE = Rails.root.join("config", "weather_codes.yml")

if File.exist?(MAPPING_FILE)
  # YAML.safe_load loads the file contents securely
  # We fetch the 'WEATHER_CODES' key and use .freeze to make the Hash immutable.
  # permitted_classes: [Symbol] is included for safe loading compatibility.
  WEATHER_MAPPING = YAML.safe_load(File.read(MAPPING_FILE), permitted_classes: [ Symbol ]).fetch("WEATHER_CODES", {}).freeze
else
  # Fallback if the file is missing
  Rails.logger.warn "WEATHER_MAPPING YAML file not found at #{MAPPING_FILE}"
  WEATHER_MAPPING = {}.freeze
end
