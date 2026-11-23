# Deployment evidence

Captured on November 22, 2026, using the local Minikube context `data789-hw4`.

| Requirement | Screenshot | Raw transcript |
| --- | --- | --- |
| Three ready replicas, probes/resources/owner, real HPA CPU target, Service | [Status](../screenshots/01-kubernetes-status.png) | [Status log](01-kubernetes-status.log) |
| Successful `/predict` through the local Service port-forward | [HTTP 200](../screenshots/02-predict.png) | [Prediction log](02-predict.log) |
| Delete a pod and automatically recover to 3/3 | [Self-healing](../screenshots/03-self-healing.png) | [Recovery log](03-self-healing.log) |
| Roll from published `v1` to `v2`, 193/193 successful, zero dropped | [Rolling update](../screenshots/04-rolling-update.png) | [Rolling log](04-rolling-update.log) |
| Flip Service to green and verify ready endpoints and HTTP 200 | [Cutover](../screenshots/05-blue-green-cutover.png) | [Cutover log](05-blue-green-cutover.log) |
| Flip Service back to blue and verify HTTP 200 | [Rollback](../screenshots/06-blue-green-rollback.png) | [Rollback log](06-blue-green-rollback.log) |
| Continuous request loop across blue → green → blue, 77/77 successful | See cutover and rollback screenshots | [Full blue-green demo](05-blue-green.log) |
| Azure public `/predict` HTTP 200 | [Azure response](../screenshots/07-azure-predict.png) | [Cloud Shell deployment and smoke test](08-azure-cloudshell.log); [independent external test](07-azure-external-predict.log) |
| Same-day Azure teardown; resource group no longer exists | [Deletion confirmation](../screenshots/08-azure-teardown.png) | [Cloud Shell transcript, ending in `false`](08-azure-cloudshell.log) |

Screenshots capture actual terminal command output. The full blue-green demo additionally verifies that ready EndpointSlice addresses match the chosen color's pod IPs; separate captures show live selector changes and smoke tests. Both published image tags report `sklearn-logreg-v1` in the response, so the blue-green routing proof uses the Service selector and endpoint/pod IPs rather than that response field.

The local LoadBalancer has an external IP of `<pending>` because no Minikube tunnel was used. Local smoke testing uses the port-forward allowed by the starter runbook, while both request-loop demos use in-cluster Service DNS.

Azure used the student subscription in `westus3`, selected by the starter script from the subscription's allowed regions. The original Cloud Shell transcript was downloaded through the portal and is preserved, including CLI progress characters. Its SHA-256 lines for the unchanged deployment script and config match the repository files. Cloud Shell timestamps use UTC, while the local logs use America/New_York; these are the same November 22, 2026 local session. The cloud resources are deleted, and the Minikube profile is stopped to release local resources.
