//
//  Created by Konstantin Gorshkov on 08.04.2022
//  Copyright (c) 2022 Konstantin Gorshkov. All Rights Reserved
//  See LICENSE.txt for license information
//
//  SPDX-License-Identifier: Apache-2.0
//


import Foundation

import Dispatch
import NIO
import NIOSSH

final class SSHInvokerHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData
    
    let userCommand: String
    let wantResult: Bool
    let inboundStreamHandler : SSHInvoker.InboundStreamHandler?
    
    private(set) var result: SSHInvoker.Result?

    //TODO: Signal scheduler

    init (command: String, wantResult: Bool , inboundStreamHandler:  SSHInvoker.InboundStreamHandler?) {
        self.userCommand =  command
        self.inboundStreamHandler = inboundStreamHandler
        self.result = SSHInvoker.Result()
        self.wantResult = wantResult
        self.result = wantResult ? SSHInvoker.Result() : nil
    }
 
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
         
        defer {
            context.fireChannelRead(data)
        }
        
        let data = self.unwrapInboundIn(data)
        
        guard case .byteBuffer(let buf) = data.data else {
            //TODO: Handle unexpected read type error
            return
        }

        switch data.type {
        case .channel:
            if wantResult {
                result?.appendStdout(buf)
            }
            inboundStreamHandler?(buf, .stdout)
            return
            
        case .stdErr:
            if wantResult {
                result?.appendStderr(buf)
            }
            inboundStreamHandler?(buf, .stderr)
            return
            
        default:
            // TODO: Handle unexpected message type
            return
        }
    }
    
    func channelActive(context: ChannelHandlerContext) {
        execCommand(self.userCommand, context: context)
    }
 

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption (ChannelOptions.allowRemoteHalfClosure, value: true)
            .whenFailure{ error in
                context.fireErrorCaught(error)
            }
    }
    
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if error as? SSHInvoker.Error == .scriptExecutionTimeout {
            sendTimoutSignal(.kill, context: context)
        }
        
        context.fireErrorCaught(error)
    }
    
    private func execCommand (_ command: String, context: ChannelHandlerContext) {
        let execRequst = SSHChannelRequestEvent.ExecRequest(command: command, wantReply: false)
        
        _ = context.triggerUserOutboundEvent(execRequst)
    }
    
    private func sendTimoutSignal (_ signal: SSHInvoker.Signal, context: ChannelHandlerContext) {
        let execRequst = SSHChannelRequestEvent.SignalRequest(signal: signal.rawValue)
        _ = context.triggerUserOutboundEvent(execRequst).flatMap{
            context.close()
        }
    }
    
}
