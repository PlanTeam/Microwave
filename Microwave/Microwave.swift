//
//  Microwave.swift
//  Microwave
//
//  Created by Joannis Orlandos on 18/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation
import When
import PlanTCP

public typealias HttpRequestHandler = ((HttpClient) -> Void)

public class Microwave {
    internal let server: TCPServer
    public var connected = true
    public private(set) var hosts = [Host]()
    
    init(port: UInt16 = 80) {
        server = TCPServer(port: port)
    }
    
    public func addHost(host: Host) {
        hosts.append(host)
    }
    
    public func generateErrorPage() -> [UInt8] {
        let page = UInt8ResponseBuilder(responseCode: .InternalServerError, contentType: "text/html", headers: [String: String](), body: "Internal Server Error")
        
        return page.generate()
    }
    
    func serve() throws {
        if server.connected {
            throw TCPError.AlreadyConnected
        }
        
        try server.bind()
        
        while true {
            let c = try! self.server.getClient()
            
            let _ = ThrowingFuture<Void> {
                var request = ""
                
                let _ = Future<Void> {
                    for _ in 0...100 {
                        if request.hasSuffix("\r\n\r\n") {
                            return
                        }
                        usleep(100000)
                    }
                    
                    self.server.closeClient(c)
                }
                
                // TODO: PARSE IN A SEPERATE LOW PRIORITY THREAD!
                // TODO: Timeout for this thread's success
                while !request.hasSuffix("\r\n\r\n") && self.server.connected {
                    var data = try self.server.receive(c)
                    
                    guard let requestPiece: String = String(bytesNoCopy: &data, length: data.count, encoding: NSUTF8StringEncoding, freeWhenDone: false) else {
                        try self.server.send(c, buffer: self.generateErrorPage())
                        
                        throw MicrowaveError.IncorrectRequest
                    }
                    
                    request += requestPiece
                }
                
                let context = try Context(server: self, client: c, request: request)
                
                hostLoop: for host in self.hosts {
                    do {
                        let response = try host.handleRequest(context)
                        hostSwitch: switch response {
                        case .Able(let responder):
                            do {
                                try responder(context: context)
                                break hostLoop
                            } catch{}
                            break hostSwitch
                        default:
                            break hostSwitch
                        }
                        
                    } catch {}
                }
                                
                }.onError { _ in }
        }
    }
}