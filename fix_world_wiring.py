import re

p = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/WorldModelAgentLoopWiringTests.swift'
t = open(p).read()

# Fix Observation
t = t.replace('focusedElement:', 'focusedElementID:')

# Fix PlanningState
# We need id, clusterKey, appID, domain, windowClass, taskPhase, focusedRole, modalClass, navigationClass, controlContext
# Existing tests use PlanningState(id: ..., app: ..., windowTitle: ..., url: ...) 
# Wait, let's see what was exactly inside. They look like they were passing WorldState/Observation fields into PlanningState!
# Let me just check the exact lines.
