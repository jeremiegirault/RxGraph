//: [Previous](@previous)

import Swift
import Foundation
import CoreLocation
import PlaygroundSupport

//
// MARK: Disposable
//

protocol Disposable {
    var disposed: Bool { get }
    
    func dispose()
}

class AnyDisposable: Disposable {
    typealias Dispose = () -> Void
    
    private(set) var disposed: Bool = false
    private let _dispose: Dispose
    
    init(_ dispose: @escaping Dispose) {
        self._dispose = dispose
    }
    
    func dispose() {
        guard !disposed else { return }
        disposed = true
        _dispose()
    }
}

class CompositeDisposable: Disposable {
    
    private var disposables = [Disposable]()
    private(set) var disposed: Bool = false
    
    func dispose() {
        guard !disposed else { return }
        disposed = true
        disposables.forEach { $0.dispose() }
    }
    
    func add(_ disposable: Disposable) {
        disposables.append(disposable)
    }
}

//
// MARK: Event
//

struct Sink<T> {
    let subscription: Subscription
    let sink: (T) -> Void
    
    init(_ subscription: Subscription, _ sink: @escaping (T) -> Void) {
        self.subscription = subscription
        self.sink = sink
    }
}
typealias Generate<T> = (Sink<T>) -> Disposable

struct Weak<T: AnyObject> {
    private(set) weak var value: T?
    init(_ value: T) { self.value = value }
}

struct Observable<T> {
    
    let nodeInfo: NodeInstrumentation
    
    let generate: Generate<T>
    
    init(_ name: String, _ generate: @escaping Generate<T>) {
        let node = NodeInstrumentation(name)
        self.nodeInfo = node
        self.generate = { sink in
            return generate(Sink(sink.subscription) { val in
                node.onValue(subscription: sink.subscription, val)
                sink.sink(val)
            })
        }
    }
    
    func map<U>(_ transform: @escaping (T) -> U) -> Observable<U> {
        let a = Observable<U>("Map") { sink in
            return self.generate(Sink(sink.subscription) { val in
                sink.sink(transform(val))
            })
        }
        
        a.nodeInfo.addInput(nodeInfo)
        
        return a
    }
    
    func flatMap<U>(_ transform: @escaping (T) -> Observable<U>) -> Observable<U> {
        var addInput: (NodeInstrumentation) -> Void = { _ in }
        let a = Observable<U>("FlatMap") { sink in
            let composite = CompositeDisposable()
            let d1 = self.generate(Sink(sink.subscription) { val in
                let n = transform(val)
                addInput(n.nodeInfo)
                let d2 = n.generate(sink)
                composite.add(d2)
            })
            composite.add(d1)
            return composite
        }
        
        let ni = a.nodeInfo
        addInput = { [weak ni] in ni?.addInput($0) }
        a.nodeInfo.addInput(nodeInfo)
        return a
    }
    
    static func of(_ values: T...) -> Observable<T> {
        return Observable("Of") { sink in
            values.forEach { sink.sink($0) }
            return AnyDisposable {}
        }
    }
    
    func test(_ name: String) {
        generate(Sink(nodeInfo.onSubscribe()) { output in
            print("\(name) > \(output)")
        })
    }
}

func test() {
    let x = Observable<Int>.of(1,2,3).map { 3*$0 }
        .flatMap { (val: Int) -> Observable<String> in
        if val % 2 == 0 { return .of("even") }
        else { return .of("odd") }
    }
    x.test("abc")
    print("\(ProcessingGraph.shared.describe())")
}

test()

print("---")
print("\(ProcessingGraph.shared.describe())")
/*
typealias Sink<Output> = (Output) -> Void

infix operator =>: MultiplicationPrecedence

struct Operator<Input, Output> {
    
    
    typealias Execute = (Input, @escaping Sink<Output>) -> Disposable
    let execute: Execute
    
    init(_ execute: @escaping Execute) {
        self.execute = execute
    }
    
    func combine<Next>(_ other: Operator<Output, Next>) -> Operator<Input, Next> {
        return Operator<Input, Next> { input, sink in
            let disposable = CompositeDisposable()
            let d1 = self.execute(input) { result in
                let d2 = other.execute(result, sink)
                disposable.add(d2) // warning: each input adds a disposable here
            }
            disposable.add(d1)
            return disposable
        }
    }
    
    static func => <T, U, V>(lhs: Operator<T, U>, rhs: Operator<U, V>) -> Operator<T, V> {
        return lhs.combine(rhs)
    }
}

func map<T, U>(_ transform: @escaping (T) -> U) -> Operator<T, U> {
    return Operator { input, sink in
        sink(transform(input))
        return AnyDisposable {}
    }
}

func test<T, U>(_ name: String, _ op: Operator<T, U>, _ values: T...) {
    let sink: Sink<U> = { output in
        print("\(name) > \(output)")
    }
    values.forEach { op.execute($0, sink) }
}

let x: Operator<Int, Int> = map { 2*$0 }// => map { 2*$0 }

test("abc", x, 1, 2, 3)
    //=> map { 3*$0 } => display("second")


class Pipe<Input, Output> {
    
}
*/
/*

enum Event<T> {
    case next(T)
    case error(Error)
    case complete
}

protocol AnyOperator: class {}

class Operator<Input, Output>: AnyOperator {
    typealias Sink = (Output) -> Void
    typealias Apply = (Input, @escaping Sink) -> Void /* Disposable */
 
    let apply: Apply
    
    private init(_ apply: @escaping Apply) {
        self.apply = apply
    }
    
    
    static func map(_ transform: @escaping (Input) -> Output) -> Operator {
        return Operator { input, sink in sink(transform(input)) }
    }
    
    func connect<Next>(_ op: Operator<Output, Next>) -> Operator<Input, Next> {
        return Operator<Input, Next> { input, sink in
            self.apply(input) { output in
                op.apply(output, sink)
            }
        }
    }
    
    func test(_ input: Input) {
        apply(input) { print("> \($0)") }
    }
}

