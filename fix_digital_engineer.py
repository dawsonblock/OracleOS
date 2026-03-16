import re

p = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/DigitalEngineerLayerTests.swift'
t = open(p).read()
t = re.sub(r'(planner\.nextStep\([^\)]+memoryStore:[^\)]+)(\s*\))', r'\1,\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )', t)
open(p, 'w').write(t)
