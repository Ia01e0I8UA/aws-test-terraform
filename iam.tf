# --- ECS task execution role (used by Fargate to pull the image and write logs) ---

resource "aws_iam_role" "ecs_execution" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- GitHub Actions OIDC provider ---

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# --- CI roles: scoped by event. Plan (PR) is read-only; apply (push to main) can write. ---

resource "aws_iam_role" "github_plan" {
  name = "github-actions-plan"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:Ia01e0I8UA@*/aws-test-terraform@*:pull_request"
        }
      }
    }]
  })
}

resource "aws_iam_role" "github_apply" {
  name = "github-actions-apply"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:Ia01e0I8UA@*/aws-test-terraform@*:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_apply_power" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "github_apply_iam" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Renamed from the original (typo) labels without destroy/create:
moved {
  from = aws_iam_role_policy_attachment.github_apply_Attatchment
  to   = aws_iam_role_policy_attachment.github_apply_power
}

moved {
  from = aws_iam_role_policy_attachment.github_apply2_Attatchment
  to   = aws_iam_role_policy_attachment.github_apply_iam
}

moved {
  from = aws_iam_role_policy_attachment.github_plan_Attatchment
  to   = aws_iam_role_policy_attachment.github_plan_readonly
}
