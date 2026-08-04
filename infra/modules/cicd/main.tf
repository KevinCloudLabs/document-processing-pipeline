data "aws_caller_identity" "current" {}

# GitHub's OIDC identity provider lets IAM trust short-lived tokens minted by
# GitHub Actions, so no AWS access keys are ever stored as repo secrets.
#
# This is referenced as a data source rather than managed here on purpose. IAM
# permits only one OIDC provider per URL per account, and it is shared by every
# project in the account that deploys from GitHub. Managing an account-wide
# shared resource from a single project's state means `terraform destroy` here
# would break every other project's pipeline. Create it once per account,
# outside this stack:
#
#   aws iam create-open-id-connect-provider \
#     --url https://token.actions.githubusercontent.com \
#     --client-id-list sts.amazonaws.com
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Scoping `sub` to one repo AND one branch is the critical control here.
        # Without it, ANY GitHub repository could assume this role.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/${var.github_branch}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # GetAuthorizationToken cannot be scoped to a resource — it is account-wide by design.
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = [
          var.worker_repository_arn,
          var.api_repository_arn
        ]
      },
      {
        # Only enough to generate a kubeconfig. Actual in-cluster authorization is
        # granted separately by the EKS access entry below, not by IAM.
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = var.cluster_arn
      }
    ]
  })
}

# IAM alone does not grant Kubernetes API access under authentication_mode = "API".
# The access entry is what actually authorizes kubectl for this principal.
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  type          = "STANDARD"
}

# Scoped to edit-only on the `default` namespace: enough to roll deployments,
# not enough to modify cluster-scoped resources or reach other namespaces.
resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.github_actions.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }

  depends_on = [aws_eks_access_entry.github_actions]
}
