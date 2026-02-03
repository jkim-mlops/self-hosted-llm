# -----------------------------------------------------------------------------
# Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "llm" {
  metadata {
    name = "llm"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller Service Account (IRSA)
# -----------------------------------------------------------------------------
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }

    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }
}

# -----------------------------------------------------------------------------
# AWS Load Balancer Controller (Helm)
# -----------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.eks.cluster.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [kubernetes_service_account.aws_load_balancer_controller]
}

# -----------------------------------------------------------------------------
# ConfigMaps
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "llm_config" {
  metadata {
    name      = "llm-config"
    namespace = kubernetes_namespace.llm.metadata[0].name
  }

  data = {
    OPENAI_BASE_URL = "http://router-service.llm.svc.cluster.local:8000/v1"
    OPENAI_MODEL    = var.model_id
  }
}

resource "kubernetes_config_map" "router_nginx_config" {
  metadata {
    name      = "router-nginx-config"
    namespace = kubernetes_namespace.llm.metadata[0].name
  }

  data = {
    "nginx.conf" = <<-EOT
    events {
        worker_connections 1024;
    }

    http {
        upstream vllm_backends {
            least_conn;
            server vllm-service.llm.svc.cluster.local:8000;
        }

        server {
            listen 8000;

            location / {
                proxy_pass http://vllm_backends;
                proxy_http_version 1.1;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Connection "";
                proxy_buffering off;
                proxy_read_timeout 300s;
                proxy_connect_timeout 75s;

                # For streaming responses
                chunked_transfer_encoding on;
            }

            location /health {
                return 200 'OK';
                add_header Content-Type text/plain;
            }
        }
    }
    EOT
  }
}

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "llm_secrets" {
  metadata {
    name      = "llm-secrets"
    namespace = kubernetes_namespace.llm.metadata[0].name
  }

  data = {
    OPENAI_API_KEY = "sk-local-dummy-key"
  }

  type = "Opaque"
}

# -----------------------------------------------------------------------------
# NVIDIA Device Plugin DaemonSet
# -----------------------------------------------------------------------------
resource "kubernetes_daemonset" "nvidia_device_plugin" {
  metadata {
    name      = "nvidia-device-plugin-daemonset"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        name = "nvidia-device-plugin-ds"
      }
    }

    strategy {
      type = "RollingUpdate"
    }

    template {
      metadata {
        labels = {
          name = "nvidia-device-plugin-ds"
        }
      }

      spec {
        toleration {
          key      = "nvidia.com/gpu"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        priority_class_name = "system-node-critical"

        container {
          name  = "nvidia-device-plugin-ctr"
          image = "nvcr.io/nvidia/k8s-device-plugin:v0.14.1"

          env {
            name  = "FAIL_ON_INIT_ERROR"
            value = "false"
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "device-plugin"
            mount_path = "/var/lib/kubelet/device-plugins"
          }
        }

        volume {
          name = "device-plugin"
          host_path {
            path = "/var/lib/kubelet/device-plugins"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values   = ["g5.2xlarge", "g5.4xlarge", "g5.8xlarge", "g5.12xlarge", "g5.16xlarge", "g5.24xlarge", "g5.48xlarge", "p4d.24xlarge", "p5.48xlarge"]
                }
              }
            }
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# vLLM Service Account (IRSA for S3 Access)
# -----------------------------------------------------------------------------
resource "kubernetes_service_account" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace.llm.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.vllm.arn
    }

    labels = {
      app = "vllm"
    }
  }
}

