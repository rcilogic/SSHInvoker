//
//  Created by Konstantin Gorshkov on 08.04.2022
//  Copyright (c) 2022 Konstantin Gorshkov. All Rights Reserved
//  See LICENSE.txt for license information
//
//  SPDX-License-Identifier: Apache-2.0
//


import Foundation
import NIO
import NIOSSH

public struct SSHInvoker {
    // Callback for stream chunks receiving.
    public typealias InboundStreamHandler = (ByteBuffer, InboundStreamType)->()
    public enum InboundStreamType {
        case stdout
        case stderr
    }
    
    public struct Result {
        public private(set) var stdout : ByteBuffer?
        public private(set) var stderr : ByteBuffer?
        
        public init (stdout: ByteBuffer? = nil, stderr: ByteBuffer? = nil) {
            self.stdout = stdout
            self.stderr = stderr
        }
        
        mutating func appendStdout (_ buf: ByteBuffer) {
            if self.stdout == nil {
                self.stdout = buf
            } else {
                let written = self.stdout!.setBuffer(buf, at: self.stdout!.writerIndex)
                self.stdout!.moveWriterIndex(forwardBy: written)
            }
        }
        mutating func appendStderr (_ buf:  ByteBuffer) {
            if self.stderr == nil {
                self.stderr = buf
            } else {
                let written = self.stderr!.setBuffer(buf, at: self.stderr!.writerIndex)
                self.stderr!.moveWriterIndex(forwardBy: written)
            }
        }
        
    }
    
    ///
    /// Connects to SSH server, execute script and disconnect  when script has finished it's work
    ///
    /// - Parameters:
    /// - `script`: Script Blocks or command which shoudl be executed on remote side.
    /// - `scriptExecutionTimout`:  If this parameter is set, script execution will be terminated by sending `SIGKILL` signal, and result EventLoopFuture will fail
    /// - `target`: Hostname/IP and Port (default: 22) of remote SSH server
    /// - `serverAuthentication`: If not set (**Not recommened**) it will use default value: allowAll, client will connect to remote server without validation.
    /// - It's recommended to provide .publicKey string, which should be formatted like this: "algorithm-id base64-encoded-key comments"
    /// - `connectionTimeout`:  If connectioun did not espablished during that amount of time, result EventLoopFuture will fail.
    /// - `credentials`:  username and password , which will be used to connect to SSH server
    /// - `wantResult`: if `true`, the function returns accumulated data of type `Result`. Otherwise it returns `nil`
    /// - `inboundStreamHandler`:  is used for receiving  data chunks from stream. Closure will be executed each time, when data has received from remote SSH server
    ///
    /// - Returns: `EventLoopFuture<Result?>`, which contains  `stdout` and `stderr` (of type `ByteBuffer`) or an `error` if it's in failure state
    ///
    public static func sendScript (
        _ script: String,
        scriptExecutionTimeout: TimeAmount? = nil,
        target: Target,
        serverAuthentication: ServerAuthentication,
        connectionTimeout: TimeAmount = .seconds(30),
        credentials: Credentials,
        eventLoopGroup group: EventLoopGroup,
        wantResult: Bool,
        inboundStreamHandler: InboundStreamHandler? = nil
    ) -> EventLoopFuture<Result?>
    {
        guard target.host != "" else {  return group.next().makeFailedFuture(Error.invalidHostname) }
        guard (0...65_535).contains(target.port) else { return group.next().makeFailedFuture(Error.invalidPort) }
                
        let invokerErrorHandler = InvokerErrorHandler()
        
        //MARK: Client bootstrap
        let clientBootstrap = ClientBootstrap (group: group).channelInitializer { channel in
            
            invokerErrorHandler.errorPromise = channel.eventLoop.makePromise(of: Void.self)
            
            return channel.pipeline.addHandlers([
                NIOSSHHandler(
                    role: .client( .init(
                        userAuthDelegate: SSHClientAuthenticationDelegate(credentials: credentials),
                        serverAuthDelegate: SSHServerAuthenticationDelegate(serverAuthentication: serverAuthentication)
                    )),
                    allocator: channel.allocator,
                    inboundChildChannelInitializer: nil
                ),
                invokerErrorHandler
            ])
        }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.Types.ConnectTimeoutOption(), value: connectionTimeout)
        
        
        // MARK: Channel
        let channelFuture = clientBootstrap.connect(host: target.host, port: target.port)
        
        let resultPromise = channelFuture.eventLoop.makePromise(of: Result?.self)
        
        // MARK: Child channel
        channelFuture.map { channel in
            
            // Cascade channel errors to invoker resultFuture error
            invokerErrorHandler.errorPromise?.futureResult.whenFailure{ error in
                channel.close().whenComplete{ _ in
                    resultPromise.fail(error)
                }
            }
            
            channel.pipeline.handler(type: NIOSSHHandler.self).map { sshHandler  in
                let sshInvokerHandler = SSHInvokerHandler(command: script, wantResult: wantResult, inboundStreamHandler: inboundStreamHandler)
                
                let childChannelPromise = channel.eventLoop.makePromise(of: Channel.self)
                
                sshHandler.createChannel(childChannelPromise){ childChannel, channelType in
                    guard channelType == .session else {
                        return channel.eventLoop.makeFailedFuture(Error.invalidChannelType)
                    }
                    return childChannel.pipeline.addHandlers ([sshInvokerHandler])
                }
                
                childChannelPromise.futureResult.map { childChannel in
                    // Script execution timeout
                    var isScriptExecutionTimeout: Bool = false
                    if let scriptExecutionTimeout = scriptExecutionTimeout {
                        childChannel.eventLoop.scheduleTask(in: scriptExecutionTimeout) {
                            isScriptExecutionTimeout = true
                            if (childChannel.isActive) {
                                childChannel.pipeline.fireErrorCaught(Error.scriptExecutionTimeout)
                            }
                        }
                    }
                    
                    childChannel.closeFuture.map {
                        _ = channel.close() // TODO: Handle possible Errors
                        if isScriptExecutionTimeout {
                            resultPromise.fail(Error.scriptExecutionTimeout)
                        }
                        resultPromise.succeed(sshInvokerHandler.result)
                    }.cascadeFailure(to: resultPromise)
                    
                }.cascadeFailure(to: resultPromise)
                
            }.cascadeFailure(to: resultPromise)
            
        }.cascadeFailure(to: resultPromise)
        
        return resultPromise.futureResult
    }
}
