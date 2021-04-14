// RUN: %target-typecheck-verify-swift -enable-experimental-concurrency -warn-concurrency
// REQUIRES: concurrency


// some utilities
func thrower() throws {}
func asyncer() async {}

func rethrower(_ f : @autoclosure () throws -> Any) rethrows -> Any {
  return try f()
}

func asAutoclosure(_ f : @autoclosure () -> Any) -> Any { return f() }

// not a concurrency-safe type
class Box {
  var counter : Int = 0
}

actor BankAccount {

  private var curBalance : Int

  private var accountHolder : String = "unknown"

  // expected-note@+1 {{mutation of this property is only permitted within the actor}}
  var owner : String {
    get { accountHolder }
    set { accountHolder = newValue }
  }

  init(initialDeposit : Int) {
    curBalance = initialDeposit
  }

  // NOTE: this func is accessed through both async and sync calls.
  // expected-note@+1 {{calls to instance method 'balance()' from outside of its actor context are implicitly asynchronous}}
  func balance() -> Int { return curBalance }

  // expected-note@+1 2{{calls to instance method 'deposit' from outside of its actor context are implicitly asynchronous}}
  func deposit(_ amount : Int) -> Int {
    guard amount >= 0 else { return 0 }

    curBalance = curBalance + amount
    return curBalance
  }

  func canWithdraw(_ amount : Int) -> Bool { 
    // call 'balance' from sync through self
    return self.balance() >= amount
  }

  func testSelfBalance() async {
    _ = await balance() // expected-warning {{no 'async' operations occur within 'await' expression}}
  }

  // returns the amount actually withdrawn
  func withdraw(_ amount : Int) -> Int {
    guard canWithdraw(amount) else { return 0 }

    curBalance = curBalance - amount
    return amount
  }

  // returns the balance of this account following the transfer
  func transferAll(from : BankAccount) async -> Int {
    // call sync methods on another actor
    let amountTaken = await from.withdraw(from.balance())
    return deposit(amountTaken)
  }

  func greaterThan(other : BankAccount) async -> Bool {
    return await balance() > other.balance()
  }

  func testTransactions() {
    _ = deposit(withdraw(deposit(withdraw(balance()))))
  }

  func testThrowing() throws {}

  var effPropA : Box {
    get async {
      await asyncer()
      return Box()
    }
  }

  var effPropT : Box {
    get throws {
      try thrower()
      return Box()
    }
  }

  var effPropAT : Int {
    get async throws {
      await asyncer()
      try thrower()
      return 0
    }
  }

  // expected-note@+1 2 {{add 'async' to function 'effPropertiesFromInsideActorInstance()' to make it asynchronous}}
  func effPropertiesFromInsideActorInstance() throws {
    // expected-error@+1{{'async' property access in a function that does not support concurrency}}
    _ = effPropA

    // expected-note@+4{{did you mean to handle error as optional value?}}
    // expected-note@+3{{did you mean to use 'try'?}}
    // expected-note@+2{{did you mean to disable error propagation?}}
    // expected-error@+1{{property access can throw but is not marked with 'try'}}
    _ = effPropT

    _ = try effPropT

    // expected-note@+6 {{did you mean to handle error as optional value?}}
    // expected-note@+5 {{did you mean to use 'try'?}}
    // expected-note@+4 {{did you mean to disable error propagation?}}
    // expected-error@+3 {{property access can throw but is not marked with 'try'}}
    // expected-note@+2 {{call is to 'rethrows' function, but argument function can throw}}
    // expected-error@+1 {{call can throw but is not marked with 'try'}}
    _ = rethrower(effPropT)

    // expected-note@+2 {{call is to 'rethrows' function, but argument function can throw}}
    // expected-error@+1 {{call can throw but is not marked with 'try'}}
    _ = rethrower(try effPropT)

    _ = try rethrower(effPropT)
    _ = try rethrower(thrower())

    _ = try rethrower(try effPropT)
    _ = try rethrower(try thrower())

    _ = rethrower(effPropA) // expected-error{{'async' property access in an autoclosure that does not support concurrency}}

    _ = asAutoclosure(effPropT) // expected-error{{property access can throw, but it is not marked with 'try' and it is executed in a non-throwing autoclosure}}

    // expected-note@+5{{did you mean to handle error as optional value?}}
    // expected-note@+4{{did you mean to use 'try'?}}
    // expected-note@+3{{did you mean to disable error propagation?}}
    // expected-error@+2{{property access can throw but is not marked with 'try'}}
    // expected-error@+1{{'async' property access in a function that does not support concurrency}}
    _ = effPropAT
  }

} // end actor

