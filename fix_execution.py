import re

with open('/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/ExecutionKernelBoundaryTests.swift', 'r') as f:
    content = f.read()

content = content.replace('let dict = result.data?["action_result"] as? [String: Any]\n        #expect(dict?["executed_through_executor"] as? Bool == true)',
'''let dataDict = result.data as? [String: Any]
        let actionResultDict = dataDict?["action_result"] as? [String: Any]
        let executed = actionResultDict?["executed_through_executor"] as? Bool ?? false
        #expect(executed == true)''')

with open('/Users/dawsonblock/Downloads/THE_ORACLE/Oracle-OS-main-4/Tests/OracleOSTests/Core/ExecutionKernelBoundaryTests.swift', 'w') as f:
    f.write(content)
