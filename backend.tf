terraform {
    backend "s3" {
        bucket = "mys3bucketZimisele"
        region = "eu-west-1"
        key = ""
        encrypt = true
    }
}