//
//  ContentView.swift
//  InfoCard
//
//  Created by Caner Davarcı on 7.06.2026.
//

import SwiftUI
import UIKit
import Combine
import LocalAuthentication
import AVFoundation
import Vision
import UniformTypeIdentifiers

// MARK: - Card Model
// MARK: - Card Provider Enum
enum CardProvider: String, CaseIterable, Codable, Identifiable {
    case visa
    case mastercard
    case troy
    case unknown
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .troy: return "Troy"
        case .unknown: return "Belirtilmemiş"
        }
    }
    
    static func detect(from cardNumber: String) -> CardProvider {
        let digits = cardNumber.filter { $0.isNumber }
        if digits.hasPrefix("4") {
            return .visa
        } else if digits.hasPrefix("51") || digits.hasPrefix("52") || digits.hasPrefix("53") || digits.hasPrefix("54") || digits.hasPrefix("55") ||
                  digits.hasPrefix("222") || digits.hasPrefix("223") || digits.hasPrefix("224") || digits.hasPrefix("225") || digits.hasPrefix("226") || digits.hasPrefix("227") || digits.hasPrefix("23") || digits.hasPrefix("24") || digits.hasPrefix("25") || digits.hasPrefix("26") || digits.hasPrefix("27") {
            return .mastercard
        } else if digits.hasPrefix("9792") {
            return .troy
        }
        return .unknown
    }
}

// MARK: - Card Provider Logo View
struct CardProviderLogo: View {
    let provider: CardProvider
    var scale: CGFloat = 1.0
    
    var body: some View {
        switch provider {
        case .visa:
            Text("VISA")
                .font(.system(size: 16 * scale, weight: .black, design: .rounded))
                .italic()
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        case .mastercard:
            ZStack {
                Circle()
                    .fill(Color(hex: "EB001B")) // Mastercard Red
                    .frame(width: 18 * scale, height: 18 * scale)
                    .offset(x: -5 * scale)
                Circle()
                    .fill(Color(hex: "F79E1B").opacity(0.9)) // Mastercard Yellow
                    .frame(width: 18 * scale, height: 18 * scale)
                    .offset(x: 5 * scale)
            }
            .frame(width: 30 * scale, height: 18 * scale)
        case .troy:
            HStack(spacing: 1 * scale) {
                Text("tr")
                    .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "00C6FF")) // Troy Cyan
                Text("oy")
                    .font(.system(size: 15 * scale, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "F79E1B")) // Troy Yellow/Orange
            }
            .italic()
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        case .unknown:
            Image(systemName: "creditcard.fill")
                .font(.system(size: 15 * scale))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

// MARK: - Card Model
struct Card: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var number: String // raw 16-digit number
    var expiry: String // MM/YY
    var cvv: String // 3 or 4 digits
    var theme: CardTheme
    var customColorHex: String? // User-selected custom color hex
    var holderName: String? // Optional cardholder name
    var provider: CardProvider = .unknown
    
    enum CodingKeys: String, CodingKey {
        case id, name, number, expiry, cvv, theme, customColorHex, holderName, provider
    }
    
    init(id: UUID = UUID(), name: String, number: String, expiry: String, cvv: String, theme: CardTheme, customColorHex: String? = nil, holderName: String? = nil, provider: CardProvider = .unknown) {
        self.id = id
        self.name = name
        self.number = number
        self.expiry = expiry
        self.cvv = cvv
        self.theme = theme
        self.customColorHex = customColorHex
        self.holderName = holderName
        self.provider = provider
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        number = try container.decode(String.self, forKey: .number)
        expiry = try container.decode(String.self, forKey: .expiry)
        cvv = try container.decode(String.self, forKey: .cvv)
        theme = try container.decode(CardTheme.self, forKey: .theme)
        customColorHex = try container.decodeIfPresent(String.self, forKey: .customColorHex)
        holderName = try container.decodeIfPresent(String.self, forKey: .holderName)
        provider = try container.decodeIfPresent(CardProvider.self, forKey: .provider) ?? .unknown
    }
}

// MARK: - Card Theme Enum
enum CardTheme: String, CaseIterable, Codable, Identifiable {
    case purplePink
    case blueTeal
    case orangeRed
    case midnightGold
    case emeraldMint
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .purplePink: return "Neon Nebula"
        case .blueTeal: return "Ocean Breeze"
        case .orangeRed: return "Sunset Flame"
        case .midnightGold: return "Obsidian Gold"
        case .emeraldMint: return "Emerald Mint"
        }
    }
    
    var colors: [Color] {
        switch self {
        case .purplePink:
            return [Color(hex: "6D28D9"), Color(hex: "DB2777")]
        case .blueTeal:
            return [Color(hex: "028090"), Color(hex: "00C6FF")]
        case .orangeRed:
            return [Color(hex: "FF416C"), Color(hex: "FF4B2B")]
        case .midnightGold:
            return [Color(hex: "1F2937"), Color(hex: "111827")]
        case .emeraldMint:
            return [Color(hex: "059669"), Color(hex: "028090")]
        }
    }
}

// MARK: - Card Store
class CardStore: ObservableObject {
    @Published var cards: [Card] = [] {
        didSet {
            saveCards()
        }
    }
    
