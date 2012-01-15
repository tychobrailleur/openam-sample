# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
RubySample::Application.initialize!

# Load the custom configuration parameters.
APP_CONFIG = YAML.load_file(File.join(Rails.root, "config", "config.yml"))
