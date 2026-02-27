import Foundation

struct RingBuffer<T> {
    private var buffer: [T?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ element: T) {
        buffer[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    var isFull: Bool { count == capacity }
    var isEmpty: Bool { count == 0 }

    var elements: [T] {
        guard count > 0 else { return [] }
        if count < capacity {
            return buffer[0..<count].compactMap { $0 }
        }
        let tail = buffer[writeIndex..<capacity].compactMap { $0 }
        let head = buffer[0..<writeIndex].compactMap { $0 }
        return tail + head
    }

    var last: T? {
        guard count > 0 else { return nil }
        let index = (writeIndex - 1 + capacity) % capacity
        return buffer[index]
    }

    mutating func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
}

// MARK: - Double / TimeInterval Statistics
// Note: TimeInterval is a typealias for Double, so a single extension covers both.

extension RingBuffer where T == Double {
    var mean: Double {
        guard count > 0 else { return 0 }
        return elements.reduce(0, +) / Double(count)
    }

    var variance: Double {
        guard count > 1 else { return 0 }
        let avg = mean
        let squaredDiffs = elements.map { ($0 - avg) * ($0 - avg) }
        return squaredDiffs.reduce(0, +) / Double(count - 1)
    }

    var standardDeviation: Double {
        sqrt(variance)
    }

    var coefficientOfVariation: Double {
        let avg = mean
        guard avg > 0 else { return 0 }
        return standardDeviation / avg
    }
}
