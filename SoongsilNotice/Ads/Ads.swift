//
//  Ads.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import AppTrackingTransparency
import Foundation
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// 광고 단위. 개발 빌드는 구글 시험 단위를 써서 실제 광고를 누르지 않게 한다.
/// 출시 빌드에서 값이 비어 있는 단위는 그 광고를 띄우지 않는다.
enum AdUnit {
    #if DEBUG
    static let banner = "ca-app-pub-3940256099942544/2435281174"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    static let appOpen = "ca-app-pub-3940256099942544/5575463023"
    #else
    static let banner = "ca-app-pub-8965771939775493/8407428627"
    static let interstitial = ""
    static let appOpen = ""
    #endif
}

/// 광고를 얼마나 자주 띄울지. 전면 광고끼리는 간격을 두고, 읽는 중에는 끼어들지 않는다.
enum AdPacing {
    /// 목록에서 글 몇 개마다 배너를 끼울지.
    static let inlineEvery = 8
    /// 공지를 몇 개 읽고 닫을 때마다 전면 광고를 띄울지.
    static let noticesPerInterstitial = 3
    /// 전면 광고·앱 열기 광고 사이의 최소 간격.
    static let fullScreenGap: TimeInterval = 120
    /// 앱을 이만큼 떠나 있다 돌아오면 앱 열기 광고를 띄운다.
    static let appOpenAway: TimeInterval = 30 * 60
    /// 앱 열기 광고는 받은 뒤 4시간이 지나면 쓰지 않는다(구글 권장).
    static let appOpenLifetime: TimeInterval = 4 * 60 * 60
}

/// 추적 허락 → 구글 동의 창 → 광고 시작 순서로 준비하고, 배너·전면·앱 열기 광고를 맡는다.
@MainActor
@Observable
final class Ads: NSObject {
    static let shared = Ads()

    private(set) var canRequestAds = false
    private(set) var isPrivacyOptionsRequired = false

    /// 스토어 스크린샷용: `-debugNoAds YES`로 모든 광고를 숨긴다. 출시 빌드에는 없다.
    var showsAds: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugNoAds") { return false }
        #endif
        return canRequestAds
    }

    @ObservationIgnored private var didConfigure = false
    @ObservationIgnored private var didStartSDK = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var appOpen: AppOpenAd?
    @ObservationIgnored private var appOpenLoadedAt: Date?
    @ObservationIgnored private var lastFullScreenAt: Date = .distantPast
    @ObservationIgnored private var backgroundedAt: Date?
    @ObservationIgnored private var closedNotices = 0
    @ObservationIgnored private var isPresenting = false

    /// 처음 쓰는 사람은 게시판을 고르고 알림 허락을 받은 뒤 부른다.
    func configure() async {
        guard !didConfigure else { return }
        didConfigure = true
        applyTracking(ATTrackingManager.trackingAuthorizationStatus)
        #if DEBUG
        let skipPrompt = UserDefaults.standard.bool(forKey: "debugNoAds")
        #else
        let skipPrompt = false
        #endif
        if skipPrompt { return }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            await waitUntilActive()
            applyTracking(await ATTrackingManager.requestTrackingAuthorization())
        }
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // 갱신에 실패해도 예전에 고른 동의로 광고를 받을 수 있다.
        }
        refreshPrivacyRequirement()
        await startIfAllowed()
        observeLifecycle()
    }

    func presentPrivacyOptions() async {
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
        refreshPrivacyRequirement()
        await startIfAllowed()
    }

    // MARK: 전면 광고

    /// 공지 본문을 닫을 때 부른다. 정해진 수만큼 읽었고 간격이 지났으면 전면 광고를 띄운다.
    func noticeClosed() {
        guard showsAds else { return }
        closedNotices += 1
        guard closedNotices >= AdPacing.noticesPerInterstitial,
              Date().timeIntervalSince(lastFullScreenAt) >= AdPacing.fullScreenGap,
              let ad = interstitial else { return }
        closedNotices = 0
        interstitial = nil
        present(ad)
    }

    // MARK: 앱 열기 광고

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.backgroundedAt = Date() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.returnedToForeground() }
        }
    }

    private func returnedToForeground() {
        defer { backgroundedAt = nil }
        guard showsAds, let away = backgroundedAt,
              Date().timeIntervalSince(away) >= AdPacing.appOpenAway,
              Date().timeIntervalSince(lastFullScreenAt) >= AdPacing.fullScreenGap else { return }
        guard let ad = appOpen, let loadedAt = appOpenLoadedAt,
              Date().timeIntervalSince(loadedAt) < AdPacing.appOpenLifetime else {
            appOpen = nil
            Task { await loadAppOpen() }
            return
        }
        appOpen = nil
        present(ad)
    }

    // MARK: 불러오기

    private func startIfAllowed() async {
        canRequestAds = ConsentInformation.shared.canRequestAds
        guard canRequestAds else { return }
        if !didStartSDK {
            didStartSDK = true
            await MobileAds.shared.start()
        }
        await loadInterstitial()
        await loadAppOpen()
    }

    private func loadInterstitial() async {
        guard canRequestAds, !AdUnit.interstitial.isEmpty, interstitial == nil else { return }
        if let ad = try? await InterstitialAd.load(with: AdUnit.interstitial, request: Request()) {
            ad.fullScreenContentDelegate = self
            interstitial = ad
        }
    }

    private func loadAppOpen() async {
        guard canRequestAds, !AdUnit.appOpen.isEmpty, appOpen == nil else { return }
        if let ad = try? await AppOpenAd.load(with: AdUnit.appOpen, request: Request()) {
            ad.fullScreenContentDelegate = self
            appOpen = ad
            appOpenLoadedAt = Date()
        }
    }

    private func present(_ ad: FullScreenPresentingAd) {
        guard !isPresenting, let top = Self.topViewController() else { return }
        isPresenting = true
        lastFullScreenAt = Date()
        let show = {
            if let ad = ad as? InterstitialAd {
                ad.present(from: top)
            } else if let ad = ad as? AppOpenAd {
                ad.present(from: top)
            }
        }
        // 화면이 넘어가는 중에 띄우면 조용히 실패한다.
        if let coordinator = top.transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { _ in show() }
        } else {
            show()
        }
    }

    private func finishFullScreen() {
        isPresenting = false
        lastFullScreenAt = Date()
        Task {
            await loadInterstitial()
            await loadAppOpen()
        }
    }

    // MARK: 도움

    private func refreshPrivacyRequirement() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func applyTracking(_ status: ATTrackingManager.AuthorizationStatus) {
        let configuration = MobileAds.shared.requestConfiguration
        configuration.publisherPrivacyPersonalizationState = status == .authorized ? .default : .disabled
        configuration.setPublisherFirstPartyIDEnabled(status == .authorized)
    }

    private func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            return
        }
    }

    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

extension Ads: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finishFullScreen() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in self.finishFullScreen() }
    }
}
