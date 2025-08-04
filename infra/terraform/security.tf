# Security Infrastructure: WAF and API Gateway
# This file defines Web Application Firewall and API Gateway configurations

# WAF (Web Application Firewall)
resource "oci_waf_web_app_firewall" "microservices_waf" {
  compartment_id = var.compartment_id
  display_name   = "microservices-waf"
  backend_type   = "LOAD_BALANCER"
  web_app_firewall_policy_id = oci_waf_web_app_firewall_policy.waf_policy.id
  
  load_balancer_id = oci_load_balancer.global_lb.id
}

# WAF Policy
resource "oci_waf_web_app_firewall_policy" "waf_policy" {
  compartment_id = var.compartment_id
  display_name   = "microservices-waf-policy"
  
  actions {
    name = "action1"
    type = "ALLOW"
  }
  
  actions {
    name = "action2"
    type = "RETURN_HTTP_RESPONSE"
    code = 403
    headers {
      name  = "Content-Type"
      value = "text/html"
    }
    body = "<html><body><h1>Access Denied</h1></body></html>"
  }
  
  rules {
    name = "SQL Injection Rule"
    action_name = "action2"
    condition = "request.url contains 'sql' or request.url contains 'union'"
    condition_language = "JMESPATH"
  }
  
  rules {
    name = "XSS Rule"
    action_name = "action2"
    condition = "request.url contains 'script' or request.url contains 'javascript'"
    condition_language = "JMESPATH"
  }
  
  rules {
    name = "Allow All"
    action_name = "action1"
    condition = "true"
    condition_language = "JMESPATH"
  }
}

# API Gateway
resource "oci_apigateway_gateway" "microservices_api_gateway" {
  compartment_id = var.compartment_id
  display_name   = "microservices-api-gateway"
  endpoint_type  = "PUBLIC"
  subnet_id      = module.vcn_primary.subnets["oke-private-subnet"].id
}

# API Gateway Deployment
resource "oci_apigateway_deployment" "microservices_deployment" {
  compartment_id = var.compartment_id
  gateway_id     = oci_apigateway_gateway.microservices_api_gateway.id
  display_name   = "microservices-api-deployment"
  
  specification {
    routes {
      path = "/api/v1/users"
      methods = ["GET", "POST", "PUT", "DELETE"]
      backend {
        type = "HTTP_BACKEND"
        url  = "http://${oci_load_balancer.global_lb.ip_addresses[0]}/api/v1/users"
      }
    }
    
    routes {
      path = "/api/v1/orders"
      methods = ["GET", "POST", "PUT", "DELETE"]
      backend {
        type = "HTTP_BACKEND"
        url  = "http://${oci_load_balancer.global_lb.ip_addresses[0]}/api/v1/orders"
      }
    }
    
    routes {
      path = "/api/v1/products"
      methods = ["GET", "POST", "PUT", "DELETE"]
      backend {
        type = "HTTP_BACKEND"
        url  = "http://${oci_load_balancer.global_lb.ip_addresses[0]}/api/v1/products"
      }
    }
    
    routes {
      path = "/health"
      methods = ["GET"]
      backend {
        type = "HTTP_BACKEND"
        url  = "http://${oci_load_balancer.global_lb.ip_addresses[0]}/health"
      }
    }
  }
}

# API Gateway Authentication
resource "oci_apigateway_authentication" "api_auth" {
  compartment_id = var.compartment_id
  display_name   = "microservices-api-auth"
  token_header   = "Authorization"
  token_query_param = "token"
  is_anonymous_access_allowed = false
  type = "CUSTOM_AUTHENTICATION"
  
  function_id = oci_functions_function.auth_function.id
}

# Function for API Authentication
resource "oci_functions_function" "auth_function" {
  application_id = oci_functions_application.microservices_app.id
  display_name   = "api-auth-function"
  memory_in_mbs  = 128
  timeout_in_seconds = 30
  
  image = "iad.ocir.io/${var.tenancy_ocid}/auth-function:latest"
  
  config = {
    "DB_HOST" = oci_mysql_db_system.mysql_primary.mysql_endpoint
    "DB_USER" = "admin"
    "DB_PASSWORD" = oci_vault_secret.mysql_password.secret_content
  }
}

# Functions Application
resource "oci_functions_application" "microservices_app" {
  compartment_id = var.compartment_id
  display_name   = "microservices-functions-app"
  subnet_ids     = [module.vcn_primary.subnets["oke-private-subnet"].id]
}

# Network Security Lists
resource "oci_core_security_list" "api_gateway_security_list" {
  compartment_id = var.compartment_id
  vcn_id         = module.vcn_primary.vcn_id
  display_name   = "api-gateway-security-list"
  
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    
    tcp_options {
      min = 443
      max = 443
    }
  }
  
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    
    tcp_options {
      min = 80
      max = 80
    }
  }
}

# Network Security Groups
resource "oci_core_network_security_group" "microservices_nsg" {
  compartment_id = var.compartment_id
  vcn_id         = module.vcn_primary.vcn_id
  display_name   = "microservices-nsg"
}

resource "oci_core_network_security_group_security_rule" "microservices_ingress" {
  network_security_group_id = oci_core_network_security_group.microservices_nsg.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  
  tcp_options {
    destination_port_range {
      min = 8080
      max = 8080
    }
  }
}

resource "oci_core_network_security_group_security_rule" "microservices_egress" {
  network_security_group_id = oci_core_network_security_group.microservices_nsg.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
} 