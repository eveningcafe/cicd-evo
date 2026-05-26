# Source: GitHub via AWS CodeConnections (formerly CodeStar Connections).
#
# Terraform creates the Connection in PENDING state. After apply, you must
# manually authorize it in the AWS Console:
#   Developer Tools → Settings → Connections → cicd-evo-github
#   → "Update pending connection" → Authorize via GitHub OAuth
# Once status flips to AVAILABLE, the pipeline can pull from GitHub.
#
# The CodeStarSourceConnection pipeline action registers a webhook on the
# GitHub repo automatically — no EventBridge rule needed.

resource "aws_codestarconnections_connection" "github" {
  name          = "${local.name}-github"
  provider_type = "GitHub"
}
