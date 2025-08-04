provider "oci" {
  tenancy_ocid        = var.tenancy_ocid
  user_ocid           = var.user_ocid
  fingerprint         = var.fingerprint
  private_key_path    = var.private_key_path
  region              = var.region
}

module "vcn" {
  source           = "oracle-terraform-modules/vcn/oci"
  compartment_id   = var.compartment_id
  vcn_name         = "oke-vcn-${var.region}"
  cidr_block       = "10.0.0.0/16"
  create_internet_gateway = true
  subnets = {
    "oke-private-subnet" = {
      cidr_block = "10.0.10.0/24"
      private    = true
    }
  }
}

module "oke" {
  source                 = "oracle-terraform-modules/oke/oci"
  compartment_id         = var.compartment_id
  cluster_name           = "oke-${var.region}"
  kubernetes_version     = "v1.28.2"
  vcn_id                 = module.vcn.vcn_id
  subnets                = [module.vcn.subnets["oke-private-subnet"].id]
  node_pool_size         = 3
  node_shape             = "VM.Standard.E4.Flex"
  node_ocpus             = 2
  node_memory_gbs        = 16
}

resource "oci_vault_secret" "mysql_password" {
  compartment_id = var.compartment_id
  vault_id       = var.vault_id
  secret_name    = "mysql-password"
  secret_content = base64encode("SuperSecurePassword123")
}
