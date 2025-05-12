import SwiftUI

struct MemoryCalculatorView: View {
    @Binding var modelSizeB: Double
    @Binding var precision: String
    @Binding var isFlipped: Bool
    @State private var overhead: Double = 1.2
    @State private var showingCalculatorHelp = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                // Calculator View (Front)
                VStack(spacing: 7) {
                    Text("Memory Calculator")
                        .font(.headline)
                    
                    HStack {
                        Text("Calculate GPU RAM Needed")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Button(action: { showingCalculatorHelp = true }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                        }
                    }
                    .alert(isPresented: $showingCalculatorHelp) {
                        Alert(
                            title: Text("GPU RAM Calculator"),
                            message: Text("When you need to estimate GPU card RAM for an LLM you use, these fields can calculate."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    
                    ScrollView {
                        InputFieldsView(
                            modelSizeB: $modelSizeB,
                            precision: $precision,
                            overhead: $overhead
                        )
                    }
                    .frame(height: 143)
                    
                    ResultsView(
                        modelSizeB: modelSizeB,
                        precision: precision,
                        overhead: overhead
                    )
                }
                .modifier(FlipModifier(isFlipped: !isFlipped))
                
                // Options View (Back)
                VStack {
                    // ... options content ...
                }
                .modifier(FlipModifier(isFlipped: isFlipped))
            }
            
            // Flip button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.6)) {
                    isFlipped.toggle()
                }
            }) {
                Image(systemName: "arrow.2.squarepath")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(Color.white.opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(.leading, 2)
            .padding(.bottom, 5)
        }
    }
}

struct FlipModifier: ViewModifier {
    let isFlipped: Bool
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 1, y: 0, z: 0)  // Changed from y-axis to x-axis for vertical flip
            )
            .opacity(isFlipped ? 0 : 1)  // Hide backside of card
    }
}

struct InputFieldsView: View {
    @Binding var modelSizeB: Double
    @Binding var precision: String
    @Binding var overhead: Double
    @State private var isFocused = false
    @State private var showingParametersHelp = false
    @State private var showingPrecisionHelp = false
    @State private var showingOverheadHelp = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Parameters
            HStack {
                HStack {
                    Text("Parameters (Billions):")
                        .font(.subheadline)
                        .frame(width: 160, alignment: .leading)
                    
                    Button(action: { showingParametersHelp = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
                .alert(isPresented: $showingParametersHelp) {
                    Alert(
                        title: Text("Parameters"),
                        message: Text("Number of parameters in billions (e.g., 30 for a 30B model)"),
                        dismissButton: .default(Text("OK"))
                    )
                }
                
                TextField("", value: $modelSizeB, formatter: NumberFormatter())
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                    .keyboardType(.decimalPad)
                    .opacity(0.6)  // Match card opacity
            }
            
            // Precision
            HStack {
                HStack {
                    Text("Precision (Bits):")
                        .font(.subheadline)
                        .frame(width: 160, alignment: .leading)
                    
                    Button(action: { showingPrecisionHelp = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .alert("Precision", isPresented: $showingPrecisionHelp) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("""
                            FP32: 32-bit floating point (4 bytes)
                            FP16: 16-bit floating point (2 bytes)
                            INT8: 8-bit integer (1 byte)
                            """)
                    }
                }
                
                Picker("", selection: $precision) {
                    Text("FP32").tag("FP32")
                    Text("FP16").tag("FP16")
                    Text("INT8").tag("INT8")
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 100)
                .opacity(0.6)  // Match card opacity
            }
            
            // Optimization Overhead
            HStack {
                HStack {
                    Text("Optimal Overhead:")
                        .font(.subheadline)
                        .frame(width: 160, alignment: .leading)
                    
                    Button(action: { showingOverheadHelp = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .alert("Optimization", isPresented: $showingOverheadHelp) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("1.1: Overhead when accelerated\n1.2: Standard overhead")
                    }
                }
                
                Picker("", selection: $overhead) {
                    Text("1.2").tag(1.2)
                    Text("1.1").tag(1.1)
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 80)
                .opacity(0.6)  // Match card opacity
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                                 to: nil, 
                                                 from: nil, 
                                                 for: nil)
                }
            }
        }
    }
}

struct SparkleView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            ForEach(0..<12) { index in
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4, height: 4)
                    .offset(y: isAnimating ? -40 : 0)
                    .opacity(isAnimating ? 0 : 1)
                    .rotationEffect(.degrees(Double(index) * 30))
                    .animation(
                        Animation.easeOut(duration: 0.5)
                            .delay(Double(index) * 0.05)
                            .repeatCount(1, autoreverses: false),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ResultsView: View {
    let modelSizeB: Double
    let precision: String
    let overhead: Double
    
    @State private var previousMemory: String = ""
    @State private var showSparkle = false
    
    private var totalMemory: String {
        MemoryCalculator.calculateModelMemory(
            modelSizeB: modelSizeB,
            precision: precision,
            overhead: overhead
        )
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("Required")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .padding(.top, -20)
            HStack(spacing: 4) {
                Text("GPU Memory:")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                
                // Result with sparkle
                HStack(spacing: 0) {
                    Text("\(totalMemory)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.blue)
                        .overlay(
                            Group {
                                if showSparkle {
                                    SparkleView()
                                        .offset(x: -8, y: 0)
                                }
                            }
                        )
                    
                    Text(" GB")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 10)  // Add 10px buffer at bottom
        }
        .frame(maxWidth: .infinity)
        .help("Based on formula: M = (P * B * (32/Q) * O)\nP: Parameters\nB: Base bytes\nQ: Precision bits\nO: Optimization overhead")
        .onChange(of: totalMemory) { newValue in
            if previousMemory != newValue {
                showSparkle = true
                previousMemory = newValue
                
                // Reset sparkle after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showSparkle = false
                }
            }
        }
    }
} 
