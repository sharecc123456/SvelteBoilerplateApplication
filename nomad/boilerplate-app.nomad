variable "boilerplate_image" {
  type = string
}

variable "boilerplate_hash" {
  type = string
}

variable "aws_key" {
  type = string
}

job "boilerplate-app" {
  datacenters = ["dc_app"]
  type = "service"

  group "webs" {
    count = 1
    network {
      port "https" { to = 5000 }
      port "http" { to = 4000 }
    }

    service {
      name = "boilerplate-app"
      port = "https"
    }

    task "boilerplate" {
      driver = "docker"
      config {
        image = var.boilerplate_image
        ports = ["https", "http"]
        network_mode = "host"
        force_pull = true
        auth {
            username = "AWS"
            password = var.aws_key
        }
      }

      resources {
          cpu = 5000
          memory = 8000
      }

      env {
          BOILERPLATE_IMAGE_HASH = var.boilerplate_hash
          ROOT_CA_LOCATION = "/app/Boilerplate-RootCA.crt"
      }

      template {
        env = true
        destination = "local/envvars.txt"
	data = <<EOH
BOILERPLATE_DOCKER_DB_ADDR="localhost:5432"
DOPPLER_TOKEN="{{ key "app/doppler_token" }}"
BOILERPLATE_COMMAND="migrate"
BOILERPLATE_NOMAD=0
EOH
      }
    }
  }
}