func test() {
    let double = Operator<Int, Int>.map { 2*$0 }
    let quad = double.connect(double)
    quad.test(1)
}

test()
*/
/*
extension Operator {
    
    static func map(_ transform: @escaping (Input) -> Output) -> Operator {
        return Operator { input, sink in sink(transform(input)) }
    }
    
    func combine<Next>(_ op: Operator<Output, Next>) -> Operator<Input, Next> {
        return Operator<Input, Next> { input, sink in
            self.apply(input) { output in
                op.apply(output, sink)
            }
        }
    }
}

func just<Output>(_ value: Output) -> Operator<Void, Output> {
    return Operator<Void, Output> { _, sink in sink(value) }
}

let x = just(1).combine(.map { 2 * $0 })

x.apply(()) { print("\($0)") }
//x.apply(()) { print("\($0)") }

class Block<Input, Output> {
    let impl: Operator<Input, Output>
    
    init(impl: Operator<Input, Output>) {
        self.impl = impl
    }
    
    func map<Next>(_ op: Operator<Input, Next>) -> Block<Input, Next> {
        return Block<Input, Next>(impl: op)
    }
}
*/

/*
struct Observer0<T> {
    var operators = [Operator]()
    
    init() {
    }
    
    mutating func addOperator(_ operator: Operator) {
        operators.append(`operator`)
    }
}*/


/*
//
// MARK: Semantics
//

protocol BehaviorType { }
protocol Hot: BehaviorType {}
protocol Errorable: BehaviorType {}
protocol Completable: BehaviorType {}
protocol Single: Completable {}

struct Mixed<L, R>: BehaviorType {
}

extension BehaviorType {
    static func combine<L: BehaviorType>(_ type: L.Type) -> Mixed<Self, L>.Type {
        return Mixed<Self, L>.self
    }
}

enum E: Errorable {}

let x = E.combine(E.self).combine(E.self).combine(E.self)
print(String(describing: x))


extension Observer {
    //func toErrorable() -> Observer<Behavior & Errorable, Value> {
    //}
}

//
// MARK: Observer
//

/// Can be fed with values
struct Observer<Behavior: BehaviorType, Value> {
    typealias Send = (Value) -> Void
    let send: Send
    
    init(_ send: @escaping Send) {
        self.send = send
    }
}

extension Observer where Behavior: Errorable {
    func sendError(_ error: Error) {}
}
extension Observer where Behavior: Completable {
    func sendComplete() {}
}

//
// MARK: Observable
//

/// Pipe provides stream of data
struct Observable<Behavior: BehaviorType, Event> {
    typealias Generate = (Observer<Behavior, Event>) -> Disposable
    
    let generate: Generate
    
    init(_ generate: @escaping Generate) {
        self.generate = generate
    }
}

extension Observable {
    static func of(_ events: Event...) -> Observable {
        return Observable { observer in
            events.forEach { evt in observer.send(evt) }
            return Disposable {}
        }
    }
}

extension Observable {
    func test(_ name: String) -> Disposable {
        return generate(Observer { event in
            print("\(name) > \(event)")
        })
    }
}

//
// MARK: Geocoding
//

enum DefaultBehavior: Errorable, Completable {
    typealias Dummy = Void
}

let geoObs = Observable<DefaultBehavior, [CLPlacemark]> { observer in
    let geocoder = CLGeocoder()
    geocoder.geocodeAddressString("12 rue janss") { result, error in
        if let error = error {
            observer.sendError(error)
        } else {
            observer.send(result ?? [])
            observer.sendComplete()
        }
    }
    
    return Disposable {
        geocoder.cancelGeocode()
    }
}
    
geoObs.test("toto")
geoObs.test("toto2")
*/

print("done")

PlaygroundPage.current.needsIndefiniteExecution = true
