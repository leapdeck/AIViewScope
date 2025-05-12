struct MemoryCalculator {
    // Break down activation memory calculation into smaller steps
    
    private static func getPrecisionBits(_ precision: String) -> Double {
        switch precision {
            case "FP32": return 32.0
            case "FP16": return 16.0
            case "INT8": return 8.0
            case "INT4": return 4.0
            default: return 16.0
        }
    }
    
    static func calculateModelMemory(modelSizeB: Double, precision: String, overhead: Double) -> String {
        // M = (P * 4B * (32/Q) * O)
      //  let P = modelSizeB * 1_000_000_000  // Convert billions to actual number
        let P = modelSizeB
        let B = 1.0  // Base unit (bytes)
        let Q = getPrecisionBits(precision)
        let O = overhead
        
        // Calculate memory in bytes
        let M = P * 4 * B / (32.0/Q) * O
        
        // Convert to GB (divide by 1024^3)
        let memoryGB = M / (1024.0 * 1024.0 * 1024.0)
        return String(format: "%.0f", M)
    }
    
    static func recommendGPU(memoryGB: Double) -> String {
        switch memoryGB {
            case 0..<8:
                return "At least 1 8GB GPU"
            case 8..<12:
                return "At least 1 12GB GPU"
            case 12..<24:
                return "At least 1 24GB GPU"
            case 24..<48:
                return "At least 1 48GB GPU"
            case 48..<80:
                return "At least 1 80GB GPU"
            case 80..<170:
                return "At least 2 80GB GPU"
            default:
                return "Multiple GPUs needed"
        }
    }
} 
