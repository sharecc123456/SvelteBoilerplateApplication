variable "boilerplate_image" {
  type = string
}

variable "boilerplate_hash" {
  type = string
}

job "boilerplate-XXXREDMINETICKETXXX" {
  datacenters = ["dc1"]
  type = "service"

  group "postgres-db" {
    network {
      port "postgres" { to = "5432" }
    }

    service {
    	name = "postgres-db-XXXREDMINETICKETXXX"
	port = "postgres"
        check {
          type     = "tcp"
          port     = "postgres"
          interval = "10s"
          timeout  = "2s"
        }
    }

    task "postgres" {
      driver = "docker"
      config {
        image = "postgres:12.7"
	ports = ["postgres"]
	# command = "postgres"
      }
      env {
        POSTGRES_DB = "boilerplate_dev"
      	POSTGRES_USER = "postgres"
        POSTGRES_PASSWORD = "postgres"
      }
    }
  }

  group "redis-db" {
    network {
      port "redis" { to = "6379" }
    }

    service {
    	name = "redis-db-XXXREDMINETICKETXXX"
	port = "redis"
        check {
          type     = "tcp"
          port     = "redis"
          interval = "10s"
          timeout  = "2s"
        }
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:6.2"
	ports = ["redis"]
      }
    }
  }

  group "webs" {
    count = 1
    network {
      port "http" {}
    }

    service {
      name = "boilerplate-XXXREDMINETICKETXXX"
      port = "http"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.rule=Host(`boilerplate-XXXREDMINETICKETXXX.nomad.boilerplate.co`)",
        "traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.tls=true",
        "traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.tls.certresolver=le",
        "external-traefik.enable=true",
        "external-traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.rule=Host(`boilerplate-XXXREDMINETICKETXXX.internal.boilerplate.co`)",
        "external-traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.tls=true",
        "external-traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.tls.certresolver=le",
        "external-traefik.http.routers.boilerplate-XXXREDMINETICKETXXX.middlewares=sso@file"
      ]
    }

    task "await-postgres" {
      driver = "docker"
    
      config {
        image        = "alpine:latest"
        command      = "sh"
        args         = ["-c", "echo -n 'Waiting for service'; until nslookup -port=8600 postgres-db-XXXREDMINETICKETXXX.service.consul 127.0.0.1 2>&1 >/dev/null; do echo '.'; sleep 2; done"]
        network_mode = "host"
      }
    
      resources {
        cpu    = 200
        memory = 128
      }
    
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "await-redis" {
      driver = "docker"
    
      config {
        image        = "alpine:latest"
        command      = "sh"
        args         = ["-c", "echo -n 'Waiting for service'; until nslookup -port=8600 redis-db-XXXREDMINETICKETXXX.service.consul 127.0.0.1 2>&1 >/dev/null; do echo '.'; sleep 2; done"]
        network_mode = "host"
      }
    
      resources {
        cpu    = 200
        memory = 128
      }
    
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }

    task "boilerplate" {
      driver = "docker"
      config {
        image = var.boilerplate_image
        ports = ["http"]
        network_mode = "host"
        force_pull = true
      }

      env {
          BOILERPLATE_IMAGE_HASH = var.boilerplate_hash
      }

      template {
        env = true
	destination = "local/envvars.txt"
	data = <<EOH
{{ if service "postgres-db-XXXREDMINETICKETXXX" }}
{{ with index (service "postgres-db-XXXREDMINETICKETXXX") 0 }}
DATABASE_URL="ecto://postgres:postgres@{{ .Address }}:{{ .Port }}/boilerplate_dev"
BOILERPLATE_DOCKER_DB_ADDR="{{ .Address }}:{{ .Port }}"
{{ end }}
{{ end }}
DOPPLER_TOKEN="{{ key "nomad/doppler_token" }}"
BOILERPLATE_COMMAND="create"
BOILERPLATE_HOSTNAME=boilerplate-XXXREDMINETICKETXXX.internal.boilerplate.co
BOILERPLATE_DOMAIN="https://boilerplate-XXXREDMINETICKETXXX.internal.boilerplate.co"
BOILERPLATE_NOMAD=1
DISABLE_HTTPS=1
ROLLBAR_ENV="nomad-XXXREDMINETICKETXXX"
HTTPS_PORT=0
HTTP_PORT="{{ env "NOMAD_PORT_http" }}"
REDMINE_TICKET=XXXREDMINETICKETXXX
{{ if service "redis-db-XXXREDMINETICKETXXX" }}
{{ with index (service "redis-db-XXXREDMINETICKETXXX") 0 }}
REDIS_HOST="{{ .Address }}"
REDIS_PORT="{{ .Port }}"
{{ end }}
{{ end }}
EOH
      }
    }
  }


}
