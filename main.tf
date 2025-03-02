provider "google" {
  project = "vcc-25"
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_instance_template" "vcc" {
  name         = "vm-vcc"
  machine_type = "n1-standard-1"

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {}
  }

  tags = ["http-server"]
}

resource "google_compute_instance_group_manager" "vcc" {
  name               = "igm-vcc"
  base_instance_name = "vm-vcc"
  zone               = "us-central1-a"

  version {
    instance_template = google_compute_instance_template.vcc.id
    name              = "primary"
  }

  target_size = 3
}

resource "google_compute_autoscaler" "vcc" {
  name   = "autoscaler-for-vm"
  zone   = "us-central1-a"
  target = google_compute_instance_group_manager.vcc.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

resource "google_project_iam_custom_role" "vm_admin" {
  role_id     = "vmAdmin"
  title       = "VM Admin"
  description = "Custom role for VM administration"
  permissions = [
    "compute.instances.get",
    "compute.instances.list",
    "compute.instances.create",
    "compute.instances.delete"
  ]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
