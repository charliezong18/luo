import Foundation
import CryptoKit

// Seals the 白话 gloss corpus (proprietary, not in this repo — see LICENSE) into
// the AES-GCM blob the app bundles. The plaintext JSON and the key never enter
// git; without the key the app degrades to 原文-only.
//
//   swift scripts/baihua-crypt.swift <plaintext.json> <keyfile> <out.enc>
//
// <keyfile> holds a base64-encoded 32-byte AES key; generated if absent.

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write(Data("usage: swift baihua-crypt.swift <plaintext.json> <keyfile> <out.enc>\n".utf8))
    exit(1)
}
let (plainPath, keyPath, outPath) = (args[1], args[2], args[3])

let key: SymmetricKey
if FileManager.default.fileExists(atPath: keyPath) {
    guard let b64 = try? String(contentsOfFile: keyPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
          let data = Data(base64Encoded: b64), data.count == 32 else {
        FileHandle.standardError.write(Data("bad key file: \(keyPath)\n".utf8))
        exit(1)
    }
    key = SymmetricKey(data: data)
} else {
    let fresh = SymmetricKey(size: .bits256)
    let b64 = fresh.withUnsafeBytes { Data($0).base64EncodedString() }
    try! (b64 + "\n").write(toFile: keyPath, atomically: true, encoding: .utf8)
    key = fresh
}

let plain = try! Data(contentsOf: URL(fileURLWithPath: plainPath))
_ = try! JSONSerialization.jsonObject(with: plain)   // must be valid JSON
let sealed = try! AES.GCM.seal(plain, using: key)
try! sealed.combined!.write(to: URL(fileURLWithPath: outPath))
print("sealed \(plain.count) bytes -> \(outPath)")
