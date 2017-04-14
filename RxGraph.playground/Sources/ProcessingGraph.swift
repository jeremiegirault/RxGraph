import Foundation
import Swift

//
// MARK: Defines a unique node, copies reference the same node
//

struct Node {
    let name: String
    let uuid: UUID
    
    init(_ name: String) {
        self.name = name
        uuid = UUID()
    }
}

extension Node: CustomStringConvertible {
    var description: String {
        return "\(name)<\(uuid.uuidString)>"
    }
}

extension Node: Hashable {
    var hashValue: Int { return uuid.hashValue }
    
    static func ==(lhs: Node, rhs: Node) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

extension Node {
    var toJson: Any {
        return [
            "name": name,
            "uuid": uuid.uuidString
        ]
    }
}

//
// MARK: Edge
//

struct Edge {
    let from: Node
    let to: Node
}

extension Edge: CustomStringConvertible {
    var description: String {
        return "\(from) -> \(to)"
    }
}

extension Edge: Hashable {
    var hashValue: Int { return from.hashValue ^ to.hashValue }
    static func ==(lhs: Edge, rhs: Edge) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }
}

extension Edge {
    var toJson: Any {
        return [
            "from": from.toJson,
            "to": to.toJson,
        ]
    }
}

//
// MARK: NodeInstrumentation
//

public struct Subscription {
    let uuid = UUID()
}

extension Subscription: CustomStringConvertible {
    public var description: String {
        return "Subscription<\(uuid.uuidString)>"
    }
}

extension Subscription: Hashable {
    public var hashValue: Int { return uuid.hashValue }
    
    public static func ==(lhs: Subscription, rhs: Subscription) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

extension Subscription {
    var toJson: Any {
        return [
            "uuid": uuid.uuidString
        ]
    }
}

public final class NodeInstrumentation {
    let node: Node
    
    public init(_ name: String) {
        node = Node(name)
        ProcessingGraph.shared.add([ node ])
    }
    
    deinit {
        ProcessingGraph.shared.remove([ node ])
    }
    
    public func addInput(_ nodes: NodeInstrumentation...) {
        ProcessingGraph.shared.addInput(for: node, from: nodes.map { $0.node })
    }
    
    public func onSubscribe() -> Subscription {
        let subscription = Subscription()
        ProcessingGraph.shared.onSubscription(subscription, for: node)
        return subscription
    }
    
    public func onValue(subscription: Subscription, _ value: Any) {
        ProcessingGraph.shared.onValue(value, in: node, instance: subscription)
    }
}

extension NodeInstrumentation: CustomStringConvertible {
    public var description: String {
        return "\(node)"
    }
}

public final class TraversalInfo: CustomStringConvertible {
    var nodes = Set<Node>()
    var edges = Set<Edge>()
    
    public var description: String {
        let nodesDesc = nodes.isEmpty ? "{}" : "{\n\(nodes.map { "\t\($0)" }.joined(separator: "\n"))\n}"
        let edgesDesc = edges.isEmpty ? "{}" : "{\n\(edges.map { "\t\($0)" }.joined(separator: "\n"))\n}"
        return "Nodes: \(nodesDesc)\nEdges: \(edgesDesc)"
    }
}

enum Event: CustomStringConvertible {
    case subscription(Node, Subscription)
    case value(Node, Subscription, Any)
    case nodesAdded(Set<Node>)
    case nodesRemoved(Set<Node>)
    case edgesAdded(Set<Edge>)
    //case edgesRemoved(Set<Edge>)
    
    var description: String {
        switch self {
        case .subscription(let node, let subscription): return ".subscription(\(node), \(subscription))"
        case .value(let node, let subscription, let val): return ".valuePropagating(\(node), \(subscription), \(val))"
        case .nodesAdded(let nodes): return ".nodesAdded { \(nodes.map { "\($0)" }.joined(separator: ",")) }"
        case .nodesRemoved(let nodes): return ".nodesRemoved { \(nodes.map { "\($0)" }.joined(separator: ",")) }"
        case .edgesAdded(let edges): return ".edgesAdded { \(edges.map { "\($0)" }.joined(separator: ",")) }"
        //case .edgesRemoved(let edges): return ".edgesRemoved { \(edges.map { "\($0)" }.joined(separator: ",")) }"
        }
    }
    
