#!/bin/bash

kubectl apply -f gremlins/gremlin-2.yaml
sleep 3
k6 run --vus 100 --duration 120s -e VOTE_URL=https://<DNSNAME>.<LOCATION>.cloudapp.azure.com/ generate-votes-test.js

# Issue: CPU limit in deployment too low
# Symptom: 502 Bad Gateway error
# Effect: Website is unusable
# Detection:
# - kubectl get pods
# - kubectl get deploy -o wide
# - kubectl describe pod/azure-vote-front-XXXXXXXXXX
# - kubectl logs pod/azure-vote-front-XXXXXXXXXX
# - kubectl diff -f apps/azure-vote/
# - Check container in Azure Portal Container Insights (live data, status, 95TH%, trend, etc.)
# - kubectl top pod
# - Log Analytics:
# KubeEvents
# | where TimeGenerated > ago(24h)
# | where Reason in ("Failed")
# | summarize count() by Reason, bin(TimeGenerated, 5m)
# | render areachart
# Fix:
# - Change CPU limit to higher amount and/or increase replicas: kubectl apply -f apps/azure-vote/azure-vote-front.deploy.yaml
# Improvements:
# - Add Application Insights to show live metrics, application map, error rates, etc.
