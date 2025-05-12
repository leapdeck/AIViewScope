//
//  ContentView.swift
//  ProjectLLMTray1
//
//  Created by modview on 2/26/25.
//

import SwiftUI
import CoreData
import SafariServices
import UIKit

// Add UIKit color extensions
extension Color {
    static let systemGray6 = Color(UIColor.systemGray6)
    static let systemBackground = Color(UIColor.systemBackground)
}

// Add screen dimensions helper
struct ScreenHelper {
    static var width: CGFloat {
        UIScreen.main.bounds.width
    }
    
    static var height: CGFloat {
        UIScreen.main.bounds.height
    }
}

// Update SafariView for iOS 15.5 compatibility
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView
        
        init(_ parent: SafariView) {
            self.parent = parent
        }
    }
}

struct LLMCardView: View {
    let item: [String: Any]
    let isFlipped: Bool
    let onFlip: () -> Void
    let onLink: (URL) -> Void
    
    var body: some View {
        ZStack {
            // Front of card
            VStack(alignment: .leading, spacing: 4) {
                // Model info row
                HStack {
                    // Model name
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Model name:")
                            .font(.subheadline)
                            .foregroundColor(darkBlue)
                        Text(item["LLM name"] as? String ?? "")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    // Parameter size
                    Text("Parameter Size: ")
                        .font(.subheadline)
                        .foregroundColor(darkBlue)
                    Text(item["Model Size"] as? String ?? "")
                        .font(.subheadline)
                        .foregroundColor(darkBlue)
                }
                
                HStack {
                    Text("Lic: ")
                        .font(.subheadline)
                        .foregroundColor(darkBlue)
                    Text(item["OpenSource Type"] as? String ?? "")
                        .font(.subheadline)
                        .foregroundColor(darkBlue)
                        .padding(.leading, 2)
                    Text("•")
                        .padding(.leading, 4)
                    Text("Launch Date: ")
                        .font(.subheadline)
                        .foregroundColor(darkBlue)
                    Text(formatDate(item["Latest Update"] as? String ?? ""))
                        .font(.subheadline)
                        .foregroundColor(darkBlue)
                }
                Text(item["content"] as? String ?? "")
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Link button only
                if let urlString = item["link"] as? String,
                   let url = URL(string: urlString) {
                    HStack {
                        Spacer()
                        Button(action: { onLink(url) }) {
                            Image(systemName: "globe")
                                .foregroundColor(darkOliveGreen)
                                .font(.system(size: 18))
                                .padding(8)
                                .background(Color(.systemGray6).opacity(0.5))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .modifier(GlassCardStyle())
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MM/yy"
            return dateFormatter.string(from: date)
        }
        return dateString
    }
}

struct ScrollMask: View {
    let isTop: Bool
    
    var body: some View {
        LinearGradient(
            colors: [.black, .clear], 
            startPoint: UnitPoint(x: 0.5, y: isTop ? 0 : 1), 
            endPoint: UnitPoint(x: 0.5, y: isTop ? 1 : 0)
        )
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .blendMode(.destinationOut)
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @SceneStorage("selectedOpenSourceTypes") 
    private var selectedOpenSourceTypesData = Data()
    
    @SceneStorage("selectedModelSizes") 
    private var selectedModelSizesData = Data()
    
    @SceneStorage("selectedYears") 
    private var selectedYearsData = Data()
    
    @SceneStorage("isOptionsExpanded")
    private var isOptionsExpanded = true
    
    @State private var presentedURL: URL?
    @State private var isLoading = true
    
    // First, add this state variable to track card flips
    @State private var flippedCards: Set<String> = []  // Store flipped card IDs
    
    // Change initial state to true so calculator shows first
    @State private var isOptionsCardFlipped = true
    
    // Keep only these calculator-related state variables
    @State private var modelSizeB: Double = 7.0
    @State private var precision: String = "FP16"
    
    // Get unique LLM names and OpenSource Types from sample data
    private var llmOptions: [OptionModel] {
        let uniqueLLMs = Set(sampleData.map { $0["LLM name"] as! String })
        return uniqueLLMs.map { OptionModel(name: $0) }.sorted(by: { $0.name < $1.name })
    }
    
    private var openSourceOptions: [OptionModel] {
        var uniqueTypes = Set(sampleData.map { $0["OpenSource Type"] as! String })
        
        // Remove all Apache and Custom variations and add single options
        uniqueTypes = uniqueTypes.filter { !$0.contains("Apache") && !$0.contains("Custom") }
        uniqueTypes.insert("Apache")
        uniqueTypes.insert("Custom")
        
        return uniqueTypes.map { OptionModel(name: $0) }.sorted(by: { $0.name < $1.name })
    }
    
    private let yearOptions: [OptionModel] = [
        OptionModel(name: "Last 6 Months"),
        OptionModel(name: "Previous Year"),
        OptionModel(name: "Past 2 Years")
    ]
    
    private let modelSizeOptions: [OptionModel] = [
        OptionModel(name: "Small < 5B"),
        OptionModel(name: "Large > 5B")
    ]
    
    // First add this helper function to determine the date range
    private func isDateInRange(_ dateString: String, range: String) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        guard let date = dateFormatter.date(from: dateString) else { return false }
        let currentDate = Date()
        let calendar = Calendar.current
        
        switch range {
        case "Last 6 Months":
            guard let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: currentDate) else { return false }
            return date >= sixMonthsAgo
        case "Previous Year":
            guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: currentDate) else { return false }
            return date >= oneYearAgo
        case "Past 2 Years":
            guard let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: currentDate) else { return false }
            return date >= twoYearsAgo
        default:
            return true
        }
    }
    
    // Then update the filteredData computed property
    private var filteredData: [[String: Any]] {
        var filtered = sampleData
        
        // Apply OpenSource Type and Model Size filters
        if !selectedOpenSourceTypes.isEmpty || !selectedModelSizes.isEmpty {
            filtered = filtered.filter { item in
                let typeMatch = selectedOpenSourceTypes.isEmpty || selectedOpenSourceTypes.contains(where: { option in
                    let itemType = item["OpenSource Type"] as! String
                    return option.name == itemType || 
                           (option.name == "Apache" && itemType.contains("Apache")) ||
                           (option.name == "Custom" && itemType.contains("Custom"))
                })
                let sizeMatch = selectedModelSizes.isEmpty || selectedModelSizes.contains(where: { option in
                    if let sizeStr = item["Model Size"] as? String,
                       let size = Double(sizeStr.replacingOccurrences(of: "B", with: "").replacingOccurrences(of: "T", with: "000")) {
                        return (option.name == "Small < 5B" && size < 5) ||
                               (option.name == "Large > 5B" && size >= 5)
                    }
                    return false
                })
                return typeMatch && sizeMatch
            }
        }
        
        // Apply date range filter
        if let selectedYear = selectedYears.first?.name {
            filtered = filtered.filter { item in
                isDateInRange(item["Latest Update"] as! String, range: selectedYear)
            }
        }
        
        return filtered
    }

    let sampleData = [
        [
            "id": "1",
            "LLM name": "T5",
            "Model Size": "11B",
            "Org": "Google",
            "Latest Update": "October 2019",
            "OpenSource Type": "Apache 2.0",
            "content": "Exploring the Limits of Transfer Learning with a Unified Text-to-Text Transformer.",
            "link": "https://github.com/google-research/text-to-text-transfer-transformer"
        ],
        [
            "id": "2",
            "LLM name": "RWKV 4",
            "Model Size": "14B",
            "Org": "BlinkDL",
            "Latest Update": "August 2021",
            "OpenSource Type": "Apache 2.0",
            "content": "The RWKV Language Model with transformer-level LLM performance.",
            "link": "https://github.com/BlinkDL/RWKV-LM#rwkv-parallelizable-rnn-with-transformer-level-llm-performance-pronounced-as-rwakuv-from-4-major-params-r-w-k-v"
        ],
        [
            "id": "3",
            "LLM name": "GPT-NeoX-20B",
            "Model Size": "20B",
            "Org": "EleutherAI",
            "Latest Update": "April 2022",
            "OpenSource Type": "Apache 2.0",
            "content": "GPT-NeoX-20B: An Open-Source Autoregressive Language Model.",
            "link": "https://huggingface.co/EleutherAI/gpt-neox-20b"
        ],
        [
            "id": "4",
            "LLM name": "YaLM-100B",
            "Model Size": "100B",
            "Org": "Yandex",
            "Latest Update": "June 2022",
            "OpenSource Type": "Apache 2.0",
            "content": "Yandex publishes YaLM 100B, the largest GPT-like neural network in open source.",
            "link": "https://github.com/yandex/YaLM-100B/"
        ],
        [
            "id": "5",
            "LLM name": "UL2",
            "Model Size": "20B",
            "Org": "Google",
            "Latest Update": "October 2022",
            "OpenSource Type": "Apache 2.0",
            "content": "UL2 20B: An Open Source Unified Language Learner.",
            "link": "https://github.com/google-research/google-research/tree/master/ul2"
        ],
        [
            "id": "6",
            "LLM name": "Bloom",
            "Model Size": "176B",
            "Org": "BigScience",
            "Latest Update": "November 2022",
            "OpenSource Type": "OpenRAIL-M v1",
            "content": "BLOOM: A 176B-Parameter Open-Access Multilingual Language Model.",
            "link": "https://huggingface.co/bigscience/bloom"
        ],
        [
            "id": "7",
            "LLM name": "ChatGLM",
            "Model Size": "6B",
            "Org": "THUDM",
            "Latest Update": "March 2023",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "ChatGLM: Open bilingual chat model with 6B parameters.",
            "link": "https://github.com/THUDM/ChatGLM-6B/blob/main/README_en.md"
        ],
        [
            "id": "8",
            "LLM name": "Cerebras-GPT",
            "Model Size": "13B",
            "Org": "Cerebras",
            "Latest Update": "March 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Cerebras-GPT: A Family of Open, Compute-efficient, Large Language Models.",
            "link": "https://huggingface.co/cerebras/Cerebras-GPT-13B"
        ],
        [
            "id": "9",
            "LLM name": "Open Assistant",
            "Model Size": "12B",
            "Org": "LAION",
            "Latest Update": "March 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Democratizing Large Language Model Alignment with Pythia family.",
            "link": "https://huggingface.co/OpenAssistant/oasst-sft-4-pythia-12b-epoch-3.5"
        ],
        [
            "id": "10",
            "LLM name": "Pythia",
            "Model Size": "12B",
            "Org": "EleutherAI",
            "Latest Update": "April 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Pythia: A Suite for Analyzing Large Language Models Across Training and Scaling",
            "link": "https://huggingface.co/EleutherAI/pythia-12b"
        ],
        [
            "id": "11",
            "LLM name": "Dolly",
            "Model Size": "12B",
            "Org": "Databricks",
            "Latest Update": "April 2023",
            "OpenSource Type": "MIT",
            "content": "Free Dolly: Introducing the World's First Truly Open Instruction-Tuned LLM.",
            "link": "https://huggingface.co/databricks/dolly-v2-12b"
        ],
        [
            "id": "12",
            "LLM name": "StableLM-Alpha",
            "Model Size": "65B",
            "Org": "Stability AI",
            "Latest Update": "April 2023",
            "OpenSource Type": "CC BY-SA-4.0",
            "content": "Stability AI Launches the First of its StableLM Suite of Language Models.",
            "link": "https://huggingface.co/stabilityai/stablelm-base-alpha-7b"
        ],
        [
            "id": "13",
            "LLM name": "FastChat-T5",
            "Model Size": "3B",
            "Org": "LMSYS",
            "Latest Update": "April 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Compact and commercial-friendly chatbot.",
            "link": "https://huggingface.co/lmsys/fastchat-t5-3b-v1.0"
        ],
        [
            "id": "14",
            "LLM name": "DLite",
            "Model Size": "1.5B",
            "Org": "AI Squared",
            "Latest Update": "May 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Announcing DLite V2: Lightweight, Open LLMs That Can Run Anywhere.",
            "link": "https://medium.com/ai-squared/announcing-dlite-v2-lightweight-open-llms-that-can-run-anywhere-a852e5978c6e"
        ],
        [
            "id": "15",
            "LLM name": "h2oGPT",
            "Model Size": "20B",
            "Org": "H2O.ai",
            "Latest Update": "May 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Building the World's Best Open-Source Large Language Model: H2O.ai's Journey.",
            "link": "https://github.com/h2oai/h2ogpt"
        ],
        [
            "id": "16",
            "LLM name": "MPT-7B",
            "Model Size": "7B",
            "Org": "MosaicML",
            "Latest Update": "May 2023",
            "OpenSource Type": "Apache 2.0, CC BY-SA-3.0",
            "content": "Introducing MPT-7B: A New Standard for Open-Source, Commercially Usable LLMs.",
            "link": "https://huggingface.co/mosaicml/mpt-7b"
        ],
        [
            "id": "17",
            "LLM name": "RedPajama-INCITE",
            "Model Size": "7B",
            "Org": "Together",
            "Latest Update": "May 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Releasing 3B and 7B RedPajama-INCITE family of models.",
            "link": "https://huggingface.co/togethercomputer/RedPajama-INCITE-7B-Base"
        ],
        [
            "id": "18",
            "LLM name": "OpenLLaMA",
            "Model Size": "13B",
            "Org": "OpenLM",
            "Latest Update": "May 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "OpenLLaMA: An Open Reproduction of LLaMA.",
            "link": "https://huggingface.co/openlm-research/open_llama_13b"
        ],
        [
            "id": "19",
            "LLM name": "Falcon",
            "Model Size": "180B",
            "Org": "TII",
            "Latest Update": "May 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "The RefinedWeb Dataset for Falcon LLM: Outperforming Curated Corpora with Web Data.",
            "link": "https://huggingface.co/tiiuae/falcon-180B"
        ],
        [
            "id": "20",
            "LLM name": "LLaMA 2",
            "Model Size": "70B",
            "Org": "Meta",
            "Latest Update": "June 2023",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Llama 2: Open Foundation and Fine-Tuned Chat Models.",
            "link": "https://huggingface.co/meta-llama/Llama-2-70b"
        ],
        [
            "id": "21",
            "LLM name": "ChatGLM2",
            "Model Size": "6B",
            "Org": "THUDM",
            "Latest Update": "June 2023",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "ChatGLM2-6B: Enhanced bilingual chat model with improved performance.",
            "link": "https://huggingface.co/THUDM/chatglm2-6b"
        ],
        [
            "id": "22",
            "LLM name": "Llama Scout",
            "Model Size": "17B",
            "Org": "Meta",
            "Latest Update": "April 2025",
            "OpenSource Type": "Apache 2.0",
            "content": "Mixture-of-experts (MoE) architecture and fusion native multimodality.",
            "link": "https://huggingface.co/meta-llama/Llama-4-Scout-17B-16E"
        ],
        [
            "id": "23",
            "LLM name": "Jais-13b",
            "Model Size": "13B",
            "Org": "Core42",
            "Latest Update": "August 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Jais and Jais-chat: Arabic-Centric Foundation and Instruction-Tuned Open Generative Large Language Models.",
            "link": "https://huggingface.co/core42/jais-13b"
        ],
        [
            "id": "24",
            "LLM name": "OpenHermes",
            "Model Size": "13B",
            "Org": "Nous Research",
            "Latest Update": "September 2023",
            "OpenSource Type": "MIT",
            "content": "OpenHermes: Open access chat LLM with improved instruction following.",
            "link": "https://llm.extractum.io/model/teknium%2FOpenHermes-2.5-Mistral-7B,4i77pGfmntbDczv7CzizSk"
        ],
        [
            "id": "25",
            "LLM name": "OpenLM",
            "Model Size": "7B",
            "Org": "ML Foundations",
            "Latest Update": "September 2023",
            "OpenSource Type": "MIT",
            "content": "Open LM: A minimal but performative language modeling repository.",
            "link": "https://github.com/mlfoundations/open_lm"
        ],
        [
            "id": "26",
            "LLM name": "Mistral 7B",
            "Model Size": "7B",
            "Org": "Mistral AI",
            "Latest Update": "September 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Mistral 7B: A new state-of-the-art open model.",
            "link": "https://huggingface.co/mistralai/Mistral-7B-Instruct-v0.1"
        ],
        [
            "id": "27",
            "LLM name": "ChatGLM3",
            "Model Size": "6B",
            "Org": "THUDM",
            "Latest Update": "October 2023",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "ChatGLM3: Enhanced multilingual chat model with improved performance.",
            "link": "https://huggingface.co/THUDM/chatglm3-6b"
        ],
        [
            "id": "28",
            "LLM name": "Skywork",
            "Model Size": "13B",
            "Org": "Skywork AI",
            "Latest Update": "October 2023",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Skywork: A strong foundation model with math capabilities.",
            "link": "https://huggingface.co/Skywork/Skywork-13B-Base"
        ],
        [
            "id": "29",
            "LLM name": "Jais-30b",
            "Model Size": "30B",
            "Org": "Core42",
            "Latest Update": "October 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Jais-30B: Advancing Arabic language capabilities.",
            "link": "https://huggingface.co/core42/jais-30b-v1"
        ],
        [
            "id": "30",
            "LLM name": "Yi-34B",
            "Model Size": "34B",
            "Org": "01.AI",
            "Latest Update": "November 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Yi Series: High-performance open foundation models.",
            "link": "https://huggingface.co/01-ai/Yi-34B"
        ],
        [
            "id": "31",
            "LLM name": "Mixtral-8x7B",
            "Model Size": "47B",
            "Org": "Mistral AI",
            "Latest Update": "December 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Mixtral: A Sparse Mixture of Experts.",
            "link": "https://huggingface.co/mistralai/Mixtral-8x7B-v0.1"
        ],
        [
            "id": "32",
            "LLM name": "Solar-10.7B",
            "Model Size": "10.7B",
            "Org": "Upstage",
            "Latest Update": "December 2023",
            "OpenSource Type": "Apache 2.0",
            "content": "Solar: Optimized for both English and Code.",
            "link": "https://huggingface.co/upstage/SOLAR-10.7B-v1.0"
        ],
        [
            "id": "33",
            "LLM name": "DeepSeek",
            "Model Size": "67B",
            "Org": "DeepSeek",
            "Latest Update": "December 2023",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "DeepSeek LLM: Specialized in Code Generation.",
            "link": "https://github.com/deepseek-ai/deepseek-LLM"
        ],
        [
            "id": "34",
            "LLM name": "Phi-2",
            "Model Size": "2.7B",
            "Org": "Microsoft",
            "Latest Update": "December 2023",
            "OpenSource Type": "MIT",
            "content": "Phi-2: Small Language Model with Amazing Capabilities.",
            "link": "https://huggingface.co/microsoft/phi-2"
        ],
        [
            "id": "35",
            "LLM name": "Nous-Hermes-2",
            "Model Size": "13B",
            "Org": "Nous Research",
            "Latest Update": "January 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "Nous-Hermes-2: Enhanced Instruction Following.",
            "link": "https://huggingface.co/NousResearch/Nous-Hermes-2-Yi-34b"
        ],
        [
            "id": "36",
            "LLM name": "StableLM 2",
            "Model Size": "12B",
            "Org": "Stability AI",
            "Latest Update": "January 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "StableLM 2: Next Generation Language Model.",
            "link": "https://stability.ai/news/introducing-stable-lm-2-12b"
        ],
        [
            "id": "37",
            "LLM name": "Salamadra 2B",
            "Model Size": "2B",
            "Org": "Mistral AI",
            "Latest Update": "May 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "Decoder-only transformer model trained across 35 languages.",
            "link": "https://huggingface.co/BSC-LT/salamandra-2b"
        ],
        [
            "id": "38",
            "LLM name": "RWKV 5",
            "Model Size": "7B",
            "Org": "BlinkDL",
            "Latest Update": "January 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "RWKV 5: Advanced RNN-based language model.",
            "link": "https://github.com/BlinkDL/RWKV-LM"
        ],
        [
            "id": "39",
            "LLM name": "OLMo",
            "Model Size": "7B",
            "Org": "AI2",
            "Latest Update": "February 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "A truly open language model with comprehensive documentation.",
            "link": "https://huggingface.co/allenai/OLMo-7B"
        ],
        [
            "id": "40",
            "LLM name": "Qwen1.5",
            "Model Size": "72B",
            "Org": "Alibaba",
            "Latest Update": "February 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Introducing Qwen1.5: Advanced multilingual capabilities.",
            "link": "https://huggingface.co/Qwen/Qwen1.5-0.5B"
        ],
        [
            "id": "41",
            "LLM name": "LWM",
            "Model Size": "1M",
            "Org": "LargeWorldModel",
            "Latest Update": "February 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Large World Model with extended context length.",
            "link": "https://github.com/LargeWorldModel/LWM"
        ],
        [
            "id": "42",
            "LLM name": "Gemma",
            "Model Size": "7B",
            "Org": "Google",
            "Latest Update": "February 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Introducing Gemma: Google's open model series.",
            "link": "https://huggingface.co/google/gemma-7b"
        ],
        [
            "id": "43",
            "LLM name": "DeepSeek R1",
            "Model Size": "70B",
            "Org": "DeepSeek",
            "Latest Update": "January 2025",
            "OpenSource Type": "MIT",
            "content": "Uses MoE architecture for efficient, scalable AI.",
            "link": "https://huggingface.co/deepseek-ai/DeepSeek-R1"
        ],
        [
            "id": "44",
            "LLM name": "Qwen1.5 MoE",
            "Model Size": "14.3B",
            "Org": "Alibaba",
            "Latest Update": "March 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Matching 7B Model Performance with 1/3 Activated Parameters.",
            "link": "https://huggingface.co/Qwen/Qwen1.5-MoE"
        ],
        [
            "id": "45",
            "LLM name": "Jamba 0.1",
            "Model Size": "52B",
            "Org": "AI21 Labs",
            "Latest Update": "March 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "Groundbreaking SSM-Transformer Model.",
            "link": "https://www.ai21.com/blog/introducing-jamba"
        ],
        [
            "id": "46",
            "LLM name": "Qwen1.5 32B",
            "Model Size": "32B",
            "Org": "Alibaba",
            "Latest Update": "April 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Fitting the Capstone of the Qwen1.5 Language Model Series.",
            "link": "https://huggingface.co/Qwen/Qwen1.5-32B"
        ],
        [
            "id": "47",
            "LLM name": "Mamba-7B",
            "Model Size": "7B",
            "Org": "Toyota Research",
            "Latest Update": "April 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "State-space model with RNN architecture.",
            "link": "https://huggingface.co/tiiuae/falcon-mamba-7b"
        ],
        [
            "id": "48",
            "LLM name": "Mixtral8x22B",
            "Model Size": "141B",
            "Org": "Mistral AI",
            "Latest Update": "April 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "Cheaper, Better, Faster, Stronger: Advanced mixture of experts model.",
            "link": "https://huggingface.co/mistralai/Mixtral-8x7B-v0.1"
        ],
        [
            "id": "49",
            "LLM name": "Llama 3",
            "Model Size": "70B",
            "Org": "Meta",
            "Latest Update": "April 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Meta's latest open model with enhanced capabilities.",
            "link": "https://www.valuecoders.com/blog/ai-ml/what-is-meta-llama-3-large-language-model"
        ],
        [
            "id": "50",
            "LLM name": "Phi-3 Mini",
            "Model Size": "3.8B",
            "Org": "Microsoft",
            "Latest Update": "April 2024",
            "OpenSource Type": "MIT",
            "content": "Redefining what's possible with small language models.",
            "link": "https://ollama.com/library/phi3:mini"
        ],
        [
            "id": "51",
            "LLM name": "OpenELM",
            "Model Size": "3B",
            "Org": "Apple",
            "Latest Update": "April 2024",
            "OpenSource Type": "Custom Open License",
            "content": "Efficient Language Model Family with Open Training Framework.",
            "link": "https://huggingface.co/apple/OpenELM"
        ],
        [
            "id": "52",
            "LLM name": "Snowflake Arctic",
            "Model Size": "480B",
            "Org": "Snowflake",
            "Latest Update": "April 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "The Best LLM for Enterprise AI — Efficiently Intelligent, Truly Open.",
            "link": "https://huggingface.co/Snowflake/snowflake-arctic-embed-m"
        ],
        [
            "id": "53",
            "LLM name": "RWKV 6 v2.1",
            "Model Size": "7B",
            "Org": "BlinkDL",
            "Latest Update": "May 2024",
            "OpenSource Type": "Apache 2.0",
            "content": "Advanced RNN-based language model with improved performance.",
            "link": "https://github.com/BlinkDL/RWKV-LM"
        ],
        [
            "id": "54",
            "LLM name": "DeepSeek-V2",
            "Model Size": "236B",
            "Org": "DeepSeek AI",
            "Latest Update": "May 2024",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "A Strong, Economical, and Efficient Mixture-of-Experts Language Model.",
            "link": "https://huggingface.co/deepseek-ai/deepseek-moe-16b-base"
        ],
        [
            "id": "55",
            "LLM name": "Phi-4",
            "Model Size": "14B",
            "Org": "Microsoft",
            "Latest Update": "December 2024",
            "OpenSource Type": "MIT",
            "content": "Advanced reasoning in a compact and efficient model.",
            "link": "https://huggingface.co/microsoft/phi-4"
        ],
        [
            "id": "56",
            "LLM name": "YuLan-Mini",
            "Model Size": "14B",
            "Org": "YuLan Team",
            "Latest Update": "December 2024",
            "OpenSource Type": "MIT",
            "content": "YuLan-Mini: An Open Data-efficient Language Model.",
            "link": "https://huggingface.co/yulan-team/YuLan-Mini"
        ],
        [
            "id": "57",
            "LLM name": "Selene Mini",
            "Model Size": "8B",
            "Org": "Atla AI",
            "Latest Update": "January 2025",
            "OpenSource Type": "Apache 2.0",
            "content": "Atla Selene Mini: A General Purpose Evaluation Model.",
            "link": "https://huggingface.co/AtlaAI/Selene-1-Mini-Llama-3.1-8B"
        ],
        [
            "id": "58",
            "LLM name": "Cohere Command",
            "Model Size": "52B",
            "Org": "Cohere",
            "Latest Update": "January 2025",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Advanced language model optimized for enterprise use cases.",
            "link": "https://cohere.com/models/command"
        ],
        [
            "id": "59",
            "LLM name": "Inflection-2.5",
            "Model Size": "380B",
            "Org": "Inflection AI",
            "Latest Update": "January 2025",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Pushing the boundaries of conversational AI.",
            "link": "https://inflection.ai/inflection-2"
        ],
        [
            "id": "60",
            "LLM name": "Falcon-11B",
            "Model Size": "11B",
            "Org": "TII",
            "Latest Update": "February 2025",
            "OpenSource Type": "Apache 2.0",
            "content": "Enhanced version of Falcon with improved reasoning.",
            "link": "https://huggingface.co/tiiuae/falcon-11B"
        ],
        [
            "id": "61",
            "LLM name": "SteerLM",
            "Model Size": "7B",
            "Org": "Intel",
            "Latest Update": "February 2025",
            "OpenSource Type": "Apache 2.0",
            "content": "Controllable language model with enhanced steering capabilities.",
            "link": "https://github.com/intel/neural-compressor"
        ],
        [
            "id": "62",
            "LLM name": "Gemini Ultra 2",
            "Model Size": "3.5T",
            "Org": "Google",
            "Latest Update": "March 2025",
            "OpenSource Type": "Proprietary",
            "content": "Next generation multimodal AI system.",
            "link": "https://deepmind.google/technologies/gemini/"
        ],
        [
            "id": "63",
            "LLM name": "Mistral Large",
            "Model Size": "32B",
            "Org": "Mistral AI",
            "Latest Update": "March 2025",
            "OpenSource Type": "Apache 2.0",
            "content": "Advanced reasoning with enhanced multilingual support.",
            "link": "https://mistral.ai/news/mistral-large/"
        ],
        [
            "id": "65",
            "LLM name": "DeepSeek V2-Lite",
            "Model Size": "16B",
            "Org": "DeepSeek",
            "Latest Update": "March 2025",
            "OpenSource Type": "Apache 2.0",
            "content": "Mid-size scale mixture of experts model.",
            "link": "https://github.com/deepseek-ai/DeepSeek-V2"
        ],
        [
            "id": "71",
            "LLM name": "Gemma-2",
            "Model Size": "8B",
            "Org": "Google",
            "Latest Update": "May 2025",
            "OpenSource Type": "Custom with Usage Restrictions",
            "content": "Enhanced version of Gemma with improved performance.",
            "link": "https://huggingface.co/google/gemma-2b"
        ],
        [
            "id": "75",
            "LLM name": "StarCoder",
            "Model Size": "15B",
            "Org": "BigCode",
            "Latest Update": "May 2023",
            "OpenSource Type": "OpenRAIL-M v1",
            "content": "A State-of-the-Art LLM for Code with 8K context window.",
            "link": "https://huggingface.co/bigcode/starcoder"
        ],
        [
            "id": "76",
            "LLM name": "StarChat Alpha",
            "Model Size": "16B",
            "Org": "HuggingFace",
            "Latest Update": "May 2023",
            "OpenSource Type": "OpenRAIL-M v1",
            "content": "Creating a Coding Assistant with StarCoder.",
            "link": "https://huggingface.co/HuggingFaceH4/starchat-alpha"
        ],
        [
            "id": "77",
            "LLM name": "Replit Code",
            "Model Size": "3B",
            "Org": "Replit",
            "Latest Update": "May 2023",
            "OpenSource Type": "CC BY-SA-4.0",
            "content": "Training a SOTA Code LLM in 1 week with infinite context window.",
            "link": "https://huggingface.co/replit/replit-code-v1-3b"
        ],
        [
            "id": "78",
            "LLM name": "CodeT5+",
            "Model Size": "16B",
            "Org": "Salesforce",
            "Latest Update": "May 2023",
            "OpenSource Type": "BSD-3-Clause",
            "content": "Open Code LLMs for Code Understanding and Generation.",
            "link": "https://github.com/salesforce/CodeT5/tree/main/CodeT5+"
        ],
        [
            "id": "79",
            "LLM name": "Code Llama",
            "Model Size": "34B",
            "Org": "Meta",
            "Latest Update": "August 2023",
            "OpenSource Type": "Apache",
            "content": "Open Foundation Models for Code. Available in multiple sizes from 7B to 34B parameters.",
            "link": "https://github.com/facebookresearch/codellama"
        ]
    ]

    // Add orientation state
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var selectedModelSizesSet = Set<OptionModel>()
    @State private var selectedYearsSet = Set<OptionModel>()

    var body: some View {
        NavigationView {
            ZStack {
                backgroundLayer
                mainContentLayer
                loadingLayer
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sheet(item: $presentedURL) { url in
            SafariView(url: url)
        }
        .onAppear(perform: handleOnAppear)
        .onAppear {
            // Load initial values from SceneStorage
            if let data = try? JSONDecoder().decode([String].self, from: selectedModelSizesData) {
                selectedModelSizesSet = Set(data.map { OptionModel(name: $0) })
            }
            if let data = try? JSONDecoder().decode([String].self, from: selectedYearsData) {
                selectedYearsSet = Set(data.map { OptionModel(name: $0) })
            }
        }
    }
    
    // MARK: - View Components
    
    private var backgroundLayer: some View {
        Image("yellow_blue_waves")
            .resizable()
            .scaledToFill()
            .edgesIgnoringSafeArea(.all)
    }
    
    private var mainContentLayer: some View {
        VStack(spacing: 0) {
            optionsCard
            cardListView
        }
        .opacity(isLoading ? 0 : 1)
    }
    
    private var optionsCard: some View {
        VStack(spacing: 8) {
            optionsTopBar
            optionsCardContent
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground).opacity(0.8))
        .cornerRadius(15)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
    }
    
    private var optionsTopBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Spacer()
                if !isOptionsCardFlipped {
                    Text("License Type")
                        .font(.headline)
                        .padding(.top, 10)
                    expandButton
                        .padding(.top, 10)
                }
                Spacer()
            }
            
            // Only show license picker when not flipped
            if !isOptionsCardFlipped {
                FavoriteOptionPicker(
                    selectedOptions: Binding(
                        get: { self.selectedOpenSourceTypes },
                        set: { newValue in
                            if let encoded = try? JSONEncoder().encode(Array(newValue.map { $0.name })) {
                                self.selectedOpenSourceTypesData = encoded
                            }
                        }
                    ),
                    candidates: openSourceOptions
                )
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var optionsCardContent: some View {
        ZStack {
            // Front of options card (calculator)
            VStack(alignment: .leading, spacing: 10) {
                if isOptionsCardFlipped {
                    MemoryCalculatorView(
                        modelSizeB: $modelSizeB,
                        precision: $precision,
                        isFlipped: $isOptionsCardFlipped
                    )
                }
            }
            .opacity(isOptionsCardFlipped ? 1 : 0)
            
            // Back of options card (filters)
            VStack(spacing: 10) {
                if !isOptionsCardFlipped {
                    if isOptionsExpanded {
                        Text("Model Size")
                            .font(.headline)
                            .padding(.top, 2)
                        FavoriteOptionPicker(
                            selectedOptions: $selectedModelSizesSet,
                            candidates: modelSizeOptions
                        )
                        .onChange(of: selectedModelSizesSet) { newValue in
                            if let encoded = try? JSONEncoder().encode(Array(newValue.map { $0.name })) {
                                selectedModelSizesData = encoded
                            }
                        }
                        
                        Text("Time Period")
                            .font(.headline)
                            .padding(.top, 2)
                        FavoriteOptionPicker(
                            selectedOptions: $selectedYearsSet,
                            candidates: yearOptions,
                            isSingleSelection: true
                        )
                        .onChange(of: selectedYearsSet) { newValue in
                            if let encoded = try? JSONEncoder().encode(Array(newValue.map { $0.name })) {
                                selectedYearsData = encoded
                            }
                        }
                        
                        Spacer()
                            .frame(height: 3)  // Space above icons
                        
                        // Count circle and flip button row
                        HStack {
                            // Flip button
                            Button(action: {
                                // Add haptic feedback
                                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                                impactMed.impactOccurred()
                                
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    isOptionsCardFlipped.toggle()
                                }
                            }) {
                                Image(systemName: "arrow.2.squarepath")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.primary)
                                    .padding(6)
                                    .background(Color(.systemBackground).opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 2)
                            .padding(.bottom, 2)
                            
                            Spacer()
                            
                            // Count circle
                            ZStack {
                                Circle()
                                    .stroke(darkOliveGreen.opacity(0.2), lineWidth: 6)
                                    .frame(height: 30)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(filteredData.count) / CGFloat(sampleData.count))
                                    .stroke(darkOliveGreen.opacity(0.6), lineWidth: 6)
                                    .frame(height: 30)
                                    .rotationEffect(.degrees(-90))
                                
                                Circle()
                                    .fill(darkOliveGreen.opacity(0.1))
                                    .frame(height: 44)
                                
                                Text("\(filteredData.count)")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(darkOliveGreen)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)
                    }
                }
            }
            .frame(height: isOptionsExpanded ? 216 : 25)
            .opacity(isOptionsCardFlipped ? 0 : 1)
            // Change rotation to make filters appear right-side up when flipped
            .rotation3DEffect(
                .degrees(isOptionsCardFlipped ? 180 : 0),  // Changed from (isOptionsCardFlipped ? 0 : 180)
                axis: (x: 1.0, y: 0.0, z: 0.0))
        }
        .animation(.easeInOut(duration: 0.6), value: isOptionsExpanded)
    }
    
    private var cardListView: some View {
        ScrollView {
            LazyVStack(spacing: 25) {
                if filteredData.isEmpty {
                    // No results message card
                    VStack(alignment: .center, spacing: 4) {
                        Text("Sparse results, please retry options.")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .modifier(GlassCardStyle())
                    .shadow(radius: 1)
                    .padding(.horizontal)
                } else {
                    let columns = horizontalSizeClass == .compact ? 1 : 2
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 60), count: columns), spacing: 60) {
                        ForEach(0..<filteredData.count, id: \.self) { index in
                            let item = filteredData[index]
                            VStack(spacing: 0) {
                                LLMCardView(
                                    item: item,
                                    isFlipped: isCardFlipped(item["id"] as? String ?? ""),
                                    onFlip: {
                                        withAnimation(.easeInOut(duration: 0.6)) {
                                            if isCardFlipped(item["id"] as? String ?? "") {
                                                flippedCards.remove(item["id"] as? String ?? "")
                                            } else {
                                                flippedCards.insert(item["id"] as? String ?? "")
                                            }
                                        }
                                    },
                                    onLink: { url in
                                        presentedURL = url
                                    }
                                )
                                .shadow(radius: 1)
                                .padding(.horizontal)
                                .frame(height: 74)
                                .frame(maxWidth: horizontalSizeClass == .compact ? 
                                       min(383, ScreenHelper.width * 1.15) : 
                                       .infinity)
                                
                                Color.clear
                                    .frame(height: 78)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: horizontalSizeClass == .compact ? 
                   min(383, ScreenHelper.width * 1.15) : 
                   .infinity)
        }
        .mask {
            Rectangle()
                .overlay(alignment: .bottom) {
                    ScrollMask(isTop: false)
                }
        }
    }
    
    private var expandButton: some View {
        Button(action: {
            withAnimation(.spring()) {
                isOptionsExpanded.toggle()
            }
        }) {
            Image(systemName: "slider.horizontal.3")
                .resizable()
                .frame(width: 10, height: 10)
                .foregroundColor(.primary)
                .padding(5)
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(10)
                .rotationEffect(.degrees(isOptionsExpanded ? 0 : 180))
        }
        
    }
    
    // MARK: - Helper Methods
    
    private func handleOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if !isLoading {
                HStack(spacing: 4) {
                    Text("A.I.")
                        .font(.system(size: 24))
                        .fontWeight(.bold)
                    
                    Image("neural_network")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("Model Viewscope")
                        .font(.system(size: 24))
                        .fontWeight(.bold)
                }
                .foregroundColor(.primary)
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MM/yy"
            return dateFormatter.string(from: date)
        }
        return dateString
    }

    private func calculateOpacity(for geometry: GeometryProxy) -> Double {
        let scrollViewHeight = ScreenHelper.height
        let position = geometry.frame(in: .global).minY
        let distanceFromBottom = scrollViewHeight - position - 20  // Adjusted to account for bottom padding
        
        if distanceFromBottom < 200 {  // Increased from 20 to 100 for longer fade distance
            return max(0, min(1, distanceFromBottom / 200))  // Adjusted divisor to match fade distance
        }
        return 1
    }

    private var selectedOpenSourceTypes: Set<OptionModel> {
        get {
            if let decoded = try? JSONDecoder().decode([String].self, from: selectedOpenSourceTypesData) {
                return Set(decoded.map { OptionModel(name: $0) })
            }
            return []
        }
        set {
            if let encoded = try? JSONEncoder().encode(Array(newValue.map { $0.name })) {
                selectedOpenSourceTypesData = encoded
            }
        }
    }
    
    private var selectedModelSizes: Set<OptionModel> {
        get {
            if let data = try? JSONDecoder().decode([String].self, from: selectedModelSizesData) {
                return Set(data.map { OptionModel(name: $0) })
            }
            return []
        }
        set {
            if let encoded = try? JSONEncoder().encode(Array(newValue.map { $0.name })) {
                selectedModelSizesData = encoded
            }
        }
    }
    
    private var selectedYears: Set<OptionModel> {
        get {
            if let data = try? JSONDecoder().decode([String].self, from: selectedYearsData) {
                return Set(data.map { OptionModel(name: $0) })
            }
            return []
        }
        set {
            if let encoded = try? JSONEncoder().encode(Array(newValue.map { $0.name })) {
                selectedYearsData = encoded
            }
        }
    }

    private func isCardFlipped(_ id: String) -> Bool {
        return flippedCards.contains(id)
    }

    // Add this after the other view components
    private var loadingLayer: some View {
        Group {
            if isLoading {
                VStack {
                    Image("ai_model_viewscope")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: "#FFFFE0"))  // Light yellow background
                .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

struct OptionModel: Identifiable, Hashable, Codable {
    var id: UUID = .init()
    var name: String
    
    // Add custom hash and equals implementation to compare by name
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: OptionModel, rhs: OptionModel) -> Bool {
        return lhs.name == rhs.name
    }
}

struct FavoriteOptionPicker: View {
    @Binding var selectedOptions: Set<OptionModel>
    var candidates: [OptionModel]
    var isSingleSelection: Bool = false
    var isSelectionRequired: Bool = false
    var minSelection: Int = 0
    var maxSelection: Int = Int.max
    
    private func isSelected(_ option: OptionModel) -> Bool {
        return selectedOptions.contains(option)
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 7) {
            ForEach(candidates) { option in
                Button(action: {
                    setSelectedOption(option: option)
                }) {
                    HStack {
                        Text(option.name)
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if isSelected(option) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(isSelected(option) ? Color.green.opacity(0.2) : Color(.systemGray6))
                    .foregroundColor(isSelected(option) ? .green : .primary)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected(option) ? Color.green : Color.gray.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: min(600, ScreenHelper.width * 0.95))
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func setSelectedOption(option: OptionModel) {
        if selectedOptions.contains(option) {
            if selectedOptions.count > minSelection {
                selectedOptions.remove(option)
                if isSelectionRequired && selectedOptions.isEmpty {
                    selectedOptions.insert(option)
                }
            }
        } else {
            if isSingleSelection {
                selectedOptions = [option]
            } else if selectedOptions.count < maxSelection {
                selectedOptions.insert(option)
            }
        }
    }
}

struct GlassCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.2),
                                Color.orange.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(Color.white.opacity(0.7))
            .cornerRadius(10)
    }
}

// First, let's define the color
let darkOliveGreen = Color(hex: "#454D32")

// Add this extension at the bottom of your file:
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// First, add this color definition near the top where darkOliveGreen is defined
let darkBlue = Color(hex: "#000080")  // Navy blue color