    var toJson: Any {
        switch self {
        case .subscription(let node, let subscription):
            return [
                "subscription": [
                    "node": node.toJson,
                    "subscription": subscription.toJson
                ]
            ]
        case .value(let node, let subscription, let val):
            return [
                "value": [
                    "node": node.toJson,
                    "subscription": subscription.toJson,
                    "value": "\(val)"
                ]
            ]
        case .nodesAdded(let nodes):
            return [
                "nodes-added": [
                    "nodes": nodes.map { $0.toJson }
                ]
            ]
        case .nodesRemoved(let nodes):
            return [
                "nodes-removed": [
                    "nodes": nodes.map { $0.toJson }
                ]
            ]
        case .edgesAdded(let edges):
            return [
                "edges-added": [
                    "edges": edges.map { $0.toJson }
                ]
            ]
        }
    }
}

public final class ProcessingGraph {
    public static let shared = ProcessingGraph()
    
    private final class Ref<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }
    
    private typealias AdjacencyList = [Node: Ref<Set<Node>>]
    
    // adjacency list for inputs / outputs
    private var inputs = AdjacencyList()
    private var outputs = AdjacencyList()
    
    // node list
    private var nodes = Set<Node>()
    
    private var history = [Event]() {
        didSet { historyDidChange() }
    }
    
    private func historyDidChange() {
        let jsonData = try! JSONSerialization.data(withJSONObject: history.last!.toJson)
        print(String(data: jsonData, encoding: .utf8)!)
    }
    
    //
    // MARK: Value
    //
    
    func onSubscription(_ subscription: Subscription, for node: Node) {
        history.append(.subscription(node, subscription))
    }
    
    func onValue(_ value: Any, in node: Node, instance subscription: Subscription) {
        history.append(.value(node, subscription, value))
    }
    
    //
    // MARK: Add/Remove node
    //
    
    func add(_ nodes: Set<Node>) {
        // #if DEBUG
        if !self.nodes.isDisjoint(with: nodes) {
            print("Warning add already registered nodes")
        }
        // #endif
        
        self.nodes.formUnion(nodes)
        
        history.append(.nodesAdded(nodes))
    }
    
    func remove(_ nodes: Set<Node>) {
        // #if DEBUG
        if !self.nodes.isSuperset(of: nodes) {
            print("Warning: removing non-registered nodes: \(nodes) / \(self.nodes) !")
        }
        // #endif
        
        nodes.forEach(clearAdjacencyInfo)
        self.nodes.subtract(nodes)
        
        history.append(.nodesRemoved(nodes))
    }
    
    
    func clearAdjacencyInfo(for node: Node) {
        //var removedEdges = Set<Edge>()
        
        inputs[node]?.value.forEach { input in // remove this node from output of each of its input
            //removedEdges.insert(Edge(from: input, to: node))
            outputs[input]?.value.remove(node)
        }
        outputs[node]?.value.forEach { output in // remove this node from input of each of its output
            //removedEdges.insert(Edge(from: node, to: output))
            inputs[output]?.value.remove(node)
        }
        
        // remove adjacency info for this node
        inputs.removeValue(forKey: node)
        outputs.removeValue(forKey: node)
        
        //history.append(.edgesRemoved(removedEdges))
    }
    
    //
    // MARK: Add input / outputs
    //
    
    private func addAdjacency(list: inout AdjacencyList, from: Node, to: Set<Node>) {
        if let ref = list[from] {
            ref.value.formUnion(to)
        } else {
            list[from] = Ref(to)
        }
    }
    
    func addInput(for node: Node, from inputs: [Node]) {
        addAdjacency(list: &self.inputs, from: node, to: Set(inputs))
        inputs.forEach { addAdjacency(list: &self.outputs, from: $0, to: [ node ]) }
        
        let addedEdges = Set(inputs.map { Edge(from: $0, to: node) })
        history.append(.edgesAdded(Set(addedEdges)))
    }
    
    //
    // MARK: Traverse and describe
    //
    
    
    private func traverse(_ traversalInfo: TraversalInfo, _ node: Node) {
        guard !traversalInfo.nodes.contains(node) else { return }
        
        traversalInfo.nodes.insert(node)
        inputs[node]?.value.forEach { input in
            traversalInfo.edges.insert(Edge(from: input, to: node))
            traverse(traversalInfo, input)
        }
        
        outputs[node]?.value.forEach { output in
            traversalInfo.edges.insert(Edge(from: node, to: output))
            traverse(traversalInfo, output)
        }
    }
    
    public func describe() -> TraversalInfo {
        let traversalInfo = TraversalInfo()
        nodes.forEach { traverse(traversalInfo, $0) }
        return traversalInfo
    }
    
    private init() {}
}
