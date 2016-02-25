//
//  WebSocketFrame.swift
//  Microwave
//
//  Created by Joannis Orlandos on 23/02/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import Foundation

// TODO: Support https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_servers
public struct WebSocketFrame {
    internal enum OperationCode : UInt8 {
        // Non-control frame op-codes
        case Continuation = 0x0
        case Text = 0x1
        case Binary = 0x2
        
        // Control frame op-codes
        case Close = 0x8
        case Ping = 0x9
        case Pong = 0xA
    }
    
    var finalFragment: Bool
    var rsv1: Bool
    var rsv2: Bool
    var rsv3: Bool
    var opcode: OperationCode
    var masked: Bool
    var payloadLength: UInt64
    
    // UInt32?
    var maskingKey: [UInt8]?
    
    var payload: [UInt8]
    
    static internal func getBit(index: UInt8, from: UInt8) -> Bool {
        return from >> index & 1 == 1
    }
    
    static internal func getBits(amount: UInt8, from: UInt8, skip: UInt8 = 0) -> UInt8 {
        var result: UInt8 = 0
        
        for k: UInt8 in skip..<amount {
            let mask: UInt8 = UInt8(1) << k
            let masked_n: UInt8 = from & mask
            result += masked_n
        }
        
        return result
    }
    
    init(fromBytes data: [UInt8]) throws {
        guard data.count >= 2 else {
            throw MicrowaveError.InternalError
        }
        
        var skip = 0
        
        guard let firstByte: UInt8 = data.first else {
            throw MicrowaveError.InternalError
        }
        
        finalFragment = WebSocketFrame.getBit(7, from: firstByte)
        rsv1 = WebSocketFrame.getBit(6, from: firstByte)
        rsv2 = WebSocketFrame.getBit(5, from: firstByte)
        rsv3 = WebSocketFrame.getBit(4, from: firstByte)
        
        guard let newOpCode: OperationCode = OperationCode(rawValue: WebSocketFrame.getBits(4, from: firstByte)) else {
            throw MicrowaveError.InternalError
        }
        
        opcode = newOpCode
        
        guard let secondByte: UInt8 = data[1] else {
            throw MicrowaveError.InternalError
        }
        
        skip += 2
        
        masked = WebSocketFrame.getBit(7, from: secondByte)
        
        let length = Int8(WebSocketFrame.getBits(7, from: secondByte))
        
        if length == 127 {
            guard data.count >= 10 else {
                throw MicrowaveError.InternalError
            }
            
            skip += 10
            payloadLength = UnsafePointer<UInt64>(Array(data[2..<10])).memory
        } else if length == 126 {
            guard data.count >= 4 else {
                throw MicrowaveError.InternalError
            }
            
            skip += 4
            payloadLength = UInt64(UnsafePointer<UInt16>(Array(data[2..<4])).memory)
        } else {
            payloadLength = UInt64(length)
        }
        
        if masked {
            guard data.count >= skip + 4 else {
                throw MicrowaveError.InternalError
            }
            maskingKey = Array(data[skip..<(skip + 4)])
            skip += 4
        }
        
        payload = Array(data[skip..<data.endIndex])
        
        guard UInt64(payload.count) == payloadLength else {
            throw MicrowaveError.InternalError
        }
        
        if masked {
            guard let maskingKey: [UInt8] = self.maskingKey where maskingKey.count == 4 else {
                throw MicrowaveError.InternalError
            }
            
            var newPayload = [UInt8]()
            
            for (key, byte) in payload.enumerate() {
                newPayload.append(byte ^ maskingKey[key % 4])
            }
            
            payload = newPayload
        }
    }
    
    internal init(withPayload payload: [UInt8], opcode: OperationCode) {
        self.finalFragment = true
        self.rsv1 = false
        self.rsv2 = false
        self.rsv3 = false
        self.opcode = opcode
        self.masked = false
        self.payloadLength = UInt64(payload.count)
        self.payload = payload
    }
    
    internal mutating func getBytes() throws -> [UInt8] {
        var data = [UInt8]()
        var firstByte: UInt8 = 0b00000000
        
        if finalFragment {
            firstByte |= 0b10000000
        }
        
        if rsv1 {
            firstByte |= 0b01000000
        }
        
        if rsv2 {
            firstByte |= 0b00100000
        }
        
        if rsv3 {
            firstByte |= 0b00010000
        }
        
        firstByte |= opcode.rawValue
        
        data.append(firstByte)
        
        var secondByte: UInt8 = 0b00000000
        
        if masked {
            secondByte |= 0b10000000
        }
        
        if payloadLength <= 125 {
            secondByte |= UInt8(payloadLength)
            data.append(secondByte)
        } else if payloadLength > UInt64(UInt16.max) {
            let bytes = withUnsafePointer(&payloadLength) {
                Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Int16)))
            }
            
            data += bytes
            data.append(127)
        } else {
            var len = UInt16(payloadLength)
            let bytes = withUnsafePointer(&len) {
                Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>($0), count: sizeof(Int16)))
            }
            
            data += bytes
            data.append(126)
        }
        
        if masked {
//            guard let maskingKey: [UInt8] = self.maskingKey where maskingKey.count == 4 else {
                throw MicrowaveError.InternalError
//            }
//            
//            var newPayload = [UInt8]()
//            
//            for (key, byte) in payload.enumerate() {
//                newPayload.append(byte ^ maskingKey[key % 4])
//            }
            
        } else {
            data += payload
        }
        
//        return [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        return data
    }
}