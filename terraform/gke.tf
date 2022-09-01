data "google_project" "project" {}

data "google_container_engine_versions" "central1a" {
  location       = var.zone
  version_prefix = "1.21.14"
}

resource "google_container_cluster" "kfcluster" {
  name               = var.cluster_name
  location           = var.zone
  initial_node_count = 1

  networking_mode = "VPC_NATIVE"

  node_version       = data.google_container_engine_versions.central1a.latest_node_version
  min_master_version = data.google_container_engine_versions.central1a.latest_node_version

  addons_config {
    network_policy_config {
      disabled = false
    }
  }

  workload_identity_config {
    workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
  }


  resource_labels = {
    "mesh_id" = "proj-${data.google_project.project.number}"
  }

  ip_allocation_policy {}

}

resource "google_container_node_pool" "main" {
  location           = var.zone
  cluster            = google_container_cluster.kfcluster.name
  initial_node_count = 3

  node_config {
    machine_type = var.cluster_machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    service_account = data.google_service_account.cluster_service_account.email

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_artifact_registry_repository" "kf_cluster_repo" {
  location      = var.region
  repository_id = var.cluster_name
  format        = "DOCKER"
}
