terraform:
  backend:
    s3:
      bucket: "oci-terraform-state-bucket"
      key: "oke/microservice/terraform.tfstate"
      region: "us-ashburn-1"
      encrypt: true
      dynamodb_table: "terraform-locks"
