import re

p = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/WorldModelAgentLoopWiringTests.swift'
t = open(p).read()
t = t.replace('focusedElementID: nil', 'focusedElementID: ""')
t = t.replace('url: nil', 'url: nil as String?')
t = re.sub(r'PlanningState\(\s*id:\s*([^,]+),\s*app:\s*([^,]+),[^)]+\)', r'PlanningState(id: \1, clusterKey: StateClusterKey(rawValue: "c"), appID: \2, domain: nil, windowClass: nil, taskPhase: nil, focusedRole: nil, modalClass: nil, navigationClass: nil, controlContext: nil)', t)
open(p, 'w').write(t)
