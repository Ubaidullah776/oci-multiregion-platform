variables:
  region:
    description: "OCI region to deploy resources"
    type: string
    default: "us-ashburn-1"

  compartment_ocid:
    description: "OCI Compartment OCID"
    type: string

  vcn_id:
    description: "Virtual Cloud Network OCID"
    type: string

  oke_cluster_name:
    description: "Name of the OKE cluster"
    type: string
    default: "springboot-microservices-cluster"

  node_pool_size:
    description: "Number of worker nodes"
    type: number
    default: 3
