import SwiftUI
import CoreLocation

struct HomeView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var useManualLocation = false
    @State private var manualLocationText = ""
    @State private var isGeocoding = false
    @State private var walkMinutes: Int = 10
    @State private var selectedBudget: BudgetRange? = nil
    @State private var selectedMoods: Set<Mood> = []
    @State private var selectedDiningScene: DiningScene? = nil
    @State private var selectedGenres: Set<Genre> = []
    @State private var freeText: String = ""
    @State private var isLoading = false
    @State private var result: RecommendationResult? = nil
    @State private var errorMessage: String? = nil

    private let walkOptions = [5, 10, 15]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    locationSection
                    walkSection
                    budgetSection
                    moodSection
                    sceneSection
                    genreSection
                    proposeButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Trois")
            .navigationBarTitleDisplayMode(.large)
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
    }

    // MARK: - Sections

    private var headerSection: some View {
        Text("AIが近くの3軒を\n決めてくれる")
            .font(.title2)
            .fontWeight(.semibold)
            .lineSpacing(4)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("場所")

            Picker("場所の指定方法", selection: $useManualLocation) {
                Text("現在地").tag(false)
                Text("地名で指定").tag(true)
            }
            .pickerStyle(.segmented)

            if useManualLocation {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.secondary)
                    TextField("例: 渋谷駅、横浜市みなとみらい", text: $manualLocationText)
                        .font(.subheadline)
                        .submitLabel(.search)
                    if isGeocoding {
                        ProgressView()
                    }
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: locationManager.statusIcon)
                        .foregroundStyle(locationManager.statusColor)
                    Text(locationManager.statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if locationManager.status == .denied {
                        Button("設定を開く") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var walkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("徒歩何分以内？")
            HStack(spacing: 10) {
                ForEach(walkOptions, id: \.self) { min in
                    Toggle(isOn: Binding(
                        get: { walkMinutes == min },
                        set: { if $0 { walkMinutes = min } }
                    )) {
                        Text("\(min)分")
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("予算")
            FlowLayout(spacing: 10) {
                ForEach(BudgetRange.allCases) { b in
                    Toggle(isOn: Binding(
                        get: { selectedBudget == b },
                        set: { if $0 { selectedBudget = b } else { selectedBudget = nil } }
                    )) {
                        Text(b.rawValue)
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("今の気分は？（複数可）")
            FlowLayout(spacing: 10) {
                ForEach(Mood.allCases) { m in
                    Toggle(isOn: Binding(
                        get: { selectedMoods.contains(m) },
                        set: { if $0 { selectedMoods.insert(m) } else { selectedMoods.remove(m) } }
                    )) {
                        Text(m.rawValue)
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var sceneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("シーン")
            FlowLayout(spacing: 10) {
                ForEach(DiningScene.allCases) { s in
                    Toggle(isOn: Binding(
                        get: { selectedDiningScene == s },
                        set: { if $0 { selectedDiningScene = s } else { selectedDiningScene = nil } }
                    )) {
                        Text(s.rawValue)
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }
        }
    }

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("ジャンルで絞る（任意・複数可）")
            FlowLayout(spacing: 10) {
                ForEach(Genre.allCases) { g in
                    Toggle(isOn: Binding(
                        get: { selectedGenres.contains(g) },
                        set: { if $0 { selectedGenres.insert(g) } else { selectedGenres.remove(g) } }
                    )) {
                        Text(g.rawValue)
                    }
                    .toggleStyle(ChipToggleStyle())
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.secondary)
                TextField("自由入力（例: さっぱりしたものが食べたい、辛いものOK）", text: $freeText)
                    .font(.subheadline)
            }
            .padding(12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var proposeButton: some View {
        Button {
            propose()
        } label: {
            Text("3軒を提案してもらう")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canPropose || isLoading)
        .padding(.top, 8)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
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
