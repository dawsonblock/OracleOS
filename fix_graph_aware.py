import re
with open('/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/GraphAwareLoopTests.swift', 'r') as f:
    text = f.read()
text = text.replace('memoryStore: AppMemoryStore(), selectedStrategy: SelectedStrategy(kind: .general, confidence: 1.0, rationale: \, allowedOperatorFamilies: [])', 'memoryStore: AppMemoryStore()')
text = text.replace('memoryStore: AppMemoryStore(), selectedStrategy: SelectedStrategy(kind: .general, confidence: 1.0, rationale: \, allowedOperatorFamilies: []),', 'memoryStore: AppMemoryStore(),')
text = re.sub(r'(planner\.nextStep\(\s*worldState:[^,]+,\s*graphStore:[^,]+,\s*memoryStore:[^\)]+)(\s*\))', r'\1, selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\2', text)
