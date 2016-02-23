//
//  MicrowaveTests.swift
//  MicrowaveTests
//
//  Created by Joannis Orlandos on 18/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import When
@testable import Microwave

class MicrowaveTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        let t = Microwave(port: 1337)
        let myHost = SimpleHost(host: "localhost", port: 1337)
        
        myHost.addURLhandler("/") { context in
            return "Hello World"
        }
        
        myHost.addNonRespondingHandler("/websocket/") { context in
            let websocket = WebSocketClient(client: context.socketClient) { websocket, message in
                do {
                    try websocket.respond(message.payload)
                } catch {
                    print("error")
                }
            }
            
            print("Upgrading")
            
            try websocket.respondToUpgrade()
        }
        
        t.addHost(myHost)
        
        let a = ThrowingFuture<Void> {
            try t.serve()
        }
        
        try! !>a
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
