terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  cloud_id  = "b1gftbsd8qcsji4lvqd2"     
  folder_id = "b1glt1ekpsufq10uno48"    
  zone      = "ru-central1-b"
  token     = "y0__xCqu8KHARjB3RMg0pGwmRPPaF8klvzyr9ppvaXGFtxDGh8EzA"
}

resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet1" {
  name           = "subnet1"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network1.id
  v4_cidr_blocks = ["172.24.8.0/24"]
}

resource "yandex_compute_instance" "vm" {
  count = 2
  name  = "vm${count.index}"

  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd87j6d92jlrbjqbl32q" # Ubuntu 22.04 LTS
      size     = 8
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    user-data = <<-EOT
      #cloud-config
      packages:
        - nginx
      runcmd:
        - systemctl enable nginx
        - systemctl start nginx
    EOT
  }
}

resource "yandex_lb_target_group" "group" {
  name = "group1"

  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.subnet1.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

resource "yandex_lb_network_load_balancer" "balancer1" {
  name                = "balancer1"
  deletion_protection = false

  listener {
    name = "listener1"
    port = 80

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.group.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
