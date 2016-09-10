import XCTest
@testable import FieryCrucible

class FieryCrucibleTests: XCTestCase {
    var testFactory: TestFactory!
    
    override func setUp() {
        super.setUp()
        
        testFactory = TestFactory()
        TestInstance.clearInitCounts()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testShared() {
        // Once instance per factory instance (effectively a singleton), useful for NSFormatter instances.
        // If needed by multiple threads make an instance of the factory per thread so that each thread can
        // get its own distict instance of the object.
        let instanceA1 = testFactory.sharedA1()
        let instanceA2 = testFactory.sharedA2()
        let instanceB1 = testFactory.sharedB1()
        let instanceB2 = testFactory.sharedB2()
        
        XCTAssertEqual(instanceA1.name, "A1")
        XCTAssertEqual(instanceA2.name, "A2")
        XCTAssertEqual(instanceB1.name, "B1")
        XCTAssertEqual(instanceB2.name, "B2")
        
        XCTAssertEqual(instanceA1.initCount, 1)
        XCTAssertEqual(instanceA2.initCount, 1)
        XCTAssertEqual(instanceB1.initCount, 1)
        XCTAssertEqual(instanceB2.initCount, 1)
        
        XCTAssertTrue(instanceA1.dependency! === instanceA2)
        XCTAssertNil(instanceA1.delegate)
        XCTAssertNil(instanceA2.dependency)
        XCTAssertTrue(instanceA2.delegate! === instanceA1)
        XCTAssertNil(instanceB1.dependency)
        XCTAssertNil(instanceB1.delegate)
        XCTAssertTrue(instanceB2.dependency! === instanceB1)
        XCTAssertTrue(instanceB2.delegate! === instanceA1)
    }
    
    func testUnshared() {
        // New instance every time
        let instanceA1 = testFactory.unsharedA1()
        let instanceA2 = testFactory.unsharedA2()
        
        XCTAssertEqual(instanceA1.name, "A1")
        XCTAssertEqual(instanceA2.name, "A2")
        
        XCTAssertEqual(instanceA1.initCount, 1)
        XCTAssertEqual(instanceA2.initCount, 2)
        
        XCTAssertTrue(instanceA1.dependency! !== instanceA2)
        XCTAssertNil(instanceA1.delegate)
        XCTAssertNil(instanceA2.dependency)
        XCTAssertNil(instanceA2.delegate)
    }
    
    func testScoped() {
        // Same instance returned only if in the same dependency request, otherwise makes a new instance
        // Useful for creating instances of view controllers that will be assigned as the delegate of a view
        //                                          REQ# A1  A2  A3
        let instanceA1 = testFactory.scopedA1() //  1     Y   Y   Y (one A3 for both A1 and A2 for this dependency fulfilling request)
        let instanceA2 = testFactory.scopedA2() //  2     N   Y   Y (a different A3 for this second instance of A2 since this is a different request)
        let instanceA3 = testFactory.scopedA3() //  3     N   N   Y (a third instance of A3)
        
        XCTAssertEqual(instanceA1.name, "A1")
        XCTAssertEqual(instanceA2.name, "A2")
        XCTAssertEqual(instanceA3.name, "A3")
        
        XCTAssertEqual(instanceA1.initCount, 1)
        XCTAssertEqual(instanceA2.initCount, 2)
        XCTAssertEqual(instanceA3.initCount, 3)
        
        XCTAssertTrue(instanceA1.dependency?.delegate === instanceA1.delegate)
        XCTAssertTrue(instanceA1.delegate !== instanceA2.delegate)
    }
    
    func testWeakShared() {
        // Same as shared, but if no other objects retain the instance then it will be
        // released and free up memory (the factory doesn't retain it)
        var instanceA1: TestInstance? = testFactory.weakSharedA1()
        
        XCTAssertEqual(instanceA1?.name, "A1")
        XCTAssertEqual(instanceA1?.initCount, 1)
        
        instanceA1 = nil
        XCTAssertEqual(TestInstance.countForName("A1"), 0)
    }
    
    static var allTests : [(String, (FieryCrucibleTests) -> () throws -> Void)] {
        return [
            ("testShared", testShared),
            ("testUnshared", testUnshared),
            ("testScoped", testScoped),
            ("testWeakShared", testWeakShared),
        ]
    }
}

class TestInstance {
    private static var initCountByName = [String : Int](minimumCapacity: 16)
    public let name: String
    public var dependency: TestInstance?
    public weak var delegate: TestInstance?
    public var requiredDuringInit = false
    public var initCount: Int {
        return TestInstance.initCountByName[name] ?? 0
    }
    
    public init(name: String, dependency: TestInstance? = nil) {
        self.name = name
        self.dependency = dependency
        
        if let count = TestInstance.initCountByName[name] {
            TestInstance.initCountByName[name] = count + 1
        }
        else {
            TestInstance.initCountByName[name] = 1
        }
    }
    
    deinit {
        if let count = TestInstance.initCountByName[name] {
            TestInstance.initCountByName[name] = count - 1
        }
    }
    
    public static func countForName(_ name: String) -> Int {
        return TestInstance.initCountByName[name] ?? 0
    }
    
    public static func clearInitCounts() {
        initCountByName.removeAll(keepingCapacity: true)
    }
}

class TestFactory : DependencyFactory {
    public func sharedA1() -> TestInstance {
        return shared(TestInstance(name: "A1", dependency: sharedA2()))
    }
    
    public func sharedA2() -> TestInstance {
        return shared(TestInstance(name: "A2")) { (instance) in
            instance.delegate = self.sharedA1()
        }
    }
    
    public func sharedB1() -> TestInstance {
        return shared(
            factory: { () -> TestInstance in
                // Only use this form if you need to configure an instance that will be passed into
                // another objects initializer. The configure block only gets called after all init
                // methods have been called and is useful for setting properties that would cause
                // dependency cycles like delegates.
                let instance = TestInstance(name: "B1")
                instance.requiredDuringInit = true
                return instance
            }
        )
    }
    
    public func sharedB2() -> TestInstance {
        return shared(
            factory: { () -> TestInstance in
                // Only use this form if you need to configure an instance that will be passed into
                // another object's initializer. The configure block only gets called after all init
                // methods have been called and is useful for setting properties that would cause
                // dependency cycles like delegates.
                precondition(sharedB1().requiredDuringInit, "Fake a situation where bad program behavior would occur if property is not set before now")
                let instance = TestInstance(name: "B2", dependency: sharedB1())
                return instance
            },
            configure: { (instance) in
                instance.delegate = self.sharedA1()
            }
        )
    }
    
    public func unsharedA1() -> TestInstance {
        return unshared(TestInstance(name: "A1", dependency: unsharedA2()))
    }
    
    public func unsharedA2() -> TestInstance {
        return unshared(TestInstance(name: "A2"))
    }
    
    public func scopedA1() -> TestInstance {
        return scoped(TestInstance(name: "A1", dependency: scopedA2())) { (instance) in
            instance.delegate = self.scopedA3()
        }
    }
    
    public func scopedA2() -> TestInstance {
        return scoped(TestInstance(name: "A2")) { (instance) in
            instance.dependency = self.scopedA3() // A bit of a hack to keep A3 alive long enough to assert with
            instance.delegate = self.scopedA3()
        }
    }
    
    public func scopedA3() -> TestInstance {
        return scoped(TestInstance(name: "A3"))
    }
    
    public func weakSharedA1() -> TestInstance {
        return weakShared(TestInstance(name: "A1"))
    }
}