func someAsyncFunc() async {
  let deposit1 = 120, deposit2 = 45
  let a = BankAccount(initialDeposit: 0)
  let b = BankAccount(initialDeposit: deposit2)

  let _ = await a.deposit(deposit1)
  let afterXfer = await a.transferAll(from: b)
  let reportedBal = await a.balance()
  
  // check on account A
  guard afterXfer == (deposit1 + deposit2) && afterXfer == reportedBal else {
    print("BUG 1!")
    return
  }

  // check on account B
  guard await b.balance() == 0 else {
    print("BUG 2!")
    return
  }

  _ = await a.deposit(b.withdraw(a.deposit(b.withdraw(b.balance()))))

  a.testSelfBalance() // expected-error {{call is 'async' but is not marked with 'await'}}

  await a.testThrowing() // expected-error {{call can throw, but it is not marked with 'try' and the error is not handled}}

  ////////////
  // effectful properties from outside the actor instance

  // expected-warning@+2 {{cannot use property 'effPropA' with a non-sendable type 'Box' across actors}}
  // expected-error@+1{{property access is 'async' but is not marked with 'await'}} {{7-7=await }}
  _ = a.effPropA

  // expected-warning@+3 {{cannot use property 'effPropT' with a non-sendable type 'Box' across actors}}
  // expected-error@+2{{property access can throw, but it is not marked with 'try' and the error is not handled}}
  // expected-error@+1{{property access is 'async' but is not marked with 'await'}} {{7-7=await }}
  _ = a.effPropT

  // expected-error@+2{{property access can throw, but it is not marked with 'try' and the error is not handled}}
    // expected-error@+1{{property access is 'async' but is not marked with 'await'}} {{7-7=await }}
  _ = a.effPropAT

  // (mostly) corrected ones
  _ = await a.effPropA  // expected-warning {{cannot use property 'effPropA' with a non-sendable type 'Box' across actors}}
  _ = try! await a.effPropT // expected-warning {{cannot use property 'effPropT' with a non-sendable type 'Box' across actors}}
  _ = try? await a.effPropAT

  print("ok!")
}


//////////////////
// check for appropriate error messages
//////////////////

extension BankAccount {
  func totalBalance(including other: BankAccount) async -> Int {
    return balance() 
          + other.balance()  // expected-error{{call is 'async' but is not marked with 'await'}}
  }

  func breakAccounts(other: BankAccount) async {
    _ = other.deposit(  // expected-error{{call is 'async' but is not marked with 'await'}}
          other.withdraw( // expected-error{{call is 'async' but is not marked with 'await'}}
            self.deposit(
              other.withdraw( // expected-error{{call is 'async' but is not marked with 'await'}}
                other.balance())))) // expected-error{{call is 'async' but is not marked with 'await'}}
  }
}

func anotherAsyncFunc() async {
  let a = BankAccount(initialDeposit: 34)
  let b = BankAccount(initialDeposit: 35)

  _ = a.deposit(1)  // expected-error{{call is 'async' but is not marked with 'await'}}
  _ = b.balance()   // expected-error{{call is 'async' but is not marked with 'await'}}
  
  _ = b.balance // expected-error {{actor-isolated instance method 'balance()' can only be referenced from inside the actor}}

  a.owner = "cat" // expected-error{{actor-isolated property 'owner' can only be mutated from inside the actor}}
  _ = b.owner // expected-error{{property access is 'async' but is not marked with 'await'}}
  _ = await b.owner == "cat"


}

func regularFunc() {
  let a = BankAccount(initialDeposit: 34)

  _ = a.deposit //expected-error{{actor-isolated instance method 'deposit' can only be referenced from inside the actor}}

  _ = a.deposit(1)  // expected-error{{actor-isolated instance method 'deposit' can only be referenced from inside the actor}}
}


