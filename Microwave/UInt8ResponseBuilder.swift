//
//  UTF8ResponseBuilder.swift
//  Microwave
//
//  Created by Joannis Orlandos on 22/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

typealias HttpCode = (Int, String)

public enum ResponseCode : Int {
    case OK = 200
    
    case BadRequest = 400
    case NotFound = 404
    
    case InternalServerError = 500
    
    var description: String {
        switch self {
        case .OK:
            return "OK"
        case .BadRequest:
            return "Bad Request"
        case .NotFound:
            return "Not Found"
        case .InternalServerError:
            return "Internal Server Error"
        }
    }
}

public class UInt8ResponseBuilder {
    public private(set) var headers: [String: String]
    public private(set) var body: [UInt8]
    public private(set) var responseCode: ResponseCode
    public private(set) var contentType: String
    
    public init(responseCode: ResponseCode, contentType: String = "", headers: [String: String] = [:], body: String = "") {
        self.responseCode = responseCode
        self.contentType = contentType
        self.headers = headers
        self.body = [UInt8]()
        self.body.appendContentsOf(body.utf8)
    }
    
    public func generate() -> [UInt8] {
        var responseString = "HTTP/1.1 \(responseCode.rawValue) \(responseCode.description)\r\n"
        
        if !contentType.isEmpty {
            responseString += "Content-Type: \(contentType)\r\n"
        }
        
        responseString += "Server: Microwave\r\n"
        
        for (key, value) in headers {
            responseString += "\(key): \(value)\r\n"
        }
        
        responseString += "\r\n"
        
        var responseData = [UInt8]()
        responseData.appendContentsOf(responseString.utf8)
        responseData += body
        
        return responseData
    }
}