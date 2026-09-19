//
//  SearchView.swift
//  SY STORE
//
//  Created by [اسمك] on [التاريخ].
//

import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchText: String = ""
    
    // بيانات وهمية للتجربة (يجب استبدالها ببيانات من AltSourceKit أو CoreData لديك)
    @State private var allApps = MockApp.dummyData
    
    // تصفية التطبيقات بناءً على نص البحث
    var filteredApps: [MockApp] {
        if searchText.isEmpty {
            return []
        } else {
            return allApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // الكلمات الشائعة (Trending Searches)
    let trendingSearches = ["WhatsApp Plus", "Spotify Premium", "Instagram Dark", "TikTok", "PUBG Hack"]

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    // MARK: - واجهة قبل البحث (عمليات البحث الشائعة)
                    Section {
                        ForEach(trendingSearches, id: \.self) { term in
                            Button(action: {
                                searchText = term
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.accentColor)
                                    Text(term)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 18, weight: .regular))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("اكتشف")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                            .textCase(nil)
                            .padding(.bottom, 5)
                    }
                    .listRowSeparator(.hidden)
                    
                } else {
                    // MARK: - واجهة نتائج البحث
                    if filteredApps.isEmpty {
                        // حالة عدم العثور على نتائج
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        // عرض التطبيقات المطابقة
                        ForEach(filteredApps) { app in
                            AppSearchRowView(app: app)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("البحث")
            // إضافة شريط البحث الأصلي من أبل
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "الألعاب، التطبيقات، والمزيد")
            .toolbar {
                // زر إغلاق الواجهة (بما أنها تفتح كـ Sheet)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تم") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
        // إجبار الواجهة على دعم الاتجاه من اليمين لليسار (اللغة العربية)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - تصميم خلية التطبيق في نتائج البحث (App Row)
struct AppSearchRowView: View {
    let app: MockApp
    
    var body: some View {
        HStack(spacing: 15) {
            // أيقونة التطبيق
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
                .cornerRadius(14)
                .overlay(
                    // يمكنك استبدال هذا بـ AsyncImage عند ربط البيانات الحقيقية
                    Image(systemName: "app.fill")
                        .resizable()
                        .padding(15)
                        .foregroundColor(.gray)
                )
            
            // تفاصيل التطبيق
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(app.developer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // زر التحميل/التثبيت (يشبه زر Get في أبل ستور)
            Button(action: {
                // أمر التثبيت
            }) {
                Text("تثبيت")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - بيانات وهمية (Mock Data) للتجربة
// ملاحظة: احذف هذا الـ Struct عند ربط الكود بموديل البيانات الحقيقي الخاص بك (مثل ASRepository.App)
struct MockApp: Identifiable {
    let id = UUID()
    let name: String
    let developer: String
    
    static let dummyData = [
        MockApp(name: "WhatsApp Plus", developer: "Fouad Mods"),
        MockApp(name: "Spotify Premium", developer: "Spotify Ltd."),
        MockApp(name: "Instagram Dark", developer: "Meta"),
        MockApp(name: "TikTok", developer: "ByteDance"),
        MockApp(name: "YouTube Reborn", developer: "Twitch"),
        MockApp(name: "PUBG Hack", developer: "Tencent")
    ]
}

// MARK: - معاينة (Preview)
struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