    private let storageKey = "wallet_cards_storage"
    
    init() {
        loadCards()
    }
    
    func addCard(_ card: Card) {
        cards.append(card)
    }
    
    func deleteCard(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards.remove(at: index)
        }
    }
    
    func updateCard(_ updatedCard: Card) {
        if let index = cards.firstIndex(where: { $0.id == updatedCard.id }) {
            cards[index] = updatedCard
        }
    }
    
    private func saveCards() {
        if let encoded = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadCards() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Card].self, from: data) {
            self.cards = decoded
        } else {
            // Load initial mock cards with holder names and providers
            self.cards = [
                Card(
                    name: "Bonus Gold",
                    number: "4355289948216503",
                    expiry: "12/28",
                    cvv: "324",
                    theme: .purplePink,
                    customColorHex: nil,
                    holderName: "CANER DAVARCI",
                    provider: .visa
                ),
                Card(
                    name: "Maximum Platinum",
                    number: "5412750012984531",
                    expiry: "09/29",
                    cvv: "889",
                    theme: .blueTeal,
                    customColorHex: nil,
                    holderName: "AYSE YILMAZ",
                    provider: .mastercard
                )
            ]
        }
    }
}

// MARK: - Main Wallet View
struct ContentView: View {
    @StateObject private var store = CardStore()
    @Environment(\.scenePhase) private var scenePhase
    
    // Lock/Security state
    #if targetEnvironment(simulator)
    @State private var isUnlocked = true
    #else
    @State private var isUnlocked = false
    #endif
    
    // Edit Mode state
    @State private var isEditing = false
    @State private var wobble = false
    @State private var draggedCard: Card? = nil
    
    // Sheet presentation (single identifiable item prevents race conditions)
    @State private var activeSheet: SheetConfig? = nil
    
    // Toast notification
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastTimer: Timer? = nil
    
    var body: some View {
        ZStack {
            if isUnlocked {
                mainWalletView
                    .transition(.opacity)
            } else {
                LockedView(onUnlock: authenticate)
                    .transition(.opacity)
            }
        }
        .onAppear {
            authenticate()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Relock and request Face ID when coming back from background
                if !isUnlocked {
                    authenticate()
                }
            } else if newPhase == .background {
                // Instantly lock when app backgrounds (disabled on simulator for previews/testing)
                #if !targetEnvironment(simulator)
                isUnlocked = false
                #endif
                isEditing = false // Exit editing on background
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // Main wallet layout view
    private var mainWalletView: some View {
        ZStack {
            // Dark premium background
            Color(hex: "0A0A0C")
                .ignoresSafeArea()
            
            // Glowing ambient lights
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color(hex: "6D28D9").opacity(0.12))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: -80, y: 120)
                    
                    Circle()
                        .fill(Color(hex: "028090").opacity(0.1))
                        .frame(width: 380, height: 380)
                        .blur(radius: 90)
                        .offset(x: geo.size.width - 200, y: geo.size.height - 350)
                }
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Centered Header Area
                    ZStack {
                        // Geometrically Centered Title
                        Text("Cüzdan")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack {
                            // Left: Düzenle Button styled in Liquid Glass Capsule shape
                            Button(action: {
                                triggerHaptic(style: .medium)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditing.toggle()
                                }
                            }) {
                                Text(isEditing ? "Bitti" : "Düzenle")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(isEditing ? Color(hex: "FBBF24") : .white)
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                                    .background(Color.white.opacity(0.06))
                                    .blurBackground(style: .systemUltraThinMaterialDark, shape: Capsule())
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                            }
                            
                            Spacer()
                            
                            // Right: Add Button styled in Liquid Glass Circle shape
                            Button(action: {
                                triggerHaptic(style: .medium)
                                activeSheet = SheetConfig(mode: .add, card: nil)
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.06))
                                    .blurBackground(style: .systemUltraThinMaterialDark, shape: Circle())
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Card List / Stack
                    if store.cards.isEmpty {
                        // Empty State
                        VStack(spacing: 20) {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    Color.white.opacity(0.15),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [8, 8])
                                )
                                .frame(height: 200)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "creditcard.and.123")
                                            .font(.system(size: 38))
                                            .foregroundColor(.white.opacity(0.3))
                                        Text("Kayıtlı kart bulunmamaktadır.")
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.4))
                                        Text("Eklemek için + butonuna dokunun.")
                                            .font(.system(size: 13, design: .rounded))
                                            .foregroundColor(.white.opacity(0.3))
                                    }
                                )
                                .onTapGesture {
                                    triggerHaptic(style: .medium)
                                    activeSheet = SheetConfig(mode: .add, card: nil)
                                }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .transition(.opacity)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(store.cards) { card in
                                CardView(card: card, maskNumber: false) {
                                    if !isEditing {
                                        copyToClipboard(card: card)
                                    }
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 16))
                                .opacity(draggedCard == card ? 0.25 : 1.0)
                                // Wobble animation in Edit mode
                                .rotationEffect(.degrees(isEditing ? (wobble ? 0.7 : -0.7) : 0))
                                .offset(y: isEditing ? (wobble ? 0.4 : -0.4) : 0)
                                .contextMenu {
                                    if !isEditing {
                                        Button(action: {
                                            activeSheet = SheetConfig(mode: .edit, card: card)
                                        }) {
                                            Label("Düzenle", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                store.deleteCard(card)
                                            }
                                        }) {
                                            Label("Sil", systemImage: "trash")
                                        }
                                    }
                                }
                                // Conditional Drag and Drop modifiers activated when in Edit mode
                                .if(isEditing) { view in
                                    view
                                        .onDrag {
                                            triggerHaptic(style: .light)
                                            self.draggedCard = card
                                            return NSItemProvider(object: card.id.uuidString as NSString)
                                        }
                                        .onDrop(of: [.text], delegate: CardDropDelegate(item: card, store: store, draggedItem: $draggedCard))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Toast Notification
            if showToast {
                VStack {
                    Spacer()
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 36)
                }
                .zIndex(1)
            }
        }
        .sheet(item: $activeSheet) { config in
            CardEditSheet(store: store, mode: config.mode, cardToEdit: config.card)
        }
        .onChange(of: isEditing) { newValue in
            if newValue {
                // Trigger wobble timer loop
                withAnimation(Animation.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                    wobble = true
                }
            } else {
                wobble = false
                draggedCard = nil // Reset dragged card to fix persistent opacity fade
            }
        }
    }
    
    // Biometric / FaceID / Device Passcode Authenticator
    private func authenticate() {
        #if targetEnvironment(simulator)
        // Bypass authentication immediately in Simulator builds for hassle-free testing and previews
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            isUnlocked = true
        }
        return
        #endif

        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Kart bilgilerinize güvenli erişim için kimliğinizi doğrulayın."
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isUnlocked = true
                        }
                    } else {
                        isUnlocked = false
                    }
                }
            }
        } else {
            isUnlocked = true
        }
    }
    
    // Copy Action Helper
    private func copyToClipboard(card: Card) {
        UIPasteboard.general.string = card.number
        triggerHaptic(style: .medium)
        
        toastTimer?.invalidate()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            toastMessage = "Kart numarası kopyalandı!"
            showToast = true
        }
        
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                showToast = false
            }
        }
    }
    
    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Drag and Drop Delegate
struct CardDropDelegate: DropDelegate {
    let item: Card
    let store: CardStore
    @Binding var draggedItem: Card?
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem,
              draggedItem != item,
              let fromIndex = store.cards.firstIndex(of: draggedItem),
              let toIndex = store.cards.firstIndex(of: item) else {
            return
        }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            store.cards.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

// MARK: - Conditional View Modifier Helper
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Locked View Component
struct LockedView: View {
    var onUnlock: () -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "0A0A0C")
                .ignoresSafeArea()
            
            // Background ambient glow
            Circle()
                .fill(Color(hex: "6D28D9").opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
            
            VStack(spacing: 28) {
                // Glowing Lock Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "6D28D9"), Color(hex: "DB2777")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: "6D28D9").opacity(0.5), radius: 10)
                }
                .padding(.bottom, 10)
                
                VStack(spacing: 10) {
                    Text("Cüzdan Kilitli")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Kart bilgilerinize güvenli erişim için kimliğinizi doğrulayın.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18, weight: .bold))
                        Text("Kimliği Doğrula")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "6D28D9"), Color(hex: "DB2777")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color(hex: "6D28D9").opacity(0.4), radius: 8, y: 4)
                }
                .padding(.top, 10)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Card View Component
struct CardView: View {
    let card: Card
    var maskNumber: Bool = false // Always show card details (no mask)
    var isPreview: Bool = false
    var onTap: (() -> Void)? = nil
    
    // Tap Animation states
    @State private var isBouncing = false
    @State private var showFlash = false
    @State private var sheenOffsetMultiplier: CGFloat = -0.6
    
    var cardColors: [Color] {
        if let hex = card.customColorHex {
            let baseColor = Color(hex: hex)
            return [baseColor, baseColor.darkened()]
        } else {
            return card.theme.colors
        }
    }
    
    var body: some View {
        ZStack {
            // Premium Gradient Theme Background
            LinearGradient(
                colors: cardColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Metallic/Glassmorphic shine overlay
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Card Decorations
            CardDecorations()
            
            // Diagonal sweep sheen flash effect
            GeometryReader { geo in
                Color.clear
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color(hex: "FBBF24").opacity(0.45),
                                        Color.white.opacity(0.2),
                                        Color(hex: "FBBF24").opacity(0.45),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: geo.size.width * 0.45)
                            .rotationEffect(.degrees(25))
                            .offset(x: geo.size.width * sheenOffsetMultiplier)
                    )
            }
            .clipped()
            .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 0) {
                // Card Name & Chip
                HStack(alignment: .center) {
                    Text(card.name.uppercased())
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .tracking(1.8)
                    
                    Spacer()
                    
                    // Golden Chip Mockup
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFE082"), Color(hex: "FFB300")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 28)
                        .overlay(
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                
                                // Internal Chip details
                                Path { path in
                                    path.move(to: CGPoint(x: 12, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 28))
                                    path.move(to: CGPoint(x: 26, y: 0))
                                    path.addLine(to: CGPoint(x: 26, y: 28))
                                    path.move(to: CGPoint(x: 0, y: 14))
                                    path.addLine(to: CGPoint(x: 38, y: 14))
                                }
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                            }
                        )
                }
                
                Spacer()
                
                // Formatted Card Number
                Text(formattedCardNumber(card.number))
                    .font(.system(size: 21, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .tracking(2.0)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                
                // Cardholder Name: Displayed elegantly between Card Number and Expiry/CVV (only if provided)
                if let holder = card.holderName, !holder.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer()
                    Text(holder.uppercased())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .shadow(color: Color.black.opacity(0.12), radius: 1)
                }
                
                Spacer()
                
                // Expiry & CVV Row
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SON KULLANMA")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.0)
                        Text(card.expiry.isEmpty ? "MM/YY" : card.expiry)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    
                    Spacer()
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CVV")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.0)
                        Text(card.cvv.isEmpty ? "•••" : (maskNumber ? "•••" : card.cvv))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    
                    Spacer()
                    
                    // Card Provider Logo
                    CardProviderLogo(provider: card.provider)
                        .padding(.bottom, 2)
                }
            }
            .padding(22)
        }
        .frame(height: 195)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(showFlash ? Color(hex: "FBBF24") : Color.white.opacity(0.2), lineWidth: showFlash ? 2.5 : 1)
                .shadow(color: Color(hex: "FBBF24").opacity(showFlash ? 0.85 : 0), radius: showFlash ? 10 : 0)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
        .scaleEffect(isBouncing ? 1.045 : 1.0)
        .onTapGesture {
            if !isPreview, let onTap = onTap {
                // Interactive bounce/jump animation
                withAnimation(.spring(response: 0.22, dampingFraction: 0.42, blendDuration: 0)) {
                    isBouncing = true
                }
                
                // Reset flash and sheen silently
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showFlash = false
                    sheenOffsetMultiplier = -0.6
                }
                
                // Trigger border glow
                withAnimation(.linear(duration: 0.52)) {
                    showFlash = true
                }
                
                // Trigger diagonal sweep sheen (left-to-right)
                withAnimation(.linear(duration: 0.52)) {
                    sheenOffsetMultiplier = 1.35
                }
                
                // Bounce back to normal scale
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.42)) {
                        isBouncing = false
                    }
                }
                
                // Reset border flash and smoothly return sheen from left
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.53) {
                    // Turn off border gold glow
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFlash = false
                    }
                    
                    // Move sheen to far left instantly
                    var resetTrans = Transaction()
                    resetTrans.disablesAnimations = true
                    withTransaction(resetTrans) {
                        sheenOffsetMultiplier = -1.2
                    }
                    
                    // Animate sheen sliding back to resting position from the left
                    withAnimation(.easeOut(duration: 0.25)) {
                        sheenOffsetMultiplier = -0.6
                    }
                }
                
                onTap()
            }
        }
    }
    
    private func formattedCardNumber(_ number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "")
        var formatted = ""
        let displayCount = 16
        
        for i in 0..<displayCount {
            if i < cleaned.count {
                let index = cleaned.index(cleaned.startIndex, offsetBy: i)
                if maskNumber && i >= 8 {
                    formatted.append("*")
                } else {
                    formatted.append(cleaned[index])
                }
            } else {
                formatted.append("*")
            }
            
            if (i + 1) % 4 == 0 && i < (displayCount - 1) {
                formatted.append(" ")
            }
        }
        
        return formatted
    }
}

// MARK: - Card Decorations Component
struct CardDecorations: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Diagonal accent stripe
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.7, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.75, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height * 1.07))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.04))
                
                // Translucent glow circles
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 140, height: 140)
                    .offset(x: geo.size.width - 60, y: geo.size.height - 70)
                
                Circle()
                    .fill(Color.white.opacity(0.02))
                    .frame(width: 200, height: 200)
                    .offset(x: -50, y: -80)
            }
        }
        .clipped()
    }
}

// MARK: - Custom TextField
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isHighlighted: Bool = false
    var onClear: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isHighlighted ? Color.red : .white.opacity(0.4))
                .font(.system(size: 16))
                .frame(width: 22)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.25))
                        .font(.system(size: 15, design: .rounded))
                }
                TextField("", text: $text)
                    .foregroundColor(.white)
                    .font(.system(size: 15, design: .rounded))
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled(true)
            }
            
            // Clear text field button
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onClear?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 15))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.red.opacity(0.75) : Color.white.opacity(0.1), lineWidth: isHighlighted ? 1.5 : 1)
        )
        .shadow(color: isHighlighted ? Color.red.opacity(0.15) : Color.clear, radius: 4)
    }
}

// MARK: - Toast View Component
struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "10B981"))
                .font(.system(size: 15, weight: .bold))
            
            Text(message)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .blurBackground(style: .systemUltraThinMaterialDark, shape: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Visual Effect Wrapper for Glassmorphism
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

struct BlurViewModifier<S: Shape>: ViewModifier {
    var style: UIBlurEffect.Style
    var shape: S
    
    func body(content: Content) -> some View {
        content
            .background(
                VisualEffectView(effect: UIBlurEffect(style: style))
                    .clipShape(shape)
            )
    }
}

extension View {
    func blurBackground<S: Shape>(style: UIBlurEffect.Style, shape: S) -> some View {
        self.modifier(BlurViewModifier(style: style, shape: shape))
    }
}

// MARK: - Color Hex Extension
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
    
    // Mathematically darkens the color for gradient styling
    func darkened() -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(red: Double(r * 0.45), green: Double(g * 0.45), blue: Double(b * 0.45), opacity: Double(a))
        }
        #endif
        return self
    }
    
    // Convert SwiftUI Color to Hex String
    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let r = Int(red * 255.0)
            let g = Int(green * 255.0)
            let b = Int(blue * 255.0)
            return String(format: "%02X%02X%02X", r, g, b)
        }
        #endif
        return nil
    }
}

// MARK: - Add / Edit Sheet Modes
enum SheetMode {
    case add
    case edit
}

// MARK: - Sheet Configuration (Identifiable wrapper for .sheet(item:))
struct SheetConfig: Identifiable {
    let id = UUID()
    let mode: SheetMode
    let card: Card?
}

// MARK: - Card Add & Edit Sheet Component
struct CardEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: CardStore
    
    let mode: SheetMode
    let cardToEdit: Card?
    
    @State private var cardName: String = ""
    @State private var cardNumber: String = ""
    @State private var expiryDate: String = ""
    @State private var cvv: String = ""
    @State private var selectedTheme: CardTheme = .purplePink
    @State private var holderName: String = "" // Added holderName state
    @State private var provider: CardProvider = .unknown
    
    func cycleProvider() {
        let allProviders: [CardProvider] = [.visa, .mastercard, .troy]
        if let currentIndex = allProviders.firstIndex(of: provider) {
            let nextIndex = (currentIndex + 1) % allProviders.count
            provider = allProviders[nextIndex]
        } else {
            provider = .visa
        }
    }
    
    // Focus states for textfields
    enum Field: Hashable {
        case cardName
        case holderName
        case cardNumber
        case expiryDate
        case cvv
    }
    @FocusState private var focusedField: Field?
    
    // Custom Color Picking states
    @State private var customColorHex: String? = nil
    @State private var pickerColor: Color = .purple
    
    // Scanning and validation highlights
    @State private var showScanner = false
    @State private var highlightCardName = false
    @State private var highlightCardNumber = false
    @State private var highlightExpiryDate = false
    @State private var highlightCVV = false
    
    // Note: holderName is optional, so it is NOT required for form validation
    var isFormValid: Bool {
        !cardName.trimmingCharacters(in: .whitespaces).isEmpty &&
        cardNumber.replacingOccurrences(of: " ", with: "").count == 16 &&
        expiryDate.count == 5 &&
        (cvv.count == 3 || cvv.count == 4)
    }
    
    private var navigationHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Text("İptal")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            
            Spacer()
            
            Text(mode == .add ? "Yeni Kart Ekle" : "Kartı Düzenle")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // Scanner Button at top right as secondary shortcut
            if mode == .add {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    showScanner = true
                }) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            } else {
                Text("İptal")
                    .font(.system(size: 15))
                    .foregroundColor(.clear)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private var providerCyclingButton: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
            cycleProvider()
        }) {
            HStack(spacing: 8) {
                CardProviderLogo(provider: provider, scale: 0.9)
                Text(provider == .unknown ? "Seç" : provider.displayName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .blurBackground(style: .systemUltraThinMaterialDark, shape: Capsule())
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var providerSelectorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.circle")
                .foregroundColor(.white.opacity(0.4))
                .font(.system(size: 16))
                .frame(width: 22)
            
            Text("Kart Sağlayıcı")
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 15, design: .rounded))
            
            Spacer()
            
            providerCyclingButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var expiryAndCvvRow: some View {
        HStack(spacing: 16) {
            CustomTextField(icon: "calendar", placeholder: "SKT (AA/YY)", text: $expiryDate, keyboardType: .numberPad, isHighlighted: highlightExpiryDate, onClear: {
                highlightExpiryDate = false
            })
            .focused($focusedField, equals: .expiryDate)
            .onChange(of: expiryDate) { newValue in
                expiryDate = formatExpiry(newValue)
                if newValue.count == 5 {
                    highlightExpiryDate = false
                }
            }
            
            CustomTextField(icon: "lock", placeholder: "CVV", text: $cvv, keyboardType: .numberPad, isHighlighted: highlightCVV, onClear: {
                highlightCVV = false
            })
            .focused($focusedField, equals: .cvv)
            .onChange(of: cvv) { newValue in
                cvv = formatCVV(newValue)
                if newValue.count >= 3 {
                    highlightCVV = false
                }
            }
        }
    }
    
    private var fieldsBlock: some View {
        VStack(spacing: 16) {
            CustomTextField(icon: "creditcard", placeholder: "Kart Adı (örn: Bonus Gold)", text: $cardName, isHighlighted: highlightCardName)
                .focused($focusedField, equals: .cardName)
                .onChange(of: cardName) { newValue in
                    if !newValue.isEmpty {
                        highlightCardName = false
                    }
                }
            
            providerSelectorRow
            
            // Cardholder Name (Optional Field)
            CustomTextField(icon: "person", placeholder: "Kart Sahibi (İsteğe Bağlı)", text: $holderName)
                .focused($focusedField, equals: .holderName)
            
            CustomTextField(icon: "number", placeholder: "Kart Numarası (16 haneli)", text: $cardNumber, keyboardType: .numberPad, isHighlighted: highlightCardNumber, onClear: {
                highlightCardNumber = false
            })
            .focused($focusedField, equals: .cardNumber)
            .onChange(of: cardNumber) { newValue in
                cardNumber = formatCardNumber(newValue)
                if newValue.replacingOccurrences(of: " ", with: "").count == 16 {
                    highlightCardNumber = false
                }
                let detected = CardProvider.detect(from: newValue)
                if detected != .unknown {
                    provider = detected
                }
            }
            
            expiryAndCvvRow
        }
        .padding(.horizontal, 20)
    }
    
    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KART RENGİ")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1.0)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Default presets
                    ForEach(CardTheme.allCases) { theme in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: theme.colors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: (selectedTheme == theme && customColorHex == nil) ? 2.5 : 0)
                                    .shadow(color: Color.black.opacity(0.3), radius: 3)
                            )
                            .scaleEffect((selectedTheme == theme && customColorHex == nil) ? 1.12 : 1.0)
                            .onTapGesture {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                customColorHex = nil // Clear custom color picker selection
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    selectedTheme = theme
                                }
                            }
                    }
                    
                    // ColorPicker with rainbow-plus overlay styling
                    ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 42, height: 42)
                        .overlay(
                            ZStack {
                                Circle()
                                    .fill(
                                        AngularGradient(
                                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                            center: .center
                                        )
                                    )
                                    .frame(width: 42, height: 42)
                                
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold))
                                    .shadow(color: Color.black.opacity(0.3), radius: 2)
                            }
                            .allowsHitTesting(false) // Let touches pass through directly to ColorPicker underneath
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: customColorHex != nil ? 2.5 : 0)
                                .shadow(color: Color.black.opacity(0.3), radius: 3)
                                .allowsHitTesting(false)
                        )
                        .scaleEffect(customColorHex != nil ? 1.12 : 1.0)
                        .onChange(of: pickerColor) { newColor in
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            if let hex = newColor.toHex() {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                    customColorHex = hex
                                }
                            }
                        }
                }
                .padding(.horizontal, 20)
                .frame(height: 52)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Dark background matching main view
            Color(hex: "0A0A0C")
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Custom Navigation/Header
                    navigationHeader
                    
                    // Live Card Preview (Unmasked, so user sees input clearly)
                    CardView(card: Card(
                        id: cardToEdit?.id ?? UUID(),
                        name: cardName.isEmpty ? "Kart Adı" : cardName,
                        number: cardNumber.replacingOccurrences(of: " ", with: ""),
                        expiry: expiryDate,
                        cvv: cvv,
                        theme: selectedTheme,
                        customColorHex: customColorHex,
                        holderName: holderName,
                        provider: provider
                    ), maskNumber: false, isPreview: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Prominent Camera Scanner Button (Add Mode Only)
                    if mode == .add {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            showScanner = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Kamera ile Hızlı Tara")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .padding(.top, 2)
                    }
                    
                    // Input Fields Block
                    fieldsBlock
                    
                    // Card Theme Selection
                    themeSelector
                    
                    // Save Button
                    Button(action: saveAction) {
                        Text("Kaydet")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: isFormValid ? (customColorHex != nil ? [pickerColor, pickerColor.darkened()] : selectedTheme.colors) : [Color.white.opacity(0.06)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isFormValid ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: isFormValid ? (customColorHex != nil ? pickerColor.opacity(0.35) : selectedTheme.colors.first!.opacity(0.35)) : Color.clear, radius: 10, y: 5)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    Spacer()
                }
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showScanner) {
            CardScannerView { cardNumber, expiry, cardProvider in
                // User closed the scanner without scanning anything
                if cardNumber == nil && expiry == nil {
                    showScanner = false
                    return
                }
                
                // Populate scanned card number, highlight if missing
                if let number = cardNumber {
                    self.cardNumber = formatCardNumber(number)
                    self.highlightCardNumber = false
                } else {
                    self.highlightCardNumber = true
                }
                
                // Populate scanned expiry, highlight if missing
                if let exp = expiry {
                    self.expiryDate = formatExpiry(exp)
                    self.highlightExpiryDate = false
                } else {
                    self.highlightExpiryDate = true
                }
                
                // Populate scanned provider (or fallback to auto-detection from scanned number)
                if cardProvider != .unknown {
                    self.provider = cardProvider
                } else if let number = cardNumber {
                    self.provider = CardProvider.detect(from: number)
                }
                
                // Highlight empty fields
                if self.cvv.isEmpty {
                    self.highlightCVV = true
                }
                if self.cardName.isEmpty {
                    self.highlightCardName = true
                }
                
                showScanner = false
                
                // Automatically request keyboard focus on Card Number to allow swift corrections
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    self.focusedField = .cardNumber
                }
            }
        }
        .onAppear {
            if let card = cardToEdit, mode == .edit {
                cardName = card.name
                cardNumber = formatCardNumber(card.number)
                expiryDate = card.expiry
                cvv = card.cvv
                selectedTheme = card.theme
                customColorHex = card.customColorHex
                holderName = card.holderName ?? ""
                provider = card.provider
                if let hex = card.customColorHex {
                    pickerColor = Color(hex: hex)
                }
            }
        }
    }
    
    // Save Event Action
    private func saveAction() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let cleanedNumber = cardNumber.replacingOccurrences(of: " ", with: "")
        let savedCard = Card(
            id: cardToEdit?.id ?? UUID(),
            name: cardName,
            number: cleanedNumber,
            expiry: expiryDate,
            cvv: cvv,
            theme: selectedTheme,
            customColorHex: customColorHex,
            holderName: holderName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : holderName,
            provider: provider
        )
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            if mode == .add {
                store.addCard(savedCard)
            } else {
                store.updateCard(savedCard)
            }
        }
        
        dismiss()
    }
    
    // Formatting Helpers
    private func formatCardNumber(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let limited = String(digits.prefix(16))
        var result = ""
        for (index, char) in limited.enumerated() {
            if index > 0 && index % 4 == 0 {
                result.append(" ")
            }
            result.append(char)
        }
        return result
    }
    
    private func formatExpiry(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        let limited = String(digits.prefix(4))
        if limited.count > 2 {
            let month = limited.prefix(2)
            let year = limited.suffix(from: limited.index(limited.startIndex, offsetBy: 2))
            return "\(month)/\(year)"
        }
        return limited
    }
    
    private func formatCVV(_ input: String) -> String {
        let digits = input.filter { $0.isNumber }
        return String(digits.prefix(4))
    }
}

// MARK: - Native Card OCR Scanner Wrapper
struct CardScannerView: UIViewControllerRepresentable {
    var onCompletion: (String?, String?, CardProvider) -> Void // returns (cardNumber, expiry, provider)
    
    func makeUIViewController(context: Context) -> CardScannerViewController {
        let controller = CardScannerViewController()
        controller.onCompletion = onCompletion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CardScannerViewController, context: Context) {}
}

class CardScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onCompletion: ((String?, String?, CardProvider) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: previewLayerClass!
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private var isProcessing = false
    private let visionQueue = DispatchQueue(label: "com.infocard.visionqueue", qos: .userInitiated)
    
    // Accumulators for Statistical Voting Mechanism
    private var numberFrequencies: [String: Int] = [:]
    private var expiryFrequencies: [String: Int] = [:]
    private var providerFrequencies: [CardProvider: Int] = [:]
    private var framesProcessed = 0
    private let maxFrames = 35 // Process up to 35 frames (approx 1.2s of analysis)
    private let requiredNumberConfidence = 5 // Require seeing the exact same number 5 times
    private let requiredExpiryConfidence = 3 // Require seeing the exact same expiry 3 times
    
    private var guideView: UIView!
    private var closeButton: UIButton!
    private var titleLabel: UILabel!
    private var statusLabel: UILabel! // Visual scan progress percent feedback
    
    typealias previewLayerClass = AVCaptureVideoPreviewLayer
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        
        // Target Guide Box layout matching credit card aspect ratio (1.58:1)
        let width = view.bounds.width * 0.85
        let height = width / 1.58
        guideView.frame = CGRect(
            x: (view.bounds.width - width) / 2,
            y: (view.bounds.height - height) / 2,
            width: width,
            height: height
        )
        
        titleLabel.frame = CGRect(
            x: 20,
            y: guideView.frame.minY - 60,
            width: view.bounds.width - 40,
            height: 40
        )
        
        statusLabel.frame = CGRect(
            x: 20,
            y: guideView.frame.maxY + 20,
            width: view.bounds.width - 40,
            height: 30
        )
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .hd1280x720
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Start camera session asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    private func setupUI() {
        // Guide Box
        guideView = UIView()
        guideView.layer.borderColor = UIColor(hex: "FBBF24").cgColor // Gold color guide box
        guideView.layer.borderWidth = 2.5
        guideView.layer.cornerRadius = 14
        guideView.layer.shadowColor = UIColor(hex: "FBBF24").cgColor
        guideView.layer.shadowOpacity = 0.5
        guideView.layer.shadowRadius = 8
        view.addSubview(guideView)
        
        // Title Label
        titleLabel = UILabel()
        titleLabel.text = "Kredi Kartınızı Çerçeve İçine Alın"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.shadowColor = .black
        titleLabel.shadowOffset = CGSize(width: 1, height: 1)
        view.addSubview(titleLabel)
        
        // Status Progress Label
        statusLabel = UILabel()
        statusLabel.text = "Kart taranıyor, lütfen sabit tutun..."
        statusLabel.textColor = UIColor(hex: "FBBF24")
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 13, weight: .bold)
        statusLabel.shadowColor = .black
        statusLabel.shadowOffset = CGSize(width: 1, height: 1)
        view.addSubview(statusLabel)
        
        // Close Button
        closeButton = UIButton(type: .system)
        closeButton.setTitle("İptal", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        closeButton.layer.cornerRadius = 12
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        closeButton.frame = CGRect(x: 20, y: 54, width: 70, height: 38)
        closeButton.addTarget(self, action: #selector(dismissScanner), for: .touchUpInside)
        view.addSubview(closeButton)
    }
    
    @objc private func dismissScanner() {
        captureSession.stopRunning()
        onCompletion?(nil, nil, .unknown)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        isProcessing = true
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }
        
        // Request Vision Text Recognition (OCR)
        let request = VNRecognizeTextRequest { [weak self] request, error in
            defer { self?.isProcessing = false }
            
            guard error == nil,
                  let results = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            var recognizedStrings = [String]()
            for observation in results {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                recognizedStrings.append(topCandidate.string)
            }
            
            self?.parseCardDetails(from: recognizedStrings)
        }
        
        request.recognitionLevel = .accurate
        
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
    
    private func parseCardDetails(from strings: [String]) {
        var foundNumber: String?
        var foundExpiry: String?
        
        // Number Regex (Matches 13-16 digit patterns with optional spaces or dashes)
        let numberRegex = try! NSRegularExpression(pattern: "\\b(?:\\d[ -]*?){13,16}\\b")
        
        // Expiry Date Regex (Matches MM/YY or MM/YYYY)
        let expiryRegex = try! NSRegularExpression(pattern: "\\b(0[1-9]|1[0-2])\\/([0-9]{2,4})\\b")
        
        for string in strings {
            let cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract Card Number
            if let match = numberRegex.firstMatch(in: cleanString, options: [], range: NSRange(location: 0, length: cleanString.utf16.count)) {
                let matchedStr = (cleanString as NSString).substring(with: match.range)
                let digits = matchedStr.filter { $0.isNumber }
                if digits.count >= 13 && digits.count <= 16 {
                    foundNumber = digits
                }
            }
            
            // Extract Expiry Date
            if let match = expiryRegex.firstMatch(in: cleanString, options: [], range: NSRange(location: 0, length: cleanString.utf16.count)) {
                let matchedStr = (cleanString as NSString).substring(with: match.range)
                let cleanExpiry = matchedStr.replacingOccurrences(of: " ", with: "")
                
                let components = cleanExpiry.split(separator: "/")
                if components.count == 2 {
                    let month = String(components[0])
                    var year = String(components[1])
                    if year.count == 4 {
                        year = String(year.suffix(2))
                    }
                    foundExpiry = "\(month)/\(year)"
                }
            }
        }
        
        // Detect frame provider (direct OCR text or fallback to number detection)
        var frameProvider: CardProvider = .unknown
        for string in strings {
            let lowercased = string.lowercased()
            if lowercased.contains("visa") {
                frameProvider = .visa
                break
            } else if lowercased.contains("mastercard") || lowercased.contains("master") {
                frameProvider = .mastercard
                break
            } else if lowercased.contains("troy") {
                frameProvider = .troy
                break
            }
        }
        
        if frameProvider == .unknown, let num = foundNumber {
            frameProvider = detectProviderFromNumber(num)
        }
        
        // Populate voting lists
        if let num = foundNumber {
            numberFrequencies[num, default: 0] += 1
        }
        if let exp = foundExpiry {
            expiryFrequencies[exp, default: 0] += 1
        }
        if frameProvider != .unknown {
            providerFrequencies[frameProvider, default: 0] += 1
        }
        
        framesProcessed += 1
        
        // Determine current statistical mode (highest frequency matches)
        let bestNumber = numberFrequencies.max(by: { $0.value < $1.value })
        let bestExpiry = expiryFrequencies.max(by: { $0.value < $1.value })
        let bestProvider = providerFrequencies.max(by: { $0.value < $1.value })?.key ?? .unknown
        
        let hasConfidentNumber = (bestNumber?.value ?? 0) >= requiredNumberConfidence
        let hasConfidentExpiry = (bestExpiry?.value ?? 0) >= requiredExpiryConfidence
        
        // Update progress label on main thread
        DispatchQueue.main.async {
            let percent = min(99, Int(Double(self.framesProcessed) / Double(self.maxFrames) * 100))
            self.statusLabel.text = "Kart taranıyor... %\(percent)"
        }
        
        // If we have met the confidence thresholds or processed the max frames, complete scanning
        if (hasConfidentNumber && hasConfidentExpiry) || framesProcessed >= maxFrames {
            DispatchQueue.main.sync {
                self.captureSession.stopRunning()
                
                let finalNumber = bestNumber?.key
                let finalExpiry = bestExpiry?.key
                
                self.onCompletion?(finalNumber, finalExpiry, bestProvider)
            }
        }
    }
    
    private func detectProviderFromNumber(_ number: String) -> CardProvider {
        let digits = number.filter { $0.isNumber }
        if digits.hasPrefix("4") {
            return .visa
        } else if digits.hasPrefix("51") || digits.hasPrefix("52") || digits.hasPrefix("53") || digits.hasPrefix("54") || digits.hasPrefix("55") ||
                  digits.hasPrefix("222") || digits.hasPrefix("223") || digits.hasPrefix("224") || digits.hasPrefix("225") || digits.hasPrefix("226") || digits.hasPrefix("227") || digits.hasPrefix("23") || digits.hasPrefix("24") || digits.hasPrefix("25") || digits.hasPrefix("26") || digits.hasPrefix("27") {
            return .mastercard
        } else if digits.hasPrefix("9792") {
            return .troy
        }
        return .unknown
    }
}

// MARK: - UIColor hex extension helper for Scanner
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        self.init(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
    }
}

// MARK: - SwiftUI Preview
#Preview {
    ContentView()
}
