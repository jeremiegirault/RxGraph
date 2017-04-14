//: Playground - noun: a place where people can play

import UIKit

/*
 func make<Handler, Param>(_ helper: Handler.Type = Handler.self, _ param: Param.Type = Param.self, _ resolution : @escaping (Handler, Param) -> Void) -> (Param) -> (Handler) -> Void {
 return { (param: Param) -> (Handler) -> Void in
 return { (handler: Handler) -> Void in
 resolution(handler, param)
 }
 }
 }
 
 protocol P {
 func someFunc()
 func someOther(bool: Bool)
 }
 
 class PP: P {
 func someFunc() { print("someFunc") }
 func someOther(bool: Bool) { print("someOther\(bool)") }
 }
 
 enum X {
 static let y = make(P.self, Void.self) { proto, void in proto.someFunc() }
 }
 
 struct LateBind<T> {
 let bind: (T) -> Void
 
 static func make<Param>(_ resolution: @escaping (T, Param) -> Void) -> (Param) -> LateBind<T> {
 return { param in
 return LateBind { handler in
 resolution(handler, param)
 }
 }
 }
 }
 
 let pp = PP()
 
 let cb = LateBind<P>.make { p, _ in p.someFunc() }
 
 cb(pp)
 
 //let x = SomeProtocol.someMethod
 
 //let x: make(ManageNotificationActionHandler.showFriendsAbroad)
 
 //x()
 
 print("y")
 
 */

class X {
    func y(_ z: Int) {
    }
}

//struct Handler<Bound> {
//    func handle<Param>()
//}

enum Action {
    case .x
}

func handle()

struct Provider<Type> {
    let with: ((Type) -> Void) -> Void
}

extension Provider where Type: AnyObject {
    init(_ object: Type) {
        with = { [weak object] callback in
            guard let object = object else { return }
            callback(object)
        }
    }
}

class Test {
    func prnt() { print("hello") }
}

var y: Test? = Test()
let x = Provider(y!)
x.with { $0.prnt() }
y = nil
x.with { $0.prnt() }

print("that's all folks")

/*
 func weakBind<Bound, Param>(_ fn: @escaping (Bound) -> (Param) -> Void) -> (Param) -> (Bound) -> Void {
 return { param in
 return { bound in
 fn(bound)(param)
 }
 }
 }
 
 struct Action {
 static let x = LateBind(X.y)
 }
 
 Action.x.execute(3)
 */

