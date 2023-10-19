provider "aws" {
  region     = "eu-west-2"
  profile = "devops-engineer"
}

provider "aws" {
  alias   = "useast1"
  region   = "us-east-1"
}