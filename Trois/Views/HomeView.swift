import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var usage: UsageManager
    @StateObject private var locationManager = LocationManager()
    @State private var useManualLocation = false
    @State private var manualLocationText = ""
    @State private var isGeocoding = false
    @State private var walkMinutes: Int = 10
    @State private var selectedBudget: BudgetRange? = .under2000
    @State private var selectedMoods: Set<Mood> = [.light]
    @State private var selectedDiningScene: DiningScene? = nil
    @State private var selectedGenres: Set<Genre> = []
    @State private var freeText: String = ""
    @State private var showMore: Bool = false
    @State private var isLoading = false
    @State private var result: RecommendationResult? = nil
    @State private var errorMessage: String? = nil
    @State private var showPaywall = false

    private let walkOptions = [5, 10, 15]

    private var moreCount: Int {
        (selectedDiningScene != nil ? 1 : 0) + selectedGenres.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Trois.cream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Trois.sectionGap) {
                        headerSection
                        locationSection
                        walkSection
                        budgetSection
                        moodSection
                        freeTextSection
                        moreSection
                        Color.clear.frame(height: 70) // CTAの下に隠れない余白
                    }
                    .padding(.horizontal, Trois.screenPadding)
                    .padding(.top, 60)
                }

                ctaBar
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $result) { res in
                ResultView(result: res)
            }
        }
        .alert("エラー", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .fullScreenCover(isPresented: $isLoading) {
            LoadingView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(usage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Wordmark
            HStack(spacing: 8) {
                wordmarkDots
                Text("Trois")
                    .font(Trois.display(20, weight: .bold))
                    .foregroundStyle(Trois.ink)
            }

            // eyebrow
            HStack(spacing: 6) {
                Circle().fill(Trois.accent).frame(width: 6, height: 6)
                Text("今のあなたに合う3軒を、AIが選びます")
                    .font(Trois.body(12.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Trois.accentDeep)
            }

            // H1
            (Text("今日のお店、\n")
                .foregroundStyle(Trois.ink)
            + Text("迷わなくていい。")
                .foregroundStyle(Trois.accentDeep))
                .font(Trois.display(30, weight: .medium))
                .lineSpacing(8)
                .tracking(0.3)

            // sub
            Text("条件はざっくりでOK。気になるところだけ選んで。あとはわたしが3軒に絞ります。")
                .font(Trois.body(13.5))
                .foregroundStyle(Trois.inkSoft)
                .lineSpacing(6)
        }
    }

    private var wordmarkDots: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Circle().fill(Trois.terracotta).frame(width: 8, height: 8)
                Circle().fill(Trois.sage).frame(width: 8, height: 8)
            }
            HStack {
                Circle().fill(Trois.ochre).frame(width: 8, height: 8)
                Spacer().frame(width: 8)
            }
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("場所")

            HStack(spacing: 4) {
                segmentButton(title: "現在地", isOn: !useManualLocation) { useManualLocation = false }
                segmentButton(title: "地名で指定", isOn: useManualLocation) { useManualLocation = true }
            }
            .padding(4)
            .background(Trois.surfaceSink, in: Capsule())

            if useManualLocation {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Trois.inkFaint)
                    TextField("例：渋谷、神保町、新横浜…", text: $manualLocationText)
                        .font(Trois.body(14.5))
                        .foregroundStyle(Trois.ink)
                        .submitLabel(.search)
                    if isGeocoding {
                        ProgressView()
                    }
                }
                .padding(14)
                .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rField))
                .overlay(RoundedRectangle(cornerRadius: Trois.rField).strokeBorder(Trois.line, lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: locationManager.statusIcon)
                        .foregroundStyle(locationManager.statusColor)
                    Text(locationManager.statusText)
                        .font(Trois.body(13.5))
                        .foregroundStyle(Trois.inkSoft)
                    Spacer()
                    if locationManager.status == .denied {
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(Trois.body(13))
                        .foregroundStyle(Trois.accentDeep)
                    }
                }
                .padding(14)
                .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rField))
                .overlay(RoundedRectangle(cornerRadius: Trois.rField).strokeBorder(Trois.line, lineWidth: 1))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: useManualLocation)
    }

    private func segmentButton(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Trois.body(14, weight: .medium))
                .foregroundStyle(isOn ? Trois.ink : Trois.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    isOn ? Trois.surface : Color.clear,
                    in: Capsule()
                )
                .shadow(color: isOn ? Trois.ink.opacity(0.10) : .clear, radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Walk / Budget / Mood

    private var walkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("徒歩何分以内？")
            HStack(spacing: Trois.chipGap) {
                ForEach(walkOptions, id: \.self) { min in
                    Toggle(isOn: Binding(
                        get: { walkMinutes == min },
                        set: { if $0 { walkMinutes = min } }
                    )) {
                        Text("〜\(min)分")
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("予算")
            FlowLayout(spacing: Trois.chipGap) {
                ForEach(BudgetRange.allCases) { b in
                    Toggle(isOn: Binding(
                        get: { selectedBudget == b },
                        set: { if $0 { selectedBudget = b } else { selectedBudget = nil } }
                    )) {
                        Text(b.localizedName)
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                sectionTitle("今の気分は？")
                Text("複数選択OK")
                    .font(Trois.body(11.5, weight: .medium))
                    .foregroundStyle(Trois.inkFaint)
            }
            FlowLayout(spacing: Trois.chipGap) {
                ForEach(Mood.allCases) { m in
                    Toggle(isOn: Binding(
                        get: { selectedMoods.contains(m) },
                        set: { if $0 { selectedMoods.insert(m) } else { selectedMoods.remove(m) } }
                    )) {
                        Text(m.localizedName)
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var freeTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                sectionTitle("ひとことあれば")
                Text("任意")
                    .font(Trois.body(11.5, weight: .medium))
                    .foregroundStyle(Trois.inkFaint)
            }
            TextField("さっぱりしたものが食べたい", text: $freeText, axis: .vertical)
                .font(Trois.body(14.5))
                .foregroundStyle(Trois.ink)
                .lineSpacing(4)
                .lineLimit(2...4)
                .padding(14)
                .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rField))
                .overlay(RoundedRectangle(cornerRadius: Trois.rField).strokeBorder(Trois.line, lineWidth: 1))
        }
    }

    // MARK: - こだわりで絞り込む（折りたたみ）

    private var moreSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { showMore.toggle() }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("こだわりで絞り込む")
                            .font(Trois.display(15, weight: .medium))
                            .foregroundStyle(Trois.ink)
                        Text("シーン・ジャンル（任意）")
                            .font(Trois.body(11.5))
                            .foregroundStyle(Trois.inkFaint)
                    }
                    Spacer()
                    if moreCount > 0 {
                        Text("\(moreCount)件選択中")
                            .font(Trois.body(11.5, weight: .semibold))
                            .foregroundStyle(Trois.accentDeep)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Trois.accentTint, in: Capsule())
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Trois.inkFaint)
                        .rotationEffect(.degrees(showMore ? 180 : 0))
                }
                .padding(15)
            }
            .buttonStyle(.plain)

            if showMore {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("シーン")
                        FlowLayout(spacing: Trois.chipGap) {
                            ForEach(DiningScene.allCases) { s in
                                Toggle(isOn: Binding(
                                    get: { selectedDiningScene == s },
                                    set: { if $0 { selectedDiningScene = s } else { selectedDiningScene = nil } }
                                )) {
                                    Text(s.localizedName)
                                }
                                .toggleStyle(ChipToggleStyle())
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            sectionTitle("ジャンルで絞る")
                            Text("複数OK")
                                .font(Trois.body(11.5, weight: .medium))
                                .foregroundStyle(Trois.inkFaint)
                        }
                        FlowLayout(spacing: Trois.chipGap) {
                            ForEach(Genre.allCases) { g in
                                Toggle(isOn: Binding(
                                    get: { selectedGenres.contains(g) },
                                    set: { if $0 { selectedGenres.insert(g) } else { selectedGenres.remove(g) } }
                                )) {
                                    Text(g.localizedName)
                                }
                                .toggleStyle(ChipToggleStyle())
                            }
                        }

                        // ファストフード選択時の注釈
                        if selectedGenres.contains(.fastFood) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Trois.ochreDeep)
                                    .padding(.top, 1)
                                Text("マクドナルド・吉野家・コンビニなどのチェーン店も含めて探します。写真や予算情報は表示されない場合があります。")
                                    .font(Trois.body(12.5))
                                    .foregroundStyle(Trois.inkSoft)
                                    .lineSpacing(4)
                            }
                            .padding(12)
                            .background(Trois.ochreTint, in: RoundedRectangle(cornerRadius: Trois.rReason))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: selectedGenres.contains(.fastFood))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Trois.surface, in: RoundedRectangle(cornerRadius: Trois.rField))
        .overlay(RoundedRectangle(cornerRadius: Trois.rField).strokeBorder(Trois.line, lineWidth: 1))
    }

    // MARK: - CTA

    private var ctaBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Trois.cream.opacity(0), Trois.cream], startPoint: .top, endPoint: .bottom)
                .frame(height: 28)

            // 残回数インジケーター
            if usage.remaining <= 10 && usage.remaining > 0 {
                Text("今月あと\(usage.remaining)回")
                    .font(Trois.body(12, weight: .medium))
                    .foregroundStyle(usage.remaining <= 5 ? Color.orange : Trois.inkSoft)
                    .padding(.bottom, 6)
            }

            HStack(spacing: 0) {
                Button {
                    if usage.isLimitReached {
                        showPaywall = true
                    } else {
                        propose()
                    }
                } label: {
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                            Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                        }
                        Text(usage.isLimitReached ? "今月の上限に達しました" : "3軒を提案してもらう")
                            .font(Trois.display(16.5, weight: .medium))
                            .tracking(0.3)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                }
                .background(usage.isLimitReached ? Trois.inkSoft : Trois.accent, in: Capsule())
                .shadow(color: (usage.isLimitReached ? Trois.inkSoft : Trois.accent).opacity(0.45), radius: 14, y: 8)
                .opacity(canPropose && !isLoading ? 1 : 0.5)
                .disabled(!canPropose || isLoading)
            }
            .padding(.horizontal, Trois.screenPadding)
            .padding(.bottom, 14)
            .background(Trois.cream)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Trois.display(16, weight: .medium))
            .foregroundStyle(Trois.ink)
            .tracking(0.3)
    }

    private var canPropose: Bool {
        if useManualLocation {
            return !manualLocationText.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return locationManager.isAvailable
        }
    }

    // MARK: - Action

    private func propose() {
        // 使用回数を消費（上限チェック済みだが念のため）
        guard usage.consume() else {
            showPaywall = true
            return
        }
        isLoading = true
        Task {
            do {
                let coord: Coordinate
                if useManualLocation {
                    await MainActor.run { isGeocoding = true }
                    coord = try await GeocodingService().geocode(address: manualLocationText)
                    await MainActor.run { isGeocoding = false }
                } else {
                    guard let c = locationManager.coordinate else {
                        await MainActor.run { isLoading = false }
                        return
                    }
                    coord = c
                }

                let query = UserQuery(
                    location: coord,
                    walkMinutes: walkMinutes,
                    budget: selectedBudget,
                    moods: Array(selectedMoods),
                    diningScene: selectedDiningScene,
                    genres: Array(selectedGenres),
                    freeText: freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : freeText.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                let service = RecommendationService()
                let res = try await service.recommend(query: query)
                await MainActor.run {
                    isLoading = false
                    result = res
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    isGeocoding = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
