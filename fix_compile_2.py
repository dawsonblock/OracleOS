import re
import sys

def replace_in_file(path, old_str, new_str, use_regex=False):
    with open(path, 'r') as f:
        content = f.read()

    if use_regex:
        content = re.sub(old_str, new_str, content)
    else:
        content = content.replace(old_str, new_str)
        
    with open(path, 'w') as f:
        f.write(content)

graph_aware_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/GraphAwareLoopTests.swift'
replace_in_file(graph_aware_path, 
    'recoveryEngine: RecoveryEngine(),\n            memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])',
    'recoveryEngine: RecoveryEngine(),\n            memoryStore: AppMemoryStore()'
)

digital_layer_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/DigitalEngineerLayerTests.swift'
replace_in_file(digital_layer_path,
    'memoryStore: AppMemoryStore(),\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])',
    'memoryStore: AppMemoryStore()'
)

# And those double parens
replace_in_file(digital_layer_path,
    ',\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )\n        )',
    ',\n            selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])\n        )'
)

# wait I already replaced some things in digital_layer_path before, let me just fix the exact strings.
# The errors were:
# DigitalEngineerLayerTests.swift:367:9: error: expected expression
# 365 |             selectedStrategy: SelectedStrategy(kind: .directExecution, confidence: 1.0, rationale: "", allowedOperatorFamilies: [])
# 366 |         )
# 367 |         )
# We can fix `\)\n        \)` to `\)` globally in that file.

with open(digital_layer_path, 'r') as f:
    d_content = f.read()
d_content = re.sub(r'selectedStrategy:(.*?)\n\s*\)\n\s*\)', r'selectedStrategy:\1\n        )', d_content)
with open(digital_layer_path, 'w') as f:
    f.write(d_content)


upgrade_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Planning/UpgradePhaseTests.swift'
replace_in_file(upgrade_path,
    'goal: "", allowedFamilies: []',
    'goal: Goal(description: ""), allowedFamilies: []'
)

mem_tests_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Strategy/StrategyScopedMemoryTests.swift'
replace_in_file(mem_tests_path, 'bias.total >=', 'bias.totalBias >=')
replace_in_file(mem_tests_path, 'bias.total <=', 'bias.totalBias <=')

plan_test_path = '/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Strategy/StrategyScopedPlanTests.swift'
old_mem = """    private func makeReasoningState() -> ReasoningPlanningState {
        ReasoningPlanningState(
            agentKind: .code,
            repoOpen: true,
            modalPresent: false,
            patchApplied: false,
            testsObserved: false
        )
    }"""
new_mem = """    private func makeReasoningState() -> ReasoningPlanningState {
        let taskContext = TaskContext(goal: Goal(description: "test"), agentKind: .code)
        let worldState = WorldState(
            observationHash: "",
            planningState: PlanningState(id: PlanningStateID(rawValue: ""), clusterKey: StateClusterKey(rawValue: ""), appID: "", domain: nil, windowClass: nil, taskPhase: nil, focusedRole: nil, modalClass: nil, navigationClass: nil, controlContext: nil),
            observation: Observation(app: "", windowTitle: "", focusedElementID: "", elements: []),
            repositorySnapshot: nil
        )
        var state = ReasoningPlanningState(taskContext: taskContext, worldState: worldState, memoryInfluence: MemoryInfluence())
        state.repoOpen = true
        state.modalPresent = false
        state.patchApplied = false
        state.testsObserved = false
        return state
    }"""
replace_in_file(plan_test_path, old_mem, new_mem)

print("Fixes round 2 applied.")
