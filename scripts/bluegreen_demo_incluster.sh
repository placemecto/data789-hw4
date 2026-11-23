#!/usr/bin/env bash
# Verify both selector swaps while requests use the in-cluster Service.
set -euo pipefail
cd "$(dirname "$0")/.."
POD="bluegreen-load-$$"
PAYLOAD="$(cat scripts/sample_transaction.json)"
cleanup() { kubectl delete pod "$POD" --ignore-not-found --now >/dev/null 2>&1 || true; }
trap cleanup EXIT
kubectl apply -f k8s/blue-green/
kubectl rollout status deployment/trustbank-fraud-blue --timeout=180s
kubectl rollout status deployment/trustbank-fraud-green --timeout=180s
bash scripts/bluegreen_switch.sh blue
kubectl run "$POD" --image=curlimages/curl:8.12.1 --restart=Never \
  --env="PAYLOAD=$PAYLOAD" --command -- sh -c '
  total=0; ok=0; bad=0
  while [ ! -f /tmp/stop ]; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
      -X POST http://trustbank-fraud-bg/predict \
      -H "Content-Type: application/json" -d "$PAYLOAD" || true)
    total=$((total+1))
    if [ "$code" = 200 ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
    sleep 0.2
  done
  echo "RESULT $total $ok $bad"'
kubectl wait --for=condition=Ready "pod/$POD" --timeout=90s
for COLOR in blue green blue; do
  echo "=== Service routing to $COLOR ==="
  bash scripts/bluegreen_switch.sh "$COLOR"
  # Wait until EndpointSlices select precisely the intended ready pods.
  EXPECTED="$(kubectl get pods -l "app=trustbank-fraud-bg,color=$COLOR" \
    -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' | sort)"
  MATCHED=false
  for attempt in $(seq 1 30); do
    ACTUAL="$(kubectl get endpointslices -l kubernetes.io/service-name=trustbank-fraud-bg \
      -o jsonpath='{range .items[*].endpoints[?(@.conditions.ready==true)]}{.addresses[0]}{"\n"}{end}' | sort)"
    if [ "$ACTUAL" = "$EXPECTED" ] && [ -n "$ACTUAL" ]; then MATCHED=true; break; fi
    sleep 1
  done
  [ "$MATCHED" = true ] || { echo 'EndpointSlice did not converge'; exit 1; }
  kubectl get svc trustbank-fraud-bg -o custom-columns=NAME:.metadata.name,COLOR:.spec.selector.color
  kubectl get pods -l "app=trustbank-fraud-bg,color=$COLOR" -o wide
  echo "Ready endpoint addresses: $(echo "$ACTUAL" | tr '\n' ' ')"
  kubectl exec "$POD" -- curl --fail-with-body -sS -w '\nHTTP %{http_code}\n' \
    --max-time 10 -X POST http://trustbank-fraud-bg/predict \
    -H 'Content-Type: application/json' -d "$PAYLOAD"
  sleep 5
done
kubectl exec "$POD" -- touch /tmp/stop
kubectl wait --for=jsonpath='{.status.phase}'=Succeeded "pod/$POD" --timeout=30s
read -r _ TOTAL OK BAD < <(kubectl logs "$POD" | sed -n '/^RESULT /p')
echo "Blue -> green -> blue: requests: $TOTAL  ok: $OK  dropped: $BAD"
[ "$TOTAL" -gt 0 ] && [ "$BAD" -eq 0 ]
