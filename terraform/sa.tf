resource "google_service_account" "cluster_service_account" {
  account_id   = var.project_id
  display_name = "${var.cluster_name}-sa"
  description = "GSA for KF ${var.cluster_name}"
}

resource "google_service_account_iam_member" "kf_controller_service_account_admin" {
  service_account_id = google_service_account.cluster_service_account.name
  role               = "roles/iam.serviceAccountAdmin"
  member             = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "kf_controller_metrics_writer_role" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_project_iam_member" "kf_controller_log_writer_role" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cluster_service_account.email}"
}

resource "google_service_account_iam_member" "kf_controller_workload_identity_role" {
  service_account_id = google_service_account.cluster_service_account.name
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project_id}.svc.id.goog[kf/controller]"
}