//
//  Created by Konstantin Gorshkov on 13.04.2022
//  Copyright (c) 2022 Konstantin Gorshkov. All Rights Reserved
//  See LICENSE.txt for license information
//
//  SPDX-License-Identifier: Apache-2.0
//


extension SSHInvoker {
    public struct Target {
        let host: String
        let port: Int
        
        public init (host: String, port: Int = 22) {
            self.host = host
            self.port = port
        }
        
    }
    
    public enum Credentials {
        case password(username: String, password: String)
        //case publicKey(username: String, privateKey: String)
    }

    public enum ServerAuthentication {
        case allowAll
        case publicKey (_ openSSHPublicKey: String)
    }
    
    public enum Signal: String {
        case kill = "KILL"
        case interrupt = "INT"
    }
}

