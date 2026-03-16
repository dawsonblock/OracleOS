import re
with open("/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Planning/TaskGraphTests.swift", "r") as f:
    text = f.read()

text = re.sub(r'navigator\.expand\(from: nodeA\.id, in: graph, scorer: scorer\)', r'navigator.expand(from: nodeA.id, in: graph, scorer: scorer, allowedFamilies: [])', text)
text = re.sub(r'navigator\.bestNextEdge\(from: nodeA\.id, in: graph, scorer: scorer\)', r'navigator.bestNextEdge(from: nodeA.id, in: graph, scorer: scorer, allowedFamilies: [])', text)
text = re.sub(r'scorer: scorer,\n\s*goal: Goal\(description: "fix failing tests"\)', r'scorer: scorer, goal: Goal(description: "fix failing tests"), allowedFamilies: []', text)

with open("/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Planning/TaskGraphTests.swift", "w") as f:
    f.write(text)
