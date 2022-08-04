//
//  Created by Konstantin Gorshkov on 04.08.2022
//  Copyright (c) 2022 Konstantin Gorshkov. All Rights Reserved
//  See LICENSE.txt for license information
//
//  SPDX-License-Identifier: Apache-2.0
//
   

import Foundation
import NIO
import SSHInvoker

func input (_ text: String) -> String {
    print(text, terminator: ": " )
    return readLine(strippingNewline: true) ?? ""
}

extension ByteBuffer {
    var convertedToString: String { self.getString(at: 0, length: self.readableBytes) ?? "Unconvertable bytes" }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
defer {
    try! group.syncShutdownGracefully()
}

let host = input("Host")
let port = Int(input("Port [22]")) ?? 22
let username = input("Username")
let password = String(cString: getpass("Enter password:"))
let script = input("Script")


let invokerFuture = SSHInvoker.sendScript (
    script,
    scriptExecutionTimeout: .minutes(1),
    target: .init(host: host, port: port),
    serverAuthentication: .allowAll,
    connectionTimeout: .seconds(30),
    credentials: .password(username: username, password: password),
    eventLoopGroup: group,
    wantResult: true) { response, responseType in
        // chunks
        let string = response.convertedToString
        switch responseType {
        case .stdout:
            print ("--- stdout ---\n\(string)\n")
        case .stderr:
            print ("--- stderr ---\n\(string)\n")
        }
    }
// whole result
invokerFuture.whenComplete{ result in
    print ("************** Result **************")
    switch result {
    case .success(let response):
        var string = ""
        if let response = response {
            if let stdout = response.stdout?.convertedToString { string += "--- stdout ---\n \(stdout)\n" }
            if let stderr = response.stderr?.convertedToString { string += "--- stderr ---\n \(stderr)\n" }
        }
        print (string)
    case .failure(let error):
        print ("Error: \(error)")
    }
}

_ = try? invokerFuture.wait()
