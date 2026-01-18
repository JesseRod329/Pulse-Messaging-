//
//  Bolt11Parser.swift
//  Pulse
//
//  BOLT11 invoice parsing for Lightning payments.
//

import Foundation

enum Bolt11Network: String {
    case bitcoin = "bc"
    case testnet = "tb"
    case regtest = "bcrt"
    case signet = "sb"
}

enum Bolt11Tag: Equatable {
    case paymentHash(Data)
    case description(String)
    case descriptionHash(Data)
    case expiry(UInt64)
    case payeePublicKey(Data)
    case minFinalCLTVExpiry(UInt64)
    case fallbackAddress(Data)
    case routingInfo(Data)
    case features(Data)
    case unknown(Character, Data)
}

struct Bolt11Invoice: Equatable {
    let raw: String
    let hrp: String
    let network: Bolt11Network
    let amountMillisats: Int?
    let timestamp: Date
    let tags: [Bolt11Tag]
    let signature: Data

    var paymentHash: Data? {
        tags.first { tag in
            if case .paymentHash = tag { return true }
            return false
        }.flatMap { tag in
            if case let .paymentHash(value) = tag { return value }
            return nil
        }
    }

    var description: String? {
        tags.first { tag in
            if case .description = tag { return true }
            return false
        }.flatMap { tag in
            if case let .description(value) = tag { return value }
            return nil
        }
    }

    var descriptionHash: Data? {
        tags.first { tag in
            if case .descriptionHash = tag { return true }
            return false
        }.flatMap { tag in
            if case let .descriptionHash(value) = tag { return value }
            return nil
        }
    }
}

enum Bolt11ParserError: Error, LocalizedError {
    case invalidBech32
    case invalidHrp
    case unsupportedNetwork
    case invalidDataLength
    case invalidSignatureLength
    case invalidTimestamp
    case invalidTagData
    case invalidAmount

    var errorDescription: String? {
        switch self {
        case .invalidBech32:
            return "Invalid BOLT11 bech32 encoding"
        case .invalidHrp:
            return "Invalid BOLT11 invoice prefix"
        case .unsupportedNetwork:
            return "Unsupported BOLT11 network"
        case .invalidDataLength:
            return "Invalid BOLT11 data length"
        case .invalidSignatureLength:
            return "Invalid BOLT11 signature length"
        case .invalidTimestamp:
            return "Invalid BOLT11 timestamp"
        case .invalidTagData:
            return "Invalid BOLT11 tag data"
        case .invalidAmount:
            return "Invalid BOLT11 amount"
        }
    }
}

struct Bolt11Parser {
    func parse(_ invoice: String) throws -> Bolt11Invoice {
        let normalized = invoice.lowercased().replacingOccurrences(of: "lightning:", with: "")
        guard let (hrp, values) = Bech32.decodeToValues(normalized) else {
            throw Bolt11ParserError.invalidBech32
        }

        guard hrp.hasPrefix("ln") else {
            throw Bolt11ParserError.invalidHrp
        }

        let (network, amountMillisats) = try parseHrp(hrp)
        guard values.count >= 7 + 104 else {
            throw Bolt11ParserError.invalidDataLength
        }

        let signatureValues = Array(values.suffix(104))
        let dataValues = Array(values.dropLast(104))

        guard let signature = convertFrom5Bit(signatureValues, allowPadding: false),
              signature.count == 65 else {
            throw Bolt11ParserError.invalidSignatureLength
        }

        var reader = BitReader(values: dataValues)
        guard let timestampSeconds = reader.readUInt(bits: 35) else {
            throw Bolt11ParserError.invalidTimestamp
        }

        let timestamp = Date(timeIntervalSince1970: TimeInterval(timestampSeconds))
        let tags = try parseTags(reader: &reader)

        return Bolt11Invoice(
            raw: normalized,
            hrp: hrp,
            network: network,
            amountMillisats: amountMillisats,
            timestamp: timestamp,
            tags: tags,
            signature: signature
        )
    }

    private func parseHrp(_ hrp: String) throws -> (Bolt11Network, Int?) {
        let prefix = String(hrp.prefix(2))
        guard prefix == "ln" else {
            throw Bolt11ParserError.invalidHrp
        }

        let remainder = String(hrp.dropFirst(2))
        let networkCandidates: [Bolt11Network] = [.bitcoin, .testnet, .regtest, .signet]
        guard let network = networkCandidates.first(where: { remainder.hasPrefix($0.rawValue) }) else {
            throw Bolt11ParserError.unsupportedNetwork
        }

        let amountPart = String(remainder.dropFirst(network.rawValue.count))
        if amountPart.isEmpty {
            return (network, nil)
        }

        let (amountString, multiplier) = splitAmount(amountPart)
        guard !amountString.isEmpty else {
            throw Bolt11ParserError.invalidAmount
        }
        guard let amountDecimal = Decimal(string: amountString) else {
            throw Bolt11ParserError.invalidAmount
        }

        let multiplierFactor: Decimal
        switch multiplier {
        case "m":
            multiplierFactor = Decimal(string: "0.001") ?? 0
        case "u":
            multiplierFactor = Decimal(string: "0.000001") ?? 0
        case "n":
            multiplierFactor = Decimal(string: "0.000000001") ?? 0
        case "p":
            multiplierFactor = Decimal(string: "0.000000000001") ?? 0
        case nil:
            multiplierFactor = 1
        default:
            throw Bolt11ParserError.invalidAmount
        }

        let btcAmount = amountDecimal * multiplierFactor
        let millisatsDecimal = btcAmount * Decimal(100_000_000_000)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &millisatsDecimal, 0, .plain)
        guard rounded == millisatsDecimal,
              rounded >= 0 else {
            throw Bolt11ParserError.invalidAmount
        }