actor TestActor {}

@globalActor
struct BananaActor {
  static var shared: TestActor { TestActor() }
}

@globalActor
struct OrangeActor {
  static var shared: TestActor { TestActor() }
}

func blender(_ peeler : () -> Void) {
  peeler()
}

// expected-note@+2 {{var declared here}}
// expected-note@+1 2 {{mutation of this var is only permitted within the actor}}
@BananaActor var dollarsInBananaStand : Int = 250000

@BananaActor func wisk(_ something : Any) { } // expected-note 5 {{calls to global function 'wisk' from outside of its actor context are implicitly asynchronous}}

@BananaActor func peelBanana() { } // expected-note 2 {{calls to global function 'peelBanana()' from outside of its actor context are implicitly asynchronous}}

@BananaActor func takeInout(_ x : inout Int) {}

@OrangeActor func makeSmoothie() async {
  var money = await dollarsInBananaStand
  money -= 1200

  dollarsInBananaStand = money // expected-error{{var 'dollarsInBananaStand' isolated to global actor 'BananaActor' can not be mutated from different global actor 'OrangeActor'}}

  // FIXME: these two errors seem a bit redundant.
  // expected-error@+2 {{actor-isolated var 'dollarsInBananaStand' cannot be passed 'inout' to implicitly 'async' function call}}
  // expected-error@+1 {{var 'dollarsInBananaStand' isolated to global actor 'BananaActor' can not be used 'inout' from different global actor 'OrangeActor'}}
  await takeInout(&dollarsInBananaStand)

  _ = wisk // expected-error {{global function 'wisk' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}


  await wisk({})
  // expected-warning@-1{{cannot pass argument of non-sendable type 'Any' across actors}}
  await wisk(1)
  // expected-warning@-1{{cannot pass argument of non-sendable type 'Any' across actors}}
  await (peelBanana)()
  await (((((peelBanana)))))()
  await (((wisk)))((wisk)((wisk)(1)))
  // expected-warning@-1 3{{cannot pass argument of non-sendable type 'Any' across actors}}

  blender((peelBanana)) // expected-error {{global function 'peelBanana()' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}
  await wisk(peelBanana) // expected-error {{global function 'peelBanana()' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}
  // expected-warning@-1{{cannot pass argument of non-sendable type 'Any' across actors}}

  await wisk(wisk)  // expected-error {{global function 'wisk' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}
  // expected-warning@-1{{cannot pass argument of non-sendable type 'Any' across actors}}
  await (((wisk)))(((wisk))) // expected-error {{global function 'wisk' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}
  // expected-warning@-1{{cannot pass argument of non-sendable type 'Any' across actors}}

  // expected-warning@+2 {{no 'async' operations occur within 'await' expression}}
  // expected-error@+1 {{global function 'wisk' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}
  await {wisk}()(1)

  // expected-warning@+2 {{no 'async' operations occur within 'await' expression}}
  // expected-error@+1 {{global function 'wisk' isolated to global actor 'BananaActor' can not be referenced from different global actor 'OrangeActor'}}
  await (true ? wisk : {n in return})(1)
}

actor Chain {
  var next : Chain?
}

func walkChain(chain : Chain) async {
  _ = chain.next?.next?.next?.next // expected-error 4 {{property access is 'async' but is not marked with 'await'}}
  _ = (await chain.next)?.next?.next?.next // expected-error 3 {{property access is 'async' but is not marked with 'await'}}
  _ = (await chain.next?.next)?.next?.next // expected-error 2 {{property access is 'async' but is not marked with 'await'}}
}


// want to make sure there is no note about implicitly async on this func.
@BananaActor func rice() async {}

@OrangeActor func quinoa() async {
  rice() // expected-error {{call is 'async' but is not marked with 'await'}}
}

///////////
// check various curried applications to ensure we mark the right expression.

actor Calculator {
  func addCurried(_ x : Int) -> ((Int) -> Int) { 
    return { (_ y : Int) in x + y }
  }

  func add(_ x : Int, _ y : Int) -> Int {
    return x + y
  }
}

