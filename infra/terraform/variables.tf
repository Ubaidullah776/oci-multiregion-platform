variable "region" {
  description = "OCI region to deploy resources"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "primary_region" {
  description = "Primary OCI region for multi-region deployment"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "secondary_region" {
  description = "Secondary OCI region for multi-region deployment"
  type        = string
  default     = "me-jeddah-1"
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI Private Key"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "ssh_public_key" {
  description = "SSH Public Key for compute instances"
  type        = string
}

variable "vault_id" {
  description = "OCI Vault OCID for secrets management"
  type        = string
}

variable "oke_cluster_name" {
  description = "Name of the OKE cluster"
  type        = string
  default     = "springboot-microservices-cluster"
}

variable "node_pool_size" {
  description = "Number of worker nodes"
  type        = number
  default     = 3
}

variable "mysql_admin_password" {
  description = "MySQL admin password"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}
