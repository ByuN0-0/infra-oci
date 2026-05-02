moved {
  from = oci_artifacts_container_repository.blog_api
  to   = oci_artifacts_container_repository.my_hub_api
}

moved {
  from = oci_identity_dynamic_group.container_instances
  to   = oci_identity_dynamic_group.my_hub_api_compute_instances
}

moved {
  from = oci_identity_policy.container_instances_ocir_read
  to   = oci_identity_policy.my_hub_api_compute_ocir_read
}

moved {
  from = oci_core_network_security_group.blog_api_lb
  to   = oci_core_network_security_group.my_hub_api_lb
}

moved {
  from = oci_core_network_security_group.blog_api_container
  to   = oci_core_network_security_group.my_hub_api_compute
}

moved {
  from = oci_core_instance.blog_api
  to   = oci_core_instance.my_hub_api
}

moved {
  from = oci_load_balancer_load_balancer.blog_api
  to   = oci_load_balancer_load_balancer.my_hub_api
}

moved {
  from = oci_load_balancer_backend_set.blog_api
  to   = oci_load_balancer_backend_set.my_hub_api
}

moved {
  from = oci_load_balancer_backend.blog_api
  to   = oci_load_balancer_backend.my_hub_api
}

moved {
  from = oci_load_balancer_listener.blog_api_http
  to   = oci_load_balancer_listener.my_hub_api_http
}

moved {
  from = oci_mysql_mysql_db_system.blog_api
  to   = oci_mysql_mysql_db_system.my_hub
}

moved {
  from = oci_nosql_table.blog_experiment
  to   = oci_nosql_table.my_hub_experiment
}