@BananaActor func bananaAdd(_ x : Int) -> ((Int) -> Int) { 
  return { (_ y : Int) in x + y }
}

@OrangeActor func doSomething() async {
  let _ = (await bananaAdd(1))(2)
  // expected-warning@-1{{cannot call function returning non-sendable type}}
  let _ = await (await bananaAdd(1))(2) // expected-warning{{no 'async' operations occur within 'await' expression}}
  // expected-warning@-1{{cannot call function returning non-sendable type}}

  let calc = Calculator()
  
  let _ = (await calc.addCurried(1))(2)
  // expected-warning@-1{{cannot call function returning non-sendable type}}
  let _ = await (await calc.addCurried(1))(2) // expected-warning{{no 'async' operations occur within 'await' expression}}
  // expected-warning@-1{{cannot call function returning non-sendable type}}

  let plusOne = await calc.addCurried(await calc.add(0, 1))
  // expected-warning@-1{{cannot call function returning non-sendable type}}
  let _ = plusOne(2)
}

///////
// Effectful properties isolated to a global actor

@BananaActor
var effPropA : Int {
  get async {
    await asyncer()
    try thrower() // expected-error{{errors thrown from here are not handled}}
    return 0
  }
}

@BananaActor
var effPropT : Int { // expected-note{{var declared here}}
  get throws {
    await asyncer()  // expected-error{{'async' call in a function that does not support concurrency}}
    try thrower()
    return 0
  }
}

@BananaActor
var effPropAT : Int {
  get async throws {
    await asyncer()
    try thrower()
    return 0
  }
}

// expected-note@+1 2 {{add 'async' to function 'tryEffPropsFromBanana()' to make it asynchronous}}
@BananaActor func tryEffPropsFromBanana() throws {
  // expected-error@+1{{'async' property access in a function that does not support concurrency}}
  _ = effPropA

  // expected-note@+4{{did you mean to handle error as optional value?}}
  // expected-note@+3{{did you mean to use 'try'?}}
  // expected-note@+2{{did you mean to disable error propagation?}}
  // expected-error@+1{{property access can throw but is not marked with 'try'}}
  _ = effPropT

  _ = try effPropT

  // expected-note@+6 {{did you mean to handle error as optional value?}}
  // expected-note@+5 {{did you mean to use 'try'?}}
  // expected-note@+4 {{did you mean to disable error propagation?}}
  // expected-error@+3 {{property access can throw but is not marked with 'try'}}
  // expected-note@+2 {{call is to 'rethrows' function, but argument function can throw}}
  // expected-error@+1 {{call can throw but is not marked with 'try'}}
  _ = rethrower(effPropT)

  // expected-note@+2 {{call is to 'rethrows' function, but argument function can throw}}
  // expected-error@+1 {{call can throw but is not marked with 'try'}}
  _ = rethrower(try effPropT)

  _ = try rethrower(effPropT)
  _ = try rethrower(thrower())

  _ = try rethrower(try effPropT)
  _ = try rethrower(try thrower())

  _ = rethrower(effPropA) // expected-error{{'async' property access in an autoclosure that does not support concurrency}}

  _ = asAutoclosure(effPropT) // expected-error{{property access can throw, but it is not marked with 'try' and it is executed in a non-throwing autoclosure}}

  // expected-note@+5{{did you mean to handle error as optional value?}}
  // expected-note@+4{{did you mean to use 'try'?}}
  // expected-note@+3{{did you mean to disable error propagation?}}
  // expected-error@+2{{property access can throw but is not marked with 'try'}}
  // expected-error@+1{{'async' property access in a function that does not support concurrency}}
  _ = effPropAT
}


// expected-note@+2 {{add '@BananaActor' to make global function 'tryEffPropsFromSync()' part of global actor 'BananaActor'}}
// expected-note@+1 2 {{add 'async' to function 'tryEffPropsFromSync()' to make it asynchronous}}
func tryEffPropsFromSync() {
  _ = effPropA // expected-error{{'async' property access in a function that does not support concurrency}}

  // expected-error@+1 {{property access can throw, but it is not marked with 'try' and the error is not handled}}
  _ = effPropT // expected-error{{var 'effPropT' isolated to global actor 'BananaActor' can not be referenced from this synchronous context}}
  // NOTE: that we don't complain about async access on `effPropT` because it's not declared async, and we're not in an async context!

  // expected-error@+1 {{property access can throw, but it is not marked with 'try' and the error is not handled}}
  _ = effPropAT // expected-error{{'async' property access in a function that does not support concurrency}}
}

