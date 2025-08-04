# OCI Object Storage Configuration for Large File Handling
# This file defines Object Storage buckets and pre-signed URL generation

# OCI Object Storage for Large File Handling
resource "oci_objectstorage_bucket" "file_storage" {
  compartment_id = var.compartment_id
  name           = "microservices-file-storage"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  access_type    = "NoPublicAccess"
  
  versioning = "Enabled"
  
  object_events_enabled = true
  
  retention_rules {
    display_name = "File Retention Policy"
    duration {
      time_amount = 365
      time_unit   = "DAYS"
    }
  }
}

# OCI Object Storage for Backup Storage
resource "oci_objectstorage_bucket" "backup_storage" {
  compartment_id = var.compartment_id
  name           = "microservices-backup-storage"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  access_type    = "NoPublicAccess"
  
  versioning = "Enabled"
  
  retention_rules {
    display_name = "Backup Retention Policy"
    duration {
      time_amount = 90
      time_unit   = "DAYS"
    }
  }
}

# OCI Object Storage for Application Data
resource "oci_objectstorage_bucket" "app_data_storage" {
  compartment_id = var.compartment_id
  name           = "microservices-app-data"
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  access_type    = "NoPublicAccess"
  
  versioning = "Enabled"
  
  object_events_enabled = true
  
  retention_rules {
    display_name = "App Data Retention Policy"
    duration {
      time_amount = 180
      time_unit   = "DAYS"
    }
  }
}

# OCI Function for Pre-Signed URL Generation
resource "oci_functions_application" "url_generator" {
  compartment_id = var.compartment_id
  display_name   = "pre-signed-url-generator"
  subnet_ids     = [module.vcn_primary.subnets["oke-private-subnet"].id]
}

resource "oci_functions_function" "generate_presigned_url" {
  application_id = oci_functions_application.url_generator.id
  display_name   = "generate-presigned-url"
  memory_in_mbs  = 256
  timeout_in_seconds = 30
  
  image = "iad.ocir.io/${var.tenancy_ocid}/url-generator:latest"
  
  config = {
    "BUCKET_NAME" = oci_objectstorage_bucket.file_storage.name
    "NAMESPACE"   = data.oci_objectstorage_namespace.ns.namespace
    "REGION"      = var.primary_region
  }
}

# IAM Policy for Object Storage Access
resource "oci_identity_policy" "object_storage_policy" {
  compartment_id = var.compartment_id
  name           = "object-storage-access-policy"
  description    = "Policy for microservices to access Object Storage"
  
  statements = [
    "allow service objectstorage-${var.primary_region} to manage object-family in compartment id ${var.compartment_id}",
    "allow service objectstorage-${var.secondary_region} to manage object-family in compartment id ${var.compartment_id}",
    "allow dynamic-group microservices-dynamic-group to manage object-family in compartment id ${var.compartment_id}",
    "allow dynamic-group microservices-dynamic-group to use functions-family in compartment id ${var.compartment_id}"
  ]
}

# Dynamic Group for Microservices
resource "oci_identity_dynamic_group" "microservices_dynamic_group" {
  compartment_id = var.compartment_id
  description    = "Dynamic group for microservices instances"
  matching_rule  = "Any {instance.compartment.id = '${var.compartment_id}'}"
  name           = "microservices-dynamic-group"
}

# Data source for Object Storage namespace
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

# Outputs for Object Storage configuration
output "file_storage_bucket_name" {
  description = "Name of the file storage bucket"
  value       = oci_objectstorage_bucket.file_storage.name
}

output "backup_storage_bucket_name" {
  description = "Name of the backup storage bucket"
  value       = oci_objectstorage_bucket.backup_storage.name
}

output "app_data_storage_bucket_name" {
  description = "Name of the application data storage bucket"
  value       = oci_objectstorage_bucket.app_data_storage.name
}

output "object_storage_namespace" {
  description = "Object Storage namespace"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "url_generator_function_id" {
  description = "ID of the pre-signed URL generator function"
  value       = oci_functions_function.generate_presigned_url.id
} 