# DATA 789 · HW4 — Model Deployment & Scaling

**Nicholas Place · nmplace@unc.edu · ONYEN: nmplace**

Created from [rfsalas/data789-hw4](https://github.com/rfsalas/data789-hw4). The application uses the published TrustBank `v1` and `v2` images; no application or model was rebuilt. This repository is public for grading, as required by the assignment.

The main Deployment requests 100m CPU / 128Mi per pod, limits each pod to 250m / 192Mi, and labels both the Deployment and pod template `owner: nmplace`. It has three replicas, health probes, a five-second shutdown drain, and a rolling strategy of `maxUnavailable: 0` / `maxSurge: 1`. The HPA targets 40% of requested CPU, with a three-pod minimum and eight-pod maximum. The supplied LoadBalancer Service and Redis manifests are unchanged.

## Reproduce locally

Requires Docker, Minikube, and kubectl. The recorded run used the isolated Minikube profile/context `data789-hw4`.

```bash
minikube start -p data789-hw4 --driver=docker --cpus=4 --memory=6144 --kubernetes-version=v1.34.2
kubectl config use-context data789-hw4
minikube -p data789-hw4 addons enable metrics-server
kubectl apply -f k8s/
kubectl rollout status deployment/redis
kubectl rollout status deployment/trustbank-fraud
kubectl get deployments,pods,svc,hpa
kubectl top pods
```

Allow metrics collection to settle before capturing the HPA. On local Minikube, the LoadBalancer external IP can remain pending; the course runbook permits a port-forward for the smoke test:

```bash
kubectl port-forward svc/trustbank-fraud 18080:80
# In another terminal:
bash scripts/smoke_test.sh http://127.0.0.1:18080
```

Delete one API pod, wait for its replacement, and verify three available replicas:

```bash
kubectl delete pod "$(kubectl get pods -l app=trustbank-fraud -o jsonpath='{.items[0].metadata.name}')"
kubectl rollout status deployment/trustbank-fraud
kubectl get pods -l app=trustbank-fraud
kubectl get deployment trustbank-fraud
```

Run the supplied graded rolling demo and the additional blue-green verification script:

```bash
bash scripts/rolling_update_demo_incluster.sh ghcr.io/rfsalas/trustbank-fraud:v2
bash scripts/bluegreen_demo_incluster.sh
kubectl delete -f k8s/blue-green/
```

The blue-green script keeps a request loop inside the cluster while switching blue → green → blue, verifies ready EndpointSlice addresses against each color's pods, and tests `/predict` at each stage. These demos measure traffic through Kubernetes Service DNS, so they do not depend on a port-forward surviving pod replacement. The tracked main manifest intentionally starts at `v1` so the update to `v2` can be reproduced.

## Evidence and Azure

The rolling update completed with **193/193 successful requests and 0 dropped**. The continuous blue-green cutover and rollback completed with **77/77 successful requests and 0 dropped**. These are measured results from finite request loops, not a guarantee under all workloads.

Real terminal captures are in [`screenshots/`](screenshots/), with corresponding raw command transcripts in [`evidence/`](evidence/). See [`ANSWERS.md`](ANSWERS.md) for the three short answers and AI disclosure, and [`README-hw4.md`](README-hw4.md) for the complete course runbook.

The Azure deployment ran successfully in **Azure Cloud Shell**, using **Azure for Students** and the policy-selected **westus3** region. A source snapshot from this repository was transferred into Cloud Shell, and the unchanged `deploy_azure.sh` imported the provided image into ACR and deployed it to Container Apps using a managed identity. The public `/predict` returned **HTTP 200** both in Cloud Shell and from this machine.

Recorded endpoint: `https://trustbank-fraud.happyplant-cf18bd73.westus3.azurecontainerapps.io/predict`. The homework resource group was deleted the same day, with `az group exists -n rg-data789-hw4-nmplace` returning **false**. The endpoint is historical because the required teardown is complete. See the [Cloud Shell transcript](evidence/08-azure-cloudshell.log), [independent public test](evidence/07-azure-external-predict.log), [Azure response screenshot](screenshots/07-azure-predict.png), and [teardown screenshot](screenshots/08-azure-teardown.png).

For a future Cloud Shell reproduction, `bash scripts/cloudshell_run.sh 2>&1 | tee azure-evidence.log` wraps the unchanged course deploy and teardown scripts: it selects the student subscription, refuses to reuse an existing homework resource group, tests the public endpoint, allows 60 seconds for screenshots, and automatically tears down and waits for deletion. It creates real cloud resources, so only run it when reproducing the Azure step.

To remove the local cluster after review: `minikube delete -p data789-hw4`.
