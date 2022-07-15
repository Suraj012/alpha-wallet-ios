// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine

enum TokenInfoPageViewModelConfiguration {
    case charts
    case testnet
    case header(viewModel: TokenInfoHeaderViewModel)
    case field(viewModel: TokenAttributeViewModel)
}
//TODO: apply input output interface
class TokenInfoPageViewModel: NSObject {
    private var chartHistoriesSubject: CurrentValueSubject<[ChartHistory], Never> = .init([])
    private let coinTickersFetcher: CoinTickersFetcher
    private var ticker: CoinTicker?

    var tabTitle: String {
        return R.string.localizable.tokenTabInfo()
    }

    let transactionType: TransactionType

    private var chartHistories: [ChartHistory] {
        chartHistoriesSubject.value
    }

    lazy var fieldsViewModelConfigurations: AnyPublisher<[TokenInfoPageViewModelConfiguration], Never> = {
        let coinTicker = coinTicker.handleEvents(receiveOutput: { [weak self] ticker in
                self?.ticker = ticker
            }).mapToVoid()
            .eraseToAnyPublisher()

        let chartHistories = chartHistoriesSubject
            .mapToVoid()
            .eraseToAnyPublisher()

        return Publishers.Merge(coinTicker, chartHistories)
            .compactMap { [weak self] _ in self?.generateConfigurations() }
            .eraseToAnyPublisher()
    }()
    
    lazy var chartViewModel: TokenHistoryChartViewModel = .init(chartHistories: chartHistoriesSubject.eraseToAnyPublisher(), coinTicker: coinTicker)
    private var chartHistoryCancelable: AnyCancellable?
    lazy var headerViewModel: FungibleTokenHeaderViewModel = .init(transactionType: transactionType, service: service)
    private let service: TokenViewModelState

    init(transactionType: TransactionType, coinTickersFetcher: CoinTickersFetcher, service: TokenViewModelState) {
        self.service = service
        self.coinTickersFetcher = coinTickersFetcher
        self.transactionType = transactionType
        super.init()
    }

    func fetchChartHistory() {
        chartHistoryCancelable?.cancel()

        chartHistoryCancelable = coinTickersFetcher.fetchChartHistories(for: .init(token: transactionType.tokenObject), force: false, periods: ChartHistoryPeriod.allCases)
            .sink { [chartHistoriesSubject] chartHistories in
                chartHistoriesSubject.send(chartHistories)
            }
    }

    private lazy var coinTicker: AnyPublisher<CoinTicker?, Never> = {
        switch transactionType {
        case .nativeCryptocurrency:
            let etherToken = MultipleChainsTokensDataStore.functional.token(forServer: transactionType.server)
            return service.tokenViewModelPublisher(for: etherToken)
                .map { $0?.balance.ticker }
                .eraseToAnyPublisher()
        case .erc20Token(let token, _, _):
            return service.tokenViewModelPublisher(for: token)
                .map { $0?.balance.ticker }
                .eraseToAnyPublisher()
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return Just<CoinTicker?>(nil)
                .eraseToAnyPublisher()
        }
    }() 

    private func generateConfigurations() -> [TokenInfoPageViewModelConfiguration] {
        var configurations: [TokenInfoPageViewModelConfiguration] = []

        if transactionType.tokenObject.server.isTestnet {
            configurations = [
                .testnet
            ]
        } else {
            configurations = [
                .charts,
                .header(viewModel: .init(title: R.string.localizable.tokenInfoHeaderPerformance())),
                .field(viewModel: dayViewModel),
                .field(viewModel: weekViewModel),
                .field(viewModel: monthViewModel),
                .field(viewModel: yearViewModel),

                .header(viewModel: .init(title: R.string.localizable.tokenInfoHeaderStats())),
                .field(viewModel: markerCapViewModel),
                .field(viewModel: yearLowViewModel),
                .field(viewModel: yearHighViewModel)
            ]
        }

        return configurations
    }

    private var markerCapViewModel: TokenAttributeViewModel {
        let value: String = ticker?.market_cap.flatMap { StringFormatter().largeNumberFormatter(for: $0, currency: "USD") } ?? "-"
        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMarket_cap(), attributedValue: attributedValue)
    }

    private var totalSupplyViewModel: TokenAttributeViewModel {
        let value: String = ticker?.total_supply.flatMap { String($0) } ?? "-"
        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldStatsTotal_supply(), attributedValue: attributedValue)
    }

    private var maxSupplyViewModel: TokenAttributeViewModel {
        let value: String = ticker?.max_supply.flatMap { Formatter.usd.string(from: $0) } ?? "-"
        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMax_supply(), attributedValue: attributedValue)
    }

    private var yearLowViewModel: TokenAttributeViewModel {
        let value: String = {
            let history = chartHistories[safe: ChartHistoryPeriod.year.index]
            if let min = HistoryHelper(history: history).minMax?.min, let value = Formatter.usd.string(from: min) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldPerformanceYearLow(), attributedValue: attributedValue)
    }

    private var yearHighViewModel: TokenAttributeViewModel {
        let value: String = {
            let history = chartHistories[safe: ChartHistoryPeriod.year.index]
            if let max = HistoryHelper(history: history).minMax?.max, let value = Formatter.usd.string(from: max) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldPerformanceYearHigh(), attributedValue: attributedValue)
    }

    private var yearViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.year)
        return .init(title: R.string.localizable.tokenInfoFieldStatsYear(), attributedValue: attributedValue)
    }

    private var monthViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.month)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMonth(), attributedValue: attributedValue)
    }

    private var weekViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.week)
        return .init(title: R.string.localizable.tokenInfoFieldStatsWeek(), attributedValue: attributedValue)
    }

    private var dayViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.day)
        return .init(title: R.string.localizable.tokenInfoFieldStatsDay(), attributedValue: attributedValue)
    }

    private func attributedHistoryValue(period: ChartHistoryPeriod) -> NSAttributedString {
        let result: (string: String, foregroundColor: UIColor) = {
            let result = HistoryHelper(history: chartHistories[safe: period.index])

            switch result.change {
            case .appreciate(let percentage, let value):
                let p = Formatter.percent.string(from: percentage) ?? "-"
                let v = Formatter.usd.string(from: value) ?? "-"

                return ("\(v) (\(p)%)", Style.value.appreciated)
            case .depreciate(let percentage, let value):
                let p = Formatter.percent.string(from: percentage) ?? "-"
                let v = Formatter.usd.string(from: value) ?? "-"

                return ("\(v) (\(p)%)", Style.value.depreciated)
            case .none:
                return ("-", Colors.black)
            }
        }()

        return TokenAttributeViewModel.attributedString(result.string, alignment: .right, font: Fonts.regular(size: 17), foregroundColor: result.foregroundColor, lineBreakMode: .byTruncatingTail)
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }
}
