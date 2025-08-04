# Cost Optimization Configuration
# This file implements cost optimization strategies for the multi-region platform

# Cost Allocation Tags
resource "oci_identity_tag_namespace" "cost_tags" {
  compartment_id = var.compartment_id
  name           = "cost-center"
  description    = "Cost allocation tags for microservices platform"
}

resource "oci_identity_tag" "environment" {
  compartment_id = var.compartment_id
  tag_namespace_id = oci_identity_tag_namespace.cost_tags.id
  name             = "environment"
  description      = "Environment tag for cost allocation"
  
  validator {
    validator_type = "ENUM"
    values         = ["production", "staging", "development"]
  }
}

resource "oci_identity_tag" "service" {
  compartment_id = var.compartment_id
  tag_namespace_id = oci_identity_tag_namespace.cost_tags.id
  name             = "service"
  description      = "Service tag for cost allocation"
  
  validator {
    validator_type = "ENUM"
    values         = ["microservices", "database", "messaging", "monitoring", "storage"]
  }
}

resource "oci_identity_tag" "cost_center" {
  compartment_id = var.compartment_id
  tag_namespace_id = oci_identity_tag_namespace.cost_tags.id
  name             = "cost-center"
  description      = "Cost center for budget allocation"
  
  validator {
    validator_type = "ENUM"
    values         = ["platform", "development", "operations"]
  }
}

# Auto-scaling Configuration for OKE
resource "oci_container_engine_node_pool" "oke_autoscaling" {
  cluster_id         = module.oke_primary.cluster_id
  compartment_id     = var.compartment_id
  kubernetes_version = "v1.28.2"
  name               = "autoscaling-pool"
  node_shape         = "VM.Standard.E4.Flex"
  
  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id          = module.vcn_primary.subnets["oke-private-subnet"].id
    }
    
    size = 2
    
    node_shape_config {
      ocpus         = 2
      memory_in_gbs = 16
    }
  }
  
  initial_node_labels {
    key   = "cost-center"
    value = "platform"
  }
  
  initial_node_labels {
    key   = "environment"
    value = "production"
  }
  
  initial_node_labels {
    key   = "service"
    value = "microservices"
  }
}

# Spot Instance Configuration for Non-Critical Workloads
resource "oci_core_instance_pool" "spot_instances" {
  compartment_id = var.compartment_id
  display_name   = "spot-instance-pool"
  instance_configuration_id = oci_core_instance_configuration.spot_config.id
  
  placement_configurations {
    availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
    primary_subnet_id   = module.vcn_primary.subnets["oke-private-subnet"].id
  }
  
  size = 1
  
  load_balancers {
    backend_set_name = "backend-set"
    load_balancer_id = oci_load_balancer.lb.id
    port             = 8080
    vnic_selection   = "PrimaryVnic"
  }
  
  defined_tags = {
    "${oci_identity_tag_namespace.cost_tags.name}.${oci_identity_tag.environment.name}" = "production"
    "${oci_identity_tag_namespace.cost_tags.name}.${oci_identity_tag.service.name}"     = "microservices"
    "${oci_identity_tag_namespace.cost_tags.name}.${oci_identity_tag.cost_center.name}" = "platform"
  }
}

# Instance Configuration for Spot Instances
resource "oci_core_instance_configuration" "spot_config" {
  compartment_id = var.compartment_id
  display_name   = "spot-instance-config"
  
  instance_details {
    instance_type = "compute"
    
    launch_details {
      compartment_id = var.compartment_id
      shape          = "VM.Standard.E4.Flex"
      
      shape_config {
        ocpus         = 1
        memory_in_gbs = 8
      }
      
      create_vnic_details {
        subnet_id        = module.vcn_primary.subnets["oke-private-subnet"].id
        assign_public_ip = false
      }
      
      source_details {
        source_type = "image"
        source_id   = data.oci_core_images.ubuntu.images[0].id
      }
    }
  }
}

# Cost Monitoring and Budget Alerts
resource "oci_budget_budget" "platform_budget" {
  compartment_id = var.compartment_id
  display_name   = "microservices-platform-budget"
  amount         = 5000
  reset_period   = "MONTHLY"
  
  target_type = "COMPARTMENT"
  targets     = [var.compartment_id]
}

resource "oci_budget_alert_rule" "budget_alert_80" {
  budget_id      = oci_budget_budget.platform_budget.id
  display_name   = "80-percent-budget-alert"
  message        = "Platform costs have reached 80% of monthly budget"
  threshold      = 80
  threshold_type = "PERCENTAGE"
  
  recipients = "devops-team@company.com"
}

resource "oci_budget_alert_rule" "budget_alert_100" {
  budget_id      = oci_budget_budget.platform_budget.id
  display_name   = "100-percent-budget-alert"
  message        = "Platform costs have reached 100% of monthly budget"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  
  recipients = "devops-team@company.com,management@company.com"
}

# Resource Right-sizing Recommendations
resource "oci_monitoring_alarm" "cpu_utilization_low" {
  compartment_id = var.compartment_id
  display_name   = "low-cpu-utilization-alert"
  is_enabled     = true
  
  metric_compartment_id = var.compartment_id
  namespace            = "oci_computeagent"
  query                = "CpuUtilization[1m].mean() < 20"
  severity             = "WARNING"
  
  destinations = ["${oci_ons_notification_topic.cost_alerts.topic_id}"]
  
  message_format = "ONS_OPTIMIZED"
  pending_duration = "PT5M"
}

resource "oci_monitoring_alarm" "memory_utilization_low" {
  compartment_id = var.compartment_id
  display_name   = "low-memory-utilization-alert"
  is_enabled     = true
  
  metric_compartment_id = var.compartment_id
  namespace            = "oci_computeagent"
  query                = "MemoryUtilization[1m].mean() < 30"
  severity             = "WARNING"
  
  destinations = ["${oci_ons_notification_topic.cost_alerts.topic_id}"]
  
  message_format = "ONS_OPTIMIZED"
  pending_duration = "PT5M"
}

# Notification Topic for Cost Alerts
resource "oci_ons_notification_topic" "cost_alerts" {
  compartment_id = var.compartment_id
  name           = "cost-optimization-alerts"
  description    = "Notifications for cost optimization alerts"
}

# Outputs for Cost Management
output "budget_id" {
  description = "Platform budget ID"
  value       = oci_budget_budget.platform_budget.id
}

output "cost_alert_topic_id" {
  description = "Cost alert notification topic ID"
  value       = oci_ons_notification_topic.cost_alerts.topic_id
} 