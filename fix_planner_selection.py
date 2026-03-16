import re

p = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Planning/PlannerPlanSelectionTests.swift'
t = open(p).read()
t = t.replace(', selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])', '')
open(p, 'w').write(t)
