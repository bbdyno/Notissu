//
//  AdBanner.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import GoogleMobileAds
import SwiftUI
import UIKit

/// 화면 아래에 붙는 적응형 배너. 광고를 받을 수 없으면 자리를 차지하지 않는다.
struct AdBanner: View {
    @State private var ads = Ads.shared
    @State private var width: CGFloat = 0

    var body: some View {
        if ads.showsAds {
            let size = currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
            ZStack {
                if width > 0 {
                    BannerContainer(adSize: size)
                        .frame(width: size.size.width, height: size.size.height)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.size.height)
            .clipped()
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { width = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, new in width = new }
                }
            }
            .background(Theme.background)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.separator).frame(height: 1)
            }
            .accessibilityLabel("광고")
        }
    }
}

/// 목록 사이에 끼우는 배너 줄. 잘못 누르지 않도록 위아래 글과 간격을 둔다.
struct InlineAdRow: View {
    @State private var ads = Ads.shared
    @State private var width: CGFloat = 0

    var body: some View {
        if ads.showsAds {
            let size = currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
            VStack(spacing: 4) {
                Text("광고")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if width > 0 {
                    BannerContainer(adSize: size)
                        .frame(width: size.size.width, height: size.size.height)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { width = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, new in width = new }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 20))
            .listRowBackground(Theme.background)
            .listRowSeparatorTint(Theme.separator)
        }
    }
}

private struct BannerContainer: UIViewRepresentable {
    var adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = AdUnit.banner
        banner.rootViewController = Ads.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) else { return }
        banner.adSize = adSize
        banner.load(Request())
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BannerView, context: Context) -> CGSize? {
        adSize.size
    }
}