# -----------------------------------------------------------------------------
# vLLM Deployment
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace.llm.metadata[0].name

    labels = {
      app = "vllm"
    }
  }

  spec {
    replicas = var.vllm_replicas

    selector {
      match_labels = {
        app = "vllm"
      }
    }

    template {
      metadata {
        labels = {
          app = "vllm"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.vllm.metadata[0].name

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values   = ["g5.2xlarge"]
                }
              }
            }
          }
        }

        toleration {
          key      = "nvidia.com/gpu"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        init_container {
          name  = "model-downloader"
          image = "amazon/aws-cli:latest"

          command = ["/bin/sh", "-c"]
          args = [
            "aws s3 sync s3://${aws_s3_bucket.model.id}/${var.model_s3_prefix}/ /model/"
          ]

          volume_mount {
            name       = "model-storage"
            mount_path = "/model"
          }
        }

        container {
          name  = "vllm"
          image = "${module.vllm-server.ecr_repo.repository_url}@${module.vllm-server.image.sha256_digest}"

          port {
            container_port = 8000
            name           = "http"
          }

          resources {
            limits = {
              "nvidia.com/gpu" = "1"
              memory           = "24Gi"
            }
            requests = {
              "nvidia.com/gpu" = "1"
              memory           = "16Gi"
              cpu              = "4"
            }
          }

          volume_mount {
            name       = "model-storage"
            mount_path = "/model"
          }

          volume_mount {
            name       = "shm"
            mount_path = "/dev/shm"
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            timeout_seconds       = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }

        volume {
          name = "model-storage"
          empty_dir {
            size_limit = "50Gi"
          }
        }

        volume {
          name = "shm"
          empty_dir {
            medium     = "Memory"
            size_limit = "8Gi"
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# vLLM Service
# -----------------------------------------------------------------------------
resource "kubernetes_service" "vllm" {
  metadata {
    name      = "vllm-service"
    namespace = kubernetes_namespace.llm.metadata[0].name

    labels = {
      app = "vllm"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "vllm"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }
  }
}

# -----------------------------------------------------------------------------
# Router Deployment (Nginx Load Balancer)
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "router" {
  metadata {
    name      = "router"
    namespace = kubernetes_namespace.llm.metadata[0].name

    labels = {
      app = "router"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "router"
      }
    }

    template {
      metadata {
        labels = {
          app = "router"
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values   = ["t3.medium"]
                }
              }
            }
          }
        }

        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"

          port {
            container_port = 8000
            name           = "http"
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
          }

          resources {
            limits = {
              memory = "256Mi"
              cpu    = "500m"
            }
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map.router_nginx_config.metadata[0].name
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Router Service
# -----------------------------------------------------------------------------
resource "kubernetes_service" "router" {
  metadata {
    name      = "router-service"
    namespace = kubernetes_namespace.llm.metadata[0].name

    labels = {
      app = "router"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "router"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }
  }
}

# -----------------------------------------------------------------------------
# Chatbot Deployment
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "chatbot" {
  metadata {
    name      = "chatbot"
    namespace = kubernetes_namespace.llm.metadata[0].name

    labels = {
      app = "chatbot"
    }
  }

  spec {
    replicas = var.chatbot_replicas

    selector {
      match_labels = {
        app = "chatbot"
      }
    }

    template {
      metadata {
        labels = {
          app = "chatbot"
        }
      }

      spec {
        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node.kubernetes.io/instance-type"
                  operator = "In"
                  values   = ["t3.medium"]
                }
              }
            }
          }
        }

        container {
          name  = "chatbot"
          image = "${module.chatbot.ecr_repo.repository_url}@${module.chatbot.image.sha256_digest}"

          port {
            container_port = 8501
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.llm_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.llm_secrets.metadata[0].name
            }
          }

          resources {
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
          }

          liveness_probe {
            http_get {
              path = "/_stcore/health"
              port = 8501
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/_stcore/health"
              port = 8501
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Chatbot Service
# -----------------------------------------------------------------------------
resource "kubernetes_service" "chatbot" {
  metadata {
    name      = "chatbot-service"
    namespace = kubernetes_namespace.llm.metadata[0].name

    labels = {
      app = "chatbot"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "chatbot"
    }

    port {
      name        = "http"
      port        = 8501
      target_port = 8501
      protocol    = "TCP"
    }
  }
}

# -----------------------------------------------------------------------------
# Ingress (ALB)
# -----------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "chatbot" {
  metadata {
    name      = "chatbot-ingress"
    namespace = kubernetes_namespace.llm.metadata[0].name

    annotations = {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = jsonencode([{ "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/certificate-arn"  = aws_acm_certificate.chatbot.arn
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/_stcore/health"
      "alb.ingress.kubernetes.io/subnets"          = join(",", module.vpc.public_subnet_ids)
      "alb.ingress.kubernetes.io/security-groups"  = aws_security_group.alb.id
    }
  }

  spec {
    rule {
      host = var.domain_name

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.chatbot.metadata[0].name
              port {
                number = 8501
              }
            }
          }
        }
      }
    }
  }

  depends_on = [aws_acm_certificate_validation.chatbot]
}

# -----------------------------------------------------------------------------
# Route 53 Record for ALB
# NOTE: DNS record is created via 'task apply' after ALB is provisioned
# and deleted via 'task cleanup' before destroy. This avoids circular
# dependencies that break terraform destroy.
# -----------------------------------------------------------------------------
# To manually create DNS after deployment:
#   aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> \
#     --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"<DOMAIN>","Type":"A","AliasTarget":{"HostedZoneId":"<ALB_ZONE_ID>","DNSName":"<ALB_DNS_NAME>","EvaluateTargetHealth":true}}}]}'