@OrangeActor func tryEffPropertiesFromGlobalActor() async throws {
  // expected-error@+1{{property access is 'async' but is not marked with 'await'}} {{7-7=await }}
  _ = effPropA

  // expected-note@+5{{did you mean to handle error as optional value?}}
  // expected-note@+4{{did you mean to use 'try'?}}
  // expected-note@+3{{did you mean to disable error propagation?}}
  // expected-error@+2{{property access can throw but is not marked with 'try'}}
  // expected-error@+1{{property access is 'async' but is not marked with 'await'}} {{7-7=await }}
  _ = effPropT

  // expected-note@+5{{did you mean to handle error as optional value?}}
  // expected-note@+4{{did you mean to use 'try'?}}
  // expected-note@+3{{did you mean to disable error propagation?}}
  // expected-error@+2{{property access can throw but is not marked with 'try'}}
  // expected-error@+1{{property access is 'async' but is not marked with 'await'}} {{7-7=await }}
  _ = effPropAT

  _ = await effPropA
  _ = try? await effPropT
  _ = try! await effPropAT
}

/////////////
// check subscripts in actors

actor SubscriptA {
  subscript(_ i : Int) -> Int {
     get async {
        try thrower() // expected-error{{errors thrown from here are not handled}}
        await asyncer()
        return 0
     }
  }

  func f() async {
    _ = self[0] // expected-error{{subscript access is 'async' but is not marked with 'await'}}
  }
}

actor SubscriptT {
  subscript(_ i : Int) -> Int {
     get throws {
        try thrower()
        await asyncer() // expected-error{{'async' call in a function that does not support concurrency}}
        return 0
     }
  }

  func f() throws {
    _ = try self[0]

    // expected-note@+6 {{did you mean to handle error as optional value?}}
    // expected-note@+5 {{did you mean to use 'try'?}}
    // expected-note@+4 {{did you mean to disable error propagation?}}
    // expected-error@+3 {{subscript access can throw but is not marked with 'try'}}
    // expected-note@+2 {{call is to 'rethrows' function, but argument function can throw}}
    // expected-error@+1 {{call can throw but is not marked with 'try'}}
    _ = rethrower(self[1])

    // expected-note@+2 {{call is to 'rethrows' function, but argument function can throw}}
    // expected-error@+1 {{call can throw but is not marked with 'try'}}
    _ = rethrower(try self[1])

    _ = try rethrower(self[1])
    _ = try rethrower(try self[1])
  }
}

actor SubscriptAT {
  subscript(_ i : Int) -> Int {
     get async throws {
        try thrower()
        await asyncer()
        return 0
     }
  }

  func f() async throws {
    _ = try await self[0]
  }
}

func tryTheActorSubscripts(a : SubscriptA, t : SubscriptT, at : SubscriptAT) async throws {
  _ = a[0] // expected-error{{subscript access is 'async' but is not marked with 'await'}}

  _ = await a[0]

  // expected-note@+5{{did you mean to handle error as optional value?}}
  // expected-note@+4{{did you mean to use 'try'?}}
  // expected-note@+3{{did you mean to disable error propagation?}}
  // expected-error@+2{{subscript access can throw but is not marked with 'try'}}
  // expected-error@+1 {{subscript access is 'async' but is not marked with 'await'}}
  _ = t[0]

  _ = try await t[0]
  _ = try! await t[0]
  _ = try? await t[0]

  // expected-note@+5{{did you mean to handle error as optional value?}}
  // expected-note@+4{{did you mean to use 'try'?}}
  // expected-note@+3{{did you mean to disable error propagation?}}
  // expected-error@+2{{subscript access can throw but is not marked with 'try'}}
  // expected-error@+1 {{subscript access is 'async' but is not marked with 'await'}}
  _ = at[0]

  _ = try await at[0]
}