# Service level objectives

> **Draft.** Filled in Phase 4 together with the recording rules, burn-rate
> alerts and their tests. The targets below are the planned ones.

| SLO | SLI (good / valid events) | Target (30 days) |
|---|---|---|
| API availability | non-5xx requests / all requests, `uptime_http_requests_total` without `/healthz`, `/readyz` | 99.5 % |
| API latency | requests faster than 250 ms / all requests | 95 % |
| Check timeliness | checks started within 5 s of schedule / all checks | 99 % |
| Notification delivery | notifications delivered within 60 s / all notifications | 99 % |
| External availability (reference) | successful blackbox probes of the public `/readyz` | 99.5 % |

To be added in Phase 4:

- error budget per SLO in minutes and events;
- error budget policy (what happens when a budget is exhausted);
- the low-traffic caveat and the minimum request volume guard;
- SLO review cadence.
