# High Availability Database Infrastructure
# This file defines HA setups for MySQL, Kafka, RabbitMQ, and Redis

# MySQL HA Cluster
resource "oci_mysql_db_system" "mysql_primary" {
  compartment_id = var.compartment_id
  display_name   = "mysql-primary-${var.primary_region}"
  shape_name     = "MySQL.VM.Standard.E3.1.8GB"
  subnet_id      = module.vcn_primary.subnets["oke-private-subnet"].id
  hostname_label = "mysql-primary"
  
  configuration_id = data.oci_mysql_mysql_configuration.mysql_config.id
  
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  
  data_storage_size_in_gb = 50
  
  admin_username = "admin"
  admin_password = oci_vault_secret.mysql_password.secret_content
  
  backup_policy {
    is_enabled        = true
    retention_in_days = 7
    window_start_time = "02:00"
  }
}

resource "oci_mysql_db_system" "mysql_secondary" {
  compartment_id = var.compartment_id
  display_name   = "mysql-secondary-${var.secondary_region}"
  shape_name     = "MySQL.VM.Standard.E3.1.8GB"
  subnet_id      = module.vcn_secondary.subnets["oke-private-subnet"].id
  hostname_label = "mysql-secondary"
  
  configuration_id = data.oci_mysql_mysql_configuration.mysql_config.id
  
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  
  data_storage_size_in_gb = 50
  
  admin_username = "admin"
  admin_password = oci_vault_secret.mysql_password.secret_content
  
  backup_policy {
    is_enabled        = true
    retention_in_days = 7
    window_start_time = "02:00"
  }
}

# Kafka Cluster
resource "oci_streaming_stream" "kafka_stream" {
  compartment_id = var.compartment_id
  name           = "microservices-kafka-stream"
  partitions     = 3
  retention_in_hours = 24
  stream_pool_id = oci_streaming_stream_pool.kafka_pool.id
}

resource "oci_streaming_stream_pool" "kafka_pool" {
  compartment_id = var.compartment_id
  name           = "microservices-kafka-pool"
  kafka_settings {
    auto_create_topics_enable = true
    log_retention_hours      = 24
    num_partitions          = 3
  }
}

# RabbitMQ HA Cluster (using OCI Compute instances)
resource "oci_core_instance" "rabbitmq_primary" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "rabbitmq-primary"
  shape               = "VM.Standard.E4.Flex"
  
  shape_config {
    ocpus         = 2
    memory_in_gbs = 16
  }
  
  create_vnic_details {
    subnet_id        = module.vcn_primary.subnets["oke-private-subnet"].id
    assign_public_ip = false
  }
  
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y rabbitmq-server
              systemctl enable rabbitmq-server
              systemctl start rabbitmq-server
              rabbitmq-plugins enable rabbitmq_management
              EOF
    )
  }
}

resource "oci_core_instance" "rabbitmq_secondary" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "rabbitmq-secondary"
  shape               = "VM.Standard.E4.Flex"
  
  shape_config {
    ocpus         = 2
    memory_in_gbs = 16
  }
  
  create_vnic_details {
    subnet_id        = module.vcn_secondary.subnets["oke-private-subnet"].id
    assign_public_ip = false
  }
  
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y rabbitmq-server
              systemctl enable rabbitmq-server
              systemctl start rabbitmq-server
              rabbitmq-plugins enable rabbitmq_management
              EOF
    )
  }
}

# Redis HA Cluster
resource "oci_core_instance" "redis_primary" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "redis-primary"
  shape               = "VM.Standard.E4.Flex"
  
  shape_config {
    ocpus         = 2
    memory_in_gbs = 16
  }
  
  create_vnic_details {
    subnet_id        = module.vcn_primary.subnets["oke-private-subnet"].id
    assign_public_ip = false
  }
  
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y redis-server
              systemctl enable redis-server
              systemctl start redis-server
              EOF
    )
  }
}

resource "oci_core_instance" "redis_secondary" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "redis-secondary"
  shape               = "VM.Standard.E4.Flex"
  
  shape_config {
    ocpus         = 2
    memory_in_gbs = 16
  }
  
  create_vnic_details {
    subnet_id        = module.vcn_secondary.subnets["oke-private-subnet"].id
    assign_public_ip = false
  }
  
  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }
  
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y redis-server
              systemctl enable redis-server
              systemctl start redis-server
              EOF
    )
  }
}

# Data sources
data "oci_mysql_mysql_configuration" "mysql_config" {
  configuration_id = "ocid1.mysql8.0.32.20230901.1"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                   = "VM.Standard.E4.Flex"
  state                   = "AVAILABLE"
  sort_by                 = "TIMECREATED"
  sort_order              = "DESC"
} 