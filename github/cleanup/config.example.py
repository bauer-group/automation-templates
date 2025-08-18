# Example configuration for the GitHub Cleanup Tool
# Copy this file to config.py and adjust the values as needed

# Default repository settings (can be overridden by command line arguments)
DEFAULT_OWNER = "bauer-group"
DEFAULT_REPO = "automation-templates"

# Rate limiting settings
RATE_LIMIT_DELAY = 0.1  # Delay between API calls in seconds
MAX_RETRIES = 3  # Maximum number of retries for failed requests

# Protected branches (these will never be deleted)
PROTECTED_BRANCHES = {"main", "master", "develop", "staging"}

# Workflow run retention (only delete runs older than this many days)
# Set to 0 to delete all workflow runs
WORKFLOW_RUN_RETENTION_DAYS = 0

# Logging settings
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_FORMAT = "[%(asctime)s] %(levelname)s: %(message)s"

# GitHub API settings
GITHUB_API_URL = "https://api.github.com"
REQUESTS_PER_PAGE = 100  # Number of items to request per page (max 100)

# Confirmation settings
REQUIRE_CONFIRMATION = True  # Require "yes" confirmation before cleanup
SHOW_SUMMARY = True  # Show summary of items to be deleted before cleanup
