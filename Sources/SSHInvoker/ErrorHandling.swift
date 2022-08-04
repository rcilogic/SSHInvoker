//
//  Created by Konstantin Gorshkov on 30.03.2022
//  Copyright (c) 2022 Konstantin Gorshkov. All Rights Reserved
//  See LICENSE.txt for license information
//
//  SPDX-License-Identifier: Apache-2.0
//


import NIO

extension SSHInvoker {
    enum Error: Swift.Error {
        case passwordAuthenticationNotSupported
        case commandExecFailed
        case invalidChannelType
        case invalidData
        case parentChannelCantBeClosedBecouseItDoesntExist
        case scriptExecutionTimeout
        case invalidEnteredServerPublicKey
        case disallowedRemoteServerPublicKey
        case invalidHostname
        case invalidPort
    }
}

final class InvokerErrorHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    
    var errorPromise: EventLoopPromise<Void>? = nil
    
    init (){}
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        errorPromise?.fail(error)
    }
    
    deinit {
        errorPromise?.succeed(())
    }
    
}



