import os
import re

tests_dir = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests'
sources_dir = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Sources/OracleOSTests'

# 1. WorldModelAgentLoopWiringTests
f1 = os.path.join(tests_dir, 'Core', 'WorldModelAgentLoopWiringTests.swift')
with open(f1, 'r') as f:
    text = f.read()

text = text.replace('url: "",\n            elements: [],\n            focusedElementID: ""', 'focusedElementID: "",\n            elements: []')
text = text.replace('url: "",\n                elements: [],\n                focusedElementID: ""', 'focusedElementID: "",\n                elements: []')
text = text.replace('url: "", elements: [], focusedElementID: ""', 'focusedElementID: "", elements: []')

# Fix the trailing ", on PlanningState
text = text.replace('controlContext: nil)",', 'controlContext: nil)')

with open(f1, 'w') as f:
    f.write(text)

# 2. GraphAwareLoopTests - multiple strategy fixes
f2 = os.path.join(tests_dir, 'Core', 'GraphAwareLoopTests.swift')
with open(f2, 'r') as f:
    text2 = f.read()

text2 = text2.replace('memoryStore: AppMemoryStore()\n            selectedStrategy', 'memoryStore: AppMemoryStore(),\n            selectedStrategy')
text2 = text2.replace('memoryStore: AppMemoryStore(), ,\n            worldState:', 'memoryStore: AppMemoryStore(),\n            worldState:')
text2 = text2.replace('graphStore: GraphStore(databaseURL: makeTempGraphURL()),\n            memoryStore: AppMemoryStore()\n        )', 'graphStore: GraphStore(databaseURL: makeTempGraphURL()),\n            memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )')

with open(f2, 'w') as f:
    f.write(text2)


# 3. TaskGraphTests.swift
f3 = os.path.join(tests_dir, 'Planning', 'TaskGraphTests.swift')
with open(f3, 'r') as f:
    text3 = f.read()

text3 = text3.replace('let ps = makePlanningState', '_ = makePlanningState')
text3 = text3.replace('let edge2 = store.addCandidateEdge', '_ = store.addCandidateEdge')
text3 = text3.replace('resultNode != nil', 'resultNode != nil /* removed constraint always true */')
text3 = text3.replace('store.currentNode()?.id == resultNode?.id', 'store.currentNode()?.id == resultNode.id')
with open(f3, 'w') as f:
    f.write(text3)

# 4. UpgradePhaseTests.swift
f4 = os.path.join(tests_dir, 'Planning', 'UpgradePhaseTests.swift')
with open(f4, 'r') as f:
    text4 = f.read()

text4 = text4.replace('let repo = RepositorySnapshot(\n            id: "test-repo",\n            workspaceRoot: "/tmp/test-repo",\n            branch: "main",\n            commitHash: "xyz",\n            files: [],\n            untrackedChanges: []\n        )', 'let repo = makeRepoSnapshot()')
text4 = text4.replace('let paths = navigator.expand(from: root.id, in: graph, scorer: scorer)', 'let paths = navigator.expand(from: root.id, in: graph, scorer: scorer, goal: "", allowedFamilies: [])')

with open(f4, 'w') as f:
    f.write(text4)


# 5. WorkflowParameterizationTests.swift
f5 = os.path.join(tests_dir, 'Workflows', 'WorkflowParameterizationTests.swift')
with open(f5, 'r') as f:
    text5 = f.read()

text5 = text5.replace('goalPattern: "open app",\n            segments: singleSegment', 'goalPattern: "open app",\n            traces: [singleSegment]')
text5 = text5.replace('goalPattern: "edit file",\n            segments: segments', 'goalPattern: "edit file",\n            traces: [segments]')
text5 = text5.replace('''TraceEvent(
                sessionID: sessionID,
                taskID: taskID,
                stepID: "step-\(i)",
                toolName: "test_tool",
                actionName: "test_action",
                agentKind: .os,
                planningStateID: PlanningStateID(rawValue: "ps-\(i)"),
                selectedElementLabel: nil,
                selectedElementID: nil,
                success: true,
                verified: true,
                workspaceRelativePath: path
            )''', '''TraceEvent(
                sessionID: sessionID,
                taskID: taskID,
                stepID: "step-\(i)",
                toolName: "test_tool",
                actionName: "test_action",
                actionTarget: "",
                actionText: nil,
                selectedElementID: nil,
                selectedElementLabel: nil,
                candidateScore: nil,
                candidateReasons: nil,
                ambiguityScore: nil,
                preObservationHash: "",
                postObservationHash: nil,
                planningStateID: PlanningStateID(rawValue: "ps-\(i)"),
                beliefSnapshotID: nil,
                postcondition: nil,
                postconditionClass: nil,
                actionContractID: nil,
                executionMode: .auto,
                plannerSource: "test",
                pathEdgeIDs: [],
                currentEdgeID: nil,
                verified: true,
                success: true,
                failureClass: nil,
                recoveryStrategy: nil,
                recoverySource: nil,
                recoveryTagged: nil,
                surface: .desktop,
                policyMode: .standard,
                protectedOperation: false,
                approvalRequestID: nil,
                approvalOutcome: nil,
                blockedByPolicy: false,
                appProfile: nil,
                agentKind: .os,
                domain: nil,
                plannerFamily: "test",
                workspaceRelativePath: path,
                commandCategory: nil,
                commandSummary: nil,
                repositorySnapshotID: nil,
                buildResultSummary: nil,
                testResultSummary: nil,
                patchID: nil,
                projectMemoryRefs: [],
                experimentID: nil,
                candidateID: nil,
                sandboxPath: nil,
                selectedCandidate: nil,
                experimentOutcome: nil,
                architectureFindings: nil,
                refactorProposalID: nil,
                knowledgeTier: nil,
                elapsedMs: 100,
                screenshotPath: nil,
                notes: nil
            )''')
with open(f5, 'w') as f:
    f.write(text5)


# 6. DigitalEngineerLayerTests.swift
f6 = os.path.join(tests_dir, 'Core', 'DigitalEngineerLayerTests.swift')
with open(f6, 'r') as f:
    text6 = f.read()

# Remove duplicate selectedStrategy
text6 = text6.replace('selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [],\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])', 'selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])')

text6 = text6.replace('graphStore: GraphStore(databaseURL: makeTempGraphURL()),\n            memoryStore: AppMemoryStore()\n        )', 'graphStore: GraphStore(databaseURL: makeTempGraphURL()),\n            memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )')
with open(f6, 'w') as f:
    f.write(text6)


# 7. CodeIntelligenceTests.swift
f7 = os.path.join(tests_dir, 'Core', 'CodeIntelligenceTests.swift')
with open(f7, 'r') as f:
    text7 = f.read()
text7 = text7.replace('worldState: worldState,\n            graphStore: graphStore,\n            memoryStore: memoryStore\n        )', 'worldState: worldState,\n            graphStore: graphStore,\n            memoryStore: memoryStore,\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )')
with open(f7, 'w') as f:
    f.write(text7)

print("Fixes applied.")
