
# Shared coverage configuration for RSpec and Cucumber

# Measure application code, including files not loaded during tests
SimpleCov.cover "app/**/*.rb"

# Store generated coverage reports in the coverage directory
SimpleCov.coverage_dir "coverage"

# Require at least 80% line coverage
SimpleCov.minimum_coverage 80
