import re
import sys

p = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/GraphAwareLoopTests.swift'
t = open(p).read()
t = t.replace('selectedStrategy: SelectedStrategy(kind: .general, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])', '')
t = t.replace(', memoryStore: AppMemoryStore(), ', ', memoryStore: AppMemoryStore() ')
t = t.replace('memoryStore: AppMemoryStore(), \n', 'memoryStore: AppMemoryStore()\n')
t = t.replace('memoryStore: AppMemoryStore(),\n', 'memoryStore: AppMemoryStore()\n')
t = t.replace('memoryStore: AppMemoryStore() ,', 'memoryStore: AppMemoryStore()')
t = t.replace('memoryStore: AppMemoryStore() \n', 'memoryStore: AppMemoryStore()\n')
t = re.sub(r'(planner\.nextStep\([^)]+memoryStore:[^\n]+)([\n\s]*)\)', r'\1,\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )', t)
t = re.sub(r'(planner\.nextStep\([^\)]+graphStore:[^\)]+)(\s*\))', r'\1,\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )', t)

# remove duplicates if re.sub matched twice
t = t.replace('selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: []),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])', 'selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])')

open(p, 'w').write(t)
