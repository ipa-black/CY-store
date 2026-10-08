//
//  HomeView.swift
//  CY STORE
//
//  Created by samara on 13.05.2026.
//  Modified for CY STORE - App Store Native Design.
//

import SwiftUI
import CoreData
import AltSourceKit
import NimbleViews

struct HomeView: View {
    @Environment(\.openURL) var openURL
    @StateObject var viewModel = SourcesViewModel.shared
    
    @State private var _allApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _recentApps: [(source: ASRepository, app: ASRepository.App)] = []
    @State private var _banners: [ASRepository.News] = []
    @State private var _selectedRoute: SourceAppRoute?
    @State private var isLoading = true
    @State private var _recentAppsCount = 0
    @State private var _currentBannerIndex = 0
    
    private let bannerTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    @FetchRequest(
        entity: AltSource.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
        animation: .snappy
    ) private var _sources: FetchedResults<AltSource>

    var body: some View {
        NBNavigationView("الرئيسية") {
            ZStack {
                // خلفية بيضاء/سوداء نقية لتطابق App Store بدلاً من رمادي الـ List
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                if isLoading && _recentApps.isEmpty && _banners.isEmpty {
                    ProgressView("جاري التحديث...")
                } else if _recentApps.isEmpty && _banners.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label("لا توجد تطبيقات", systemImage: "tray.fill")
                        } description: {
                            Text("لم يتم العثور على تطبيقات أو عروض حالياً.")
                        }
                    } else {
                        Text("لا توجد تطبيقات")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 28) {
                            
                            // MARK: - قسم البنرات الإعلانية (App Store Featured Cards)
                            if !_banners.isEmpty {
                                TabView(selection: $_currentBannerIndex) {
                                    ForEach(_banners.indices, id: \.self) { index in
                                        let banner = _banners[index]
                                        
                                        Button {
                                            if let url = banner.url {
                                                openURL(url)
                                            } else if let appID = banner.appID,
                                                      let targetApp = _allApps.first(where: { $0.app.id == appID }) {
                                                _selectedRoute = SourceAppRoute(source: targetApp.source, app: targetApp.app)
                                            }
                                        } label: {
                                            if let imgUrl = banner.imageURL {
                                                AsyncImage(url: imgUrl) { phase in
                                                    if let image = phase.image {
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                    } else if phase.error != nil {
                                                        Rectangle()
                                                            .fill(Color(uiColor: .secondarySystemBackground))
                                                            .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color(uiColor: .secondarySystemBackground))
                                                            .overlay(ProgressView())
                                                    }
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 260) // ارتفاع أكبر ليطابق بطاقات أبل
                                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                                                .padding(.horizontal, 20)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .tag(index)
                                    }
                                }
                                .frame(height: 300) // توفير مساحة لمؤشر الصفحات (Page Control) والظل
                                .tabViewStyle(.page(indexDisplayMode: .always))
                                .onReceive(bannerTimer) { _ in
                                    if !_banners.isEmpty {
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            _currentBannerIndex = (_currentBannerIndex + 1) % _banners.count
                                        }
                                    }
                                }
                            }

                            // MARK: - قسم أحدث التطبيقات (App Store Vertical List)
                            if !_recentApps.isEmpty {
                                VStack(spacing: 16) {
                                    // ترويسة القسم بتصميم App Store
                                    HStack(alignment: .lastTextBaseline) {
                                        Text("أحدث الإضافات")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text("\(_recentAppsCount) تطبيق")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    // قائمة التطبيقات
                                    LazyVStack(spacing: 0) {
                                        ForEach(Array(_recentApps.enumerated()), id: \.element.app.currentUniqueId) { index, item in
                                            Button {
                                                _selectedRoute = SourceAppRoute(source: item.source, app: item.app)
                                            } label: {
                                                VStack(spacing: 0) {
                                                    SourceAppsCellView(source: item.source, app: item.app)
                                                        .padding(.vertical, 12)
                                                        .padding(.horizontal, 20)
                                                    
                                                    // خط فاصل بين التطبيقات (بدون خط في آخر عنصر)
                                                    if index < _recentApps.count - 1 {
                                                        Divider()
                                                            .padding(.leading, 85) // إزاحة الخط الفاصل ليبدأ بعد أيقونة التطبيق (حسب مقاس SourceAppsCellView)
                                                    }
                                                }
                                                // تأثير ضغطة الزر مثل App Store
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(AppStoreButtonStyle())
                                        }
                                    }
                                }
                            }
                            
                            // مسافة سفلية للتنفس
                            Spacer(minLength: 40)
                        }
                        .padding(.top, 10)
                    }
                }
            }
            .compatNavigationDestination(item: $_selectedRoute) { route in
                SourceAppsDetailView(source: route.source, app: route.app)
            }
            .refreshable {
                do {
                    await viewModel.fetchSources(_sources, refresh: true)
                } catch {
                    print("صيانة السورسات الخارجية جارية...")
                }
                _loadData()
            }
        }
        .task(id: Array(_sources)) {
            do {
                await viewModel.fetchSources(_sources)
            } catch {
                print("تحميل صامت للسورسات المتاحة...")
            }
            _loadData()
        }
    }

    // MARK: - جلب البيانات الآمن
    private func _loadData() {
        isLoading = true
        Task {
            let rawSources = _sources
            let loadedSources = rawSources.compactMap { viewModel.sources[$0] }
            
            var allApps: [(source: ASRepository, app: ASRepository.App)] = []
            var allBanners: [ASRepository.News] = []

            for source in loadedSources {
                let sourceApps = source.apps
                for app in sourceApps {
                    allApps.append((source: source, app: app))
                }
                
                if let matchedRawSource = rawSources.first(where: { viewModel.sources[$0]?.identifier == source.identifier }),
                   let sourceURLString = matchedRawSource.sourceURL?.absoluteString.lowercased() {
                    
                    if sourceURLString.contains("ipa-black") {
                        if let news = source.news {
                            allBanners.append(contentsOf: news)
                        }
                    }
                }
            }

            allApps.sort { firstItem, secondItem in
                let firstDate = firstItem.app.currentDate?.date ?? .distantPast
                let secondDate = secondItem.app.currentDate?.date ?? .distantPast
                return firstDate > secondDate
            }

            let topApps = Array(allApps.prefix(25))
            let validBanners = allBanners.filter { $0.imageURL != nil }

            DispatchQueue.main.async {
                self._allApps = allApps
                self._recentApps = topApps
                self._banners = validBanners
                self._recentAppsCount = topApps.count
                
                if self._currentBannerIndex >= validBanners.count {
                    self._currentBannerIndex = 0
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Types & Styles
struct SourceAppRoute: Identifiable, Hashable {
    let source: ASRepository
    let app: ASRepository.App
    let id: String = UUID().uuidString
}

// أسلوب ضغطة زر يحاكي التلاشي الخفيف في متجر أبل عند لمس الخلايا
struct AppStoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemGray5).opacity(0.5) : Color.clear)
    }
}

// MARK: - Extension for Navigation
extension View {
    @ViewBuilder
    func compatNavigationDestination<Item: Identifiable & Hashable, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        if #available(iOS 16.0, *) {
            self.navigationDestination(isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            )) {
                if let selectedItem = item.wrappedValue {
                    destination(selectedItem)
                }
            }
        } else {
            self.background(
                NavigationLink(
                    isActive: Binding(
                        get: { item.wrappedValue != nil },
                        set: { if !$0 { item.wrappedValue = nil } }
                    )
                ) {
                    if let selectedItem = item.wrappedValue {
                        destination(selectedItem)
                    } else {
                        EmptyView()
                    }
                } label: {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}
