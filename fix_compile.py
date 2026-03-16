import re

def fix_file(path, replacements):
    with open(path, 'r') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(path, 'w') as f:
        f.write(content)

graph_aware_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/GraphAwareLoopTests.swift'
fix_file(graph_aware_path, [
    (
        'memoryStore: AppMemoryStore()\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])',
        'memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])'
    ),
    (
        'memoryStore: AppMemoryStore(), ,',
        'memoryStore: AppMemoryStore(),'
    ),
    (
        'memoryStore: AppMemoryStore()\n        )',
        'memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )'
    )
])

task_graph_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Planning/TaskGraphTests.swift'
fix_file(task_graph_path, [
    ('let ps = makePlanningState', '_ = makePlanningState'),
    ('#expect(resultNode != nil)\n            #expect(store.currentNode()?.id == resultNode?.id)', '#expect(store.currentNode()?.id == resultNode.id)'),
    ('let edge2 = store.addCandidateEdge', '_ = store.addCandidateEdge'),
    ('#expect(resultNode != nil)\n        #expect(store.currentNode()?.id == resultNode?.id)', '#expect(store.currentNode()?.id == resultNode.id)')
])

upgrade_phase_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Planning/UpgradePhaseTests.swift'
fix_file(upgrade_phase_path, [
    (
        '        let repo = RepositorySnapshot(\n            id: "test-repo",\n            workspaceRoot: "/tmp/test-repo",\n            branch: "main",\n            commitHash: "abc",\n            status: .clean,\n            changedFiles: []\n        )',
        '        let repo: RepositorySnapshot? = nil'
    ),
    (
        'let paths = navigator.expand(from: root.id, in: graph, scorer: scorer)',
        'let paths = navigator.expand(from: root.id, in: graph, scorer: scorer, goal: nil, allowedFamilies: [])'
    )
])

wf_param_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Workflows/WorkflowParameterizationTests.swift'
fix_file(wf_param_path, [
    (
        'parameterizer.parameterize(\n            goalPattern: "open app",\n            segments: singleSegment\n        )',
        'parameterizer.parameterize(\n            goalPattern: "open app",\n            traces: [singleSegment]\n        )'
    ),
    (
        'parameterizer.parameterize(\n            goalPattern: "edit file",\n            segments: segments\n        )',
        'parameterizer.parameterize(\n            goalPattern: "edit file",\n            traces: [segments]\n        )'
    ),
    (
        'TraceEvent(\n                sessionID: sessionID,\n                taskID: taskID,\n                stepID: "step-\\(i)",\n                toolName: "app_control",\n                actionName: "click",\n                agentKind: "os",\n                planningStateID: "state-1",\n                selectedElementLabel: "Button-\\(i)",\n                selectedElementID: "btn-\\(i)",\n                success: true,\n                verified: true,\n                workspaceRelativePath: path\n            )',
        'TraceEvent(\n                sessionID: sessionID,\n                taskID: taskID,\n                stepID: "step-\\(i)",\n                toolName: "app_control",\n                actionName: "click",\n                actionTarget: nil,\n                actionText: nil,\n                selectedElementID: "btn-\\(i)",\n                selectedElementLabel: "Button-\\(i)",\n                candidateScore: nil,\n                candidateReasons: nil,\n                ambiguityScore: nil,\n                preObservationHash: nil,\n                postObservationHash: nil,\n                planningStateID: "state-1",\n                beliefSnapshotID: nil,\n                postcondition: nil,\n                postconditionClass: nil,\n                actionContractID: nil,\n                executionMode: nil,\n                plannerSource: nil,\n                pathEdgeIDs: nil,\n                currentEdgeID: nil,\n                verified: true,\n                success: true,\n                failureClass: nil,\n                recoveryStrategy: nil,\n                recoverySource: nil,\n                recoveryTagged: nil,\n                surface: nil,\n                policyMode: nil,\n                protectedOperation: nil,\n                approvalRequestID: nil,\n                approvalOutcome: nil,\n                blockedByPolicy: nil,\n                appProfile: nil,\n                agentKind: "os",\n                domain: "os",\n                plannerFamily: nil,\n                workspaceRelativePath: path,\n                commandCategory: nil,\n                commandSummary: nil,\n                repositorySnapshotID: nil,\n                buildResultSummary: nil,\n                testResultSummary: nil,\n                patchID: nil,\n                projectMemoryRefs: nil,\n                experimentID: nil,\n                candidateID: nil,\n                sandboxPath: nil,\n                selectedCandidate: nil,\n                experimentOutcome: nil,\n                architectureFindings: nil,\n                refactorProposalID: nil,\n                knowledgeTier: nil,\n                elapsedMs: 100,\n                screenshotPath: nil,\n                notes: nil\n            )'
    )
])

digital_layer_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/DigitalEngineerLayerTests.swift'
fix_file(digital_layer_path, [
    (
        ',\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [],\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )',
        ',\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )'
    ),
    (
        'memoryStore: AppMemoryStore()\n        )',
        'memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )'
    )
])

code_intel_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/CodeIntelligenceTests.swift'
fix_file(code_intel_path, [
    ('memoryStore: memoryStore\n        )', 'memoryStore: memoryStore,\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )')
])

print("Fixes applied.")
