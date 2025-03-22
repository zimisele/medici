terraform {
    backend "s3" {
        bucket = "zmiselebucketdemo"
        region = "eu-west-1"
        key = "network/terraform.tfstate"
        encrypt = true
        region = "eu-west-1"
    }
}
