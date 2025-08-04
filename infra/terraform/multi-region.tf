# Multi-Region OKE Clusters Configuration
# This file defines OKE clusters across multiple regions for high availability

# Primary Region (Frankfurt)
module "oke_primary" {
  source                 = "oracle-terraform-modules/oke/oci"
  compartment_id         = var.compartment_id
  cluster_name           = "oke-primary-${var.primary_region}"
  kubernetes_version     = "v1.28.2"
  vcn_id                 = module.vcn_primary.vcn_id
  subnets                = [module.vcn_primary.subnets["oke-private-subnet"].id]
  node_pool_size         = 3
  node_shape             = "VM.Standard.E4.Flex"
  node_ocpus             = 2
  node_memory_gbs        = 16
  region                 = var.primary_region
}

# Secondary Region (Jeddah)
module "oke_secondary" {
  source                 = "oracle-terraform-modules/oke/oci"
  compartment_id         = var.compartment_id
  cluster_name           = "oke-secondary-${var.secondary_region}"
  kubernetes_version     = "v1.28.2"
  vcn_id                 = module.vcn_secondary.vcn_id
  subnets                = [module.vcn_secondary.subnets["oke-private-subnet"].id]
  node_pool_size         = 3
  node_shape             = "VM.Standard.E4.Flex"
  node_ocpus             = 2
  node_memory_gbs        = 16
  region                 = var.secondary_region
}

# VCN for Primary Region
module "vcn_primary" {
  source                 = "oracle-terraform-modules/vcn/oci"
  compartment_id         = var.compartment_id
  vcn_name               = "oke-vcn-${var.primary_region}"
  cidr_block             = "10.0.0.0/16"
  create_internet_gateway = true
  subnets = {
    "oke-private-subnet" = {
      cidr_block = "10.0.10.0/24"
      private    = true
    }
  }
  region                 = var.primary_region
}

# VCN for Secondary Region
module "vcn_secondary" {
  source                 = "oracle-terraform-modules/vcn/oci"
  compartment_id         = var.compartment_id
  vcn_name               = "oke-vcn-${var.secondary_region}"
  cidr_block             = "10.1.0.0/16"
  create_internet_gateway = true
  subnets = {
    "oke-private-subnet" = {
      cidr_block = "10.1.10.0/24"
      private    = true
    }
  }
  region                 = var.secondary_region
}

# Global Load Balancer for Active-Active setup
resource "oci_load_balancer" "global_lb" {
  compartment_id = var.compartment_id
  display_name   = "global-microservices-lb"
  shape          = "flexible"
  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 100
  }
  subnet_ids = [
    module.vcn_primary.subnets["oke-private-subnet"].id,
    module.vcn_secondary.subnets["oke-private-subnet"].id
  ]
}

# Health Check Backend Sets
resource "oci_load_balancer_backend_set" "primary_backend" {
  load_balancer_id = oci_load_balancer.global_lb.id
  name             = "primary-backend"
  policy           = "ROUND_ROBIN"
  health_checker {
    protocol            = "HTTP"
    port                = 8080
    url_path           = "/health"
    interval_ms        = 10000
    timeout_in_millis  = 3000
    retries            = 3
  }
}

resource "oci_load_balancer_backend_set" "secondary_backend" {
  load_balancer_id = oci_load_balancer.global_lb.id
  name             = "secondary-backend"
  policy           = "ROUND_ROBIN"
  health_checker {
    protocol            = "HTTP"
    port                = 8080
    url_path           = "/health"
    interval_ms        = 10000
    timeout_in_millis  = 3000
    retries            = 3
  }
} 