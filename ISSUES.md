# [ALP-2408] Planning gate: define harness driver boundary before adding clients

## Selector Decision

* Mode: `needs_human_direction`
* Selected issue: none
* Reason: Open Backlog issue exists outside accepted gate Execute list
* Blocker threshold: `Worker Done`, `Done`, `Canceled`, `Duplicate`

ISSUES.md is selector evidence only. Linear selection above is authoritative.

```text
         ISSUE_ID      Title                                                              Priority  State
[X]      ALP-2409      Planning: audit current Claude and Codex harness surfaces          Medium    Worker Done
[X]      ALP-2410      Planning: design harness boundary and migration plan               Medium    Worker Done
[X]      ALP-2411      Gate review: harness driver boundary execution readiness           Medium    Worker Done
[ ]      ALP-2412      Backlog                                                            Medium    Todo
[X]        ↳ ALP-2413  Characterize provider selection before harness movement            Medium    Worker Done
[X]        ↳ ALP-2414  Characterize shared launch supervision before driver extraction    Medium    Worker Done
[X]        ↳ ALP-2415  Introduce static harness driver contract and registry              Medium    Worker Done
[ ]        ↳ ALP-2416  Move Claude launch onto ManagedClient supervision                  Medium    Todo
[ ]        ↳ ALP-2417  Expose harness capabilities to desktop and web                     Medium    Todo
[ ]        ↳ ALP-2418  Post execution review: harness driver boundary                     Medium    Todo
[ ]        ↳ ALP-2419  Correct ALP-2415: commit harness registry and record verification  Medium    Backlog
```
