# Distributed Tracing: PHP on EKS Fargate → AWS X-Ray

Reference manifests and Dockerfile for instrumenting a **PHP 8.4 (Slim)** microservice
on **EKS Fargate** with **OpenTelemetry**, exporting traces to **AWS X-Ray** via the
**ADOT Collector running as a native sidecar**.

> 📖 Full walkthrough: [`distributed-tracing-php-eks-fargate-xray.md`](./distributed-tracing-php-eks-fargate-xray.md)

## Why this exists

Most AWS/ADOT tracing guides deploy the OpenTelemetry Collector as a **DaemonSet**.
**DaemonSets do not run on Fargate.** There is no node you control — the pod *is* the
compute unit. So the collector has to run *inside* each pod.

The pattern here:

- ADOT Collector as an `initContainer` with `restartPolicy: Always` (**native sidecar**, k8s 1.29+)
- PHP app exports OTLP/HTTP to `localhost:4318` (containers share the pod network namespace)
- Credentials via **IRSA** (ServiceAccount annotated with an IAM role ARN)
- Zero application code changes — all config via the `opentelemetry` PHP extension + env vars

## Layout

```
docker/
  Dockerfile      # PHP 8.4-FPM + OTel extension via install-php-extensions
  php.ini
  www.conf
k8s/
  demo-serviceaccount-production.yaml              # IRSA
  demo-test-otel-config-production.yaml      # ADOT Collector config
  demo-test-with-xray-deployment-production.yaml
  demo-test-app-env-production.yaml
  demo-test-nginx-conf-production.yaml
  demo-test-nginx-default-conf-production.yaml
  demo-test-svc-production.yaml
  demo-test-ingress-production.yaml
```

## ⚠️ Before you use these

All secrets and account-specific values are replaced with `xxxxxxxx` or `<ACCOUNT_ID>`.
You must substitute your own:

| Placeholder | Where |
|---|---|
| `<ACCOUNT_ID>` | ECR image, ACM cert ARN, IAM role ARN |
| `<IMAGE_TAG>` | Deployment image tag |
| `xxxxxxxx` | JWT secret, API keys, Redis endpoint, hostnames, IAM role name |

**Do not store real secrets in ConfigMaps.** Use AWS Secrets Manager + External Secrets
Operator, SOPS, or Sealed Secrets. The ConfigMap here is what we had; it is not what you
should copy.

## Quick verify

```bash
# 1. Extension is actually loaded in the image
docker run --rm <image> php -m | grep -i opentelemetry

# 2. Collector is up
POD=$(kubectl get pods -n production -l app=demo-test-production -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD -n production -c otel-collector | grep "Everything is ready"

# 3. Spans are exporting
kubectl logs $POD -n production -c otel-collector | grep "Exporting traces"
```

**Note:** sampling is set to `0.1` (10%). Set `OTEL_TRACES_SAMPLER_ARG=1.0` while validating.
