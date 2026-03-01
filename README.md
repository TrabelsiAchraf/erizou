# 🛜 Erizou

![](https://img.shields.io/github/license/TrabelsiAchraf/erizou)
[![](https://img.shields.io/badge/SPM-supported-DE5C43.svg?style=flat)](https://swift.org/package-manager/)

Erizou is a lightweight network framework for simplifying HTTP calls in iOS project written in Swift.

## 🚀 Features

- [x] Chainable Request / Response Methods
- [x] Swift Concurrency Support
- [x] Upload File / Data
- [x] Download File using Request
- [x] DocC Documentation
- [x] Retry Requests (exponential backoff)
- [x] Network Reachability
- [x] Unit Tests

## 🚨 Requirements
- iOS 16.0+ 
- Xcode 14.3.1+
- Swift 5.8.1+

## 💻 Installing

### Swift Package Manager

- File > Swift Packages > Add Package Dependency
- Add the following dependency:
```ogdl
https://github.com/TrabelsiAchraf/erizou.git
```
- Select "Up to Next Major" with "0.1.0" (Beta)

## 🚀 Getting Started
- [Demo app](https://github.com/TrabelsiAchraf/erizou-demo) for usage

## 📖 Documentation

All public types and methods are documented with DocC-compatible comments. Open the package in Xcode and select **Product › Build Documentation** to generate the full reference.

### Quick Reference

| Method | Description |
|---|---|
| `sendRequest(endpoint:responseModel:)` | Send a request and decode the response |
| `upload(endpoint:data:responseModel:)` | Upload raw `Data` |
| `upload(endpoint:fileURL:responseModel:)` | Upload a file from a local URL |
| `download(endpoint:)` | Download a file and return its local cache URL |

### Retry

Set `retryCount` on your `HTTPClient` conformer to automatically retry on network failures with exponential backoff:

```swift
struct APIService: HTTPClient {
    var retryCount: Int { 3 }      // up to 3 retries
    var retryDelay: TimeInterval { 1.0 }  // 2s, 4s, 8s backoff
}
```

### Network Reachability

```swift
let reachability = NetworkReachability()

// Combine / SwiftUI
reachability.$isConnected
    .sink { print("Connected:", $0) }
    .store(in: &cancellables)
```

### Author

Achraf Trabelsi [@Tr_Achraf](https://twitter.com/Tr_Achraf)

## 👨‍⚖️ License

Erizou is released under the MIT license. [See LICENSE](https://github.com/TrabelsiAchraf/erizou/blob/master/LICENSE) for details
