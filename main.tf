provider "google" {
  project = "vcc-25"
  region  = "us-central1"
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
  metadata = {
    startup-script = <<-EOF
        #!/bin/bash
        apt update && apt install -y apache2
        echo "Hello, Terraform VM!" > /var/www/html/index.html
        systemctl restart apache2
    EOF
  }
  tags = ["http-server"]
}

resource "google_compute_region_instance_group_manager" "vcc" {
  name               = "igm-vcc"
  base_instance_name = "vm-vcc"
  region             = "us-central1"

  version {
    instance_template = google_compute_instance_template.vcc.id
    name              = "primary"
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.default.id
    initial_delay_sec = 300
  }
}

resource "google_compute_autoscaler" "vcc" {
  name   = "autoscaler-for-vm"
  zone   = "us-central1-a"
  target = google_compute_region_instance_group_manager.vcc.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
  depends_on = [google_compute_region_instance_group_manager.vcc]
}

resource "google_compute_health_check" "default" {
  name               = "health-check"
  timeout_sec        = 5
  check_interval_sec = 30
  http_health_check {
    port = 80
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

resource "google_project_iam_binding" "vm_admin_binding" {
  project = "vcc-25"
  role    = google_project_iam_custom_role.vm_admin.id

  members = [
    "serviceAccount:vcc-10@vcc-25.iam.gserviceaccount.com"
  ]
}

resource "google_compute_firewall" "allow_egress" {
  name      = "allow-egress"
  network   = "default"
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  source_ranges      = ["0.0.0.0/0"]
}