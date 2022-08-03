//
//  Created by Konstantin Gorshkov on 11.04.2022
//  Copyright (c) 2022 Konstantin Gorshkov. All Rights Reserved
//  See LICENSE.txt for license information
//
//  SPDX-License-Identifier: Apache-2.0
//


import NIOSSH
import NIO

final class SSHClientAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate {
    
    private var credentials: SSHInvoker.Credentials
    
    init (credentials: SSHInvoker.Credentials){
        self.credentials = credentials
    }
       
    
    func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        
        switch self.credentials {
        case .password(let username, let password):
            guard availableMethods.contains(.password) else {
                nextChallengePromise.fail(SSHInvoker.Error.passwordAuthenticationNotSupported)
                return
            }
            nextChallengePromise.succeed(
                NIOSSHUserAuthenticationOffer(
                    username: username,
                    serviceName: "",
                    offer: .password( .init(password: password) )
                )
            )
        }
    }
}


final class SSHServerAuthenticationDelegate: NIOSSHClientServerAuthenticationDelegate {
    
    private let serverAuthentication: SSHInvoker.ServerAuthentication
    
    init (serverAuthentication: SSHInvoker.ServerAuthentication) {
        self.serverAuthentication = serverAuthentication
    }
    
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        
        switch serverAuthentication {
            
        case .allowAll:
            validationCompletePromise.succeed(())
            
        case .publicKey(let serverPublicKey):
            guard let allowedServerPublicKey = try? NIOSSHPublicKey(openSSHPublicKey: serverPublicKey) else {
                validationCompletePromise.fail(SSHInvoker.Error.invalidEnteredServerPublicKey)
                return
            }
            
            if hostKey == allowedServerPublicKey {
                validationCompletePromise.succeed(())
            } else {
                validationCompletePromise.fail(SSHInvoker.Error.disallowedRemoteServerPublicKey)
            }
        }
    }
    
}
