import Foundation

@MainActor
public final class RuntimeContext {
    public let config: RuntimeConfig
    public let runtime: OracleRuntime
    public let planningGraphStore: PlanningGraphStore

    public init(
        config: RuntimeConfig = .live(),
        runtime: OracleRuntime = OracleRuntime(),
        planningGraphStore: PlanningGraphStore? = nil
    ) {
        self.config = config
        self.runtime = runtime
        self.planningGraphStore = planningGraphStore ?? PlanningGraphStore(engine: runtime.planningGraphEngine)
    }

    public var traceRecorder: TraceRecorder { runtime.traceRecorder }
    public var verifiedExecutor: VerifiedActionExecutor { runtime.executor }
    public var policyEngine: PolicyEngine { runtime.policy }
    public var graphStore: GraphStore { runtime.memory }
    public var stateMemoryIndex: StateMemoryIndex { runtime.stateMemory }
    public var searchController: SearchController { runtime.searchController }
    public var metricsRecorder: MetricsRecorder { runtime.metrics }

    public static func live(config: RuntimeConfig = .live()) -> RuntimeContext {
        let runtime = OracleRuntime()
        runtime.initialize()
        return RuntimeContext(config: config, runtime: runtime)
    }
}