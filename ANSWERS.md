# HW4 — Model Deployment & Scaling

Nicholas Place · nmplace@unc.edu · ONYEN: nmplace

## 1. Rolling-update safety

`maxUnavailable: 0` prevents a rolling update from reducing the number of available replicas below the desired count; with `maxSurge: 1`, Kubernetes can start a replacement and wait for readiness before removing an old pod. At `maxUnavailable: 1`, it could remove one available replica before its replacement is ready, temporarily reducing capacity from three to two. Neither setting alone guarantees zero dropped requests: readiness checks, graceful shutdown, and enough capacity also matter.

## 2. Health probes

`/health` is a lightweight endpoint that checks whether the API can respond without running inference or accessing Redis. Probing `/predict` would require a transaction payload, consume scoring capacity, and could trigger restarts because of a downstream dependency rather than a broken API process. Here, readiness gates Service traffic and liveness determines whether the container needs restarting.

## 3. Autoscaling under load

If traffic doubled and CPU usage increased proportionally, the HPA would increase replicas to bring average CPU utilization toward 40% of each pod's 100m CPU request, subject to measurement delays and scheduling capacity. For example, three pods already at the target would need roughly six pods under twice that CPU-bound load. At eight pods, the HPA cannot add more replicas, so sustained excess demand can increase latency, throttling, or errors and requires more capacity or application improvements.

## AI assistance disclosure

Codex assisted with interpreting the assignment, walking me through running deployment and verification commands, and drafting documentation. I feel comfortable explaining any of the steps of this assignment and doing a similar Azure deployment fully on my own.