        let msatsNumber = NSDecimalNumber(decimal: rounded)
        if msatsNumber.compare(NSDecimalNumber(value: Int64.max)) == .orderedDescending {
            throw Bolt11ParserError.invalidAmount
        }

        let millisats = msatsNumber.int64Value
        guard millisats <= Int64(Int.max) else {
            throw Bolt11ParserError.invalidAmount
        }

        return (network, Int(millisats))
    }

    private func splitAmount(_ amountPart: String) -> (String, Character?) {
        guard let last = amountPart.last, last.isLetter else {
            return (amountPart, nil)
        }
        return (String(amountPart.dropLast()), last)
    }

    private func parseTags(reader: inout BitReader) throws -> [Bolt11Tag] {
        var tags: [Bolt11Tag] = []
        while reader.hasBitsAvailable {
            guard let typeValue = reader.readUInt(bits: 5),
                  let lengthValue = reader.readUInt(bits: 10) else {
                throw Bolt11ParserError.invalidTagData
            }

            guard typeValue < UInt64(Self.bech32Charset.count) else {
                throw Bolt11ParserError.invalidTagData
            }
            let tagType = Self.bech32Charset[Int(typeValue)]
            let length = Int(lengthValue)
            let tagValues = try reader.readValues(count: length)
            let tagData = convertFrom5Bit(tagValues, allowPadding: false) ?? Data()

            switch tagType {
            case "p":
                guard tagData.count == 32 else { throw Bolt11ParserError.invalidTagData }
                tags.append(.paymentHash(tagData))
            case "d":
                guard let description = String(data: tagData, encoding: .utf8) else {
                    throw Bolt11ParserError.invalidTagData
                }
                tags.append(.description(description))
            case "h":
                guard tagData.count == 32 else { throw Bolt11ParserError.invalidTagData }
                tags.append(.descriptionHash(tagData))
            case "x":
                let expiry = valuesToUInt(tagValues)
                tags.append(.expiry(expiry))
            case "n":
                guard tagData.count == 33 else { throw Bolt11ParserError.invalidTagData }
                tags.append(.payeePublicKey(tagData))
            case "c":
                let cltv = valuesToUInt(tagValues)
                tags.append(.minFinalCLTVExpiry(cltv))
            case "f":
                tags.append(.fallbackAddress(tagData))
            case "r":
                tags.append(.routingInfo(tagData))
            case "9":
                tags.append(.features(tagData))
            default:
                tags.append(.unknown(tagType, tagData))
            }
        }
        return tags
    }

    private func valuesToUInt(_ values: [UInt8]) -> UInt64 {
        var result: UInt64 = 0
        for value in values {
            result = (result << 5) | UInt64(value)
        }
        return result
    }

    private static let bech32Charset: [Character] = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    private func convertFrom5Bit(_ values: [UInt8], allowPadding: Bool) -> Data? {
        var result = Data()
        var acc: UInt32 = 0
        var bits: UInt32 = 0

        for value in values {
            guard value < 32 else { return nil }
            acc = (acc << 5) | UInt32(value)
            bits += 5
            while bits >= 8 {
                bits -= 8
                result.append(UInt8((acc >> bits) & 0xff))
            }
        }

        if !allowPadding && bits > 0 {
            let paddingMask = UInt32((1 << bits) - 1)
            if (acc & paddingMask) != 0 {
                return nil
            }
        }

        return result
    }
}

private struct BitReader {
    private let values: [UInt8]
    private var bitIndex: Int = 0

    init(values: [UInt8]) {
        self.values = values
    }

    var hasBitsAvailable: Bool {
        bitIndex < values.count * 5
    }

    mutating func readUInt(bits: Int) -> UInt64? {
        guard bits > 0, bits <= 64 else { return nil }
        guard bitIndex + bits <= values.count * 5 else { return nil }

        var remaining = bits
        var result: UInt64 = 0
        while remaining > 0 {
            let valueIndex = bitIndex / 5
            let offset = bitIndex % 5
            let available = 5 - offset
            let take = min(available, remaining)
            let value = values[valueIndex]
            let shift = available - take
            let mask = UInt8((1 << take) - 1) << shift
            let extracted = UInt64((value & mask) >> shift)
            result = (result << UInt64(take)) | extracted
            bitIndex += take
            remaining -= take
        }

        return result
    }

    mutating func readValues(count: Int) throws -> [UInt8] {
        guard count >= 0 else { throw Bolt11ParserError.invalidTagData }
        var result: [UInt8] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            guard let value = readUInt(bits: 5), value < 32 else {
                throw Bolt11ParserError.invalidTagData
            }
            result.append(UInt8(value))
        }
        return result
    }
}
