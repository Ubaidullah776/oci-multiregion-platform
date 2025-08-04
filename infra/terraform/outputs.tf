outputs:
  kubeconfig:
    description: "Kubeconfig to connect to the OKE cluster"
    value: oci_containerengine_cluster.kubeconfig

  cluster_id:
    description: "OKE Cluster ID"
    value: oci_containerengine_cluster.main.id

  node_pool_ids:
    description: "Node pool IDs"
    value: [for np in oci_containerengine_node_pool.node_pools : np.id]
