# Cluster

This document describes the cluster and distributed coordination layer
of Oracle OS.

> **Status**: The cluster subsystem is scaffolded but not yet active in
> production. It is intended for Phase 11 (High Availability).

## Components

### ClusterCoordinator

`Sources/OracleOS/Core/Cluster/ClusterCoordinator.swift`

Manages cluster membership and health. Handles role transitions between
`leader`, `follower`, and `candidate` states. Logs transitions to the
`DurableEventStore`.

### DistributedLockManager

`Sources/OracleOS/Core/Cluster/DistributedLockManager.swift`

Provides distributed locking for coordinating exclusive operations across
cluster nodes.

### LogReplicator

`Sources/OracleOS/Core/Cluster/LogReplicator.swift`

Replicates the event log (WAL) across cluster nodes for durability
and consistency.

## Cluster Roles

| Role | Description |
|------|-------------|
| `leader` | Owns the execution loop and writes to the event store |
| `follower` | Receives replicated events; can serve read queries |
| `candidate` | Participating in leader election |

## Architecture

The cluster layer sits below the runtime and is transparent to the
execution spine:

```
AgentLoop (unchanged)
  → VerifiedActionExecutor (unchanged)
  → DurableEventStore
  → LogReplicator (replicates WAL to followers)
  → ClusterCoordinator (manages role transitions)
```

The runtime executes identically whether clustered or standalone.
Clustering only affects event durability and availability — not
execution semantics.

## Future Work

- Raft-based consensus for leader election
- Automatic failover from leader to follower
- Read replicas for observability queries
- `CommitCoordinator` integration with high-consistency storage
