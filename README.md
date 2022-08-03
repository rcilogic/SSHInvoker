# SSHInvoker

## Description
This package provides the ability to send commands to remote SSH server and receive data from it using swift-nio-ssh.

## Installation with Swift Package Manager
Add: 
.package(url: "https://github.com/rcilogic/SSHInvoker.git", from: "0.0.1" )

## Usage

```swift
import NIO
import SSHInvoker
...

        let group = MultiThreadedEventLoopGroup (numberOfThreads: System.coreCount)
                
        // replace with yours:
        let script = "ping github.com"
        let sshHost = "127.0.0.1"
        let sshPort = 22
        let serverPublicKey = "ssh-ed25519 ___PublicKey___ SRV01"
        let username = "user"
        let password = "password"
        
        SSHInvoker.sendScript (
            script,
            scriptExecutionTimeout: .minutes(1),
            target: .init(host: sshHost, port: sshPort),
            serverAuthentication: .publicKey(serverPublicKey),
            connectionTimeout: .seconds(30),
            credentials: .password(username: username, password: password),
            eventLoopGroup: group,
            wantResult: true) { response, responseType in
                switch responseType {
                case .stdout:
                    // Do something with response (ByteBuffer)
                case .stderr:
                    // Do something with response (ByteBuffer)
                }
            
            } .whenComplete{ result in
                switch result {
                    
                case .success(let response):
                    // Do something with response (ByteBuffer)
                case .failure(let error):
                    // Do something with error (Error)
                }
            }

```

## SSHInvoker.sendScript

### Parameters:
`script` Script Block or command which shoudl be executed on remote side.

`scriptExecutionTimout`  If this parameter is set, script execution will be terminated by sending `SIGKILL` signal, and result EventLoopFuture will fail.

`target` Hostname/IP and Port (default: 22) of remote SSH server.

`serverAuthentication` If not set (**not recommened**) it will use default value: `.allowAll`, client will connect to remote server without validation. It's recommended to provide `.publicKey` string, which should be formatted like this: "algorithm-id base64-encoded-key comments".

`connectionTimeout`  If connectioun did not espablished during that amount of time, result EventLoopFuture will fail.

`credentials`  username and password , which will be used to connect to SSH server.

`wantResult` if `true` the function returns accumulated data of type `Result`. Otherwise it returns `nil`

`inboundStreamHandler`  is used for receiving  data chunks from stream. Closure will be executed each time, when data has received from remote SSH server.

### - Returns: 
EventLoopFuture<Result?>, which contains  `stdout` and `stderr` (of type `ByteBuffer`) or an `error` if it's in a failure state
    
