//
//  SwapError.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation

public enum SwapError: Error {
    case unableToBuildSwapUnsignedTransactionFromSwapProvider
    case unableToBuildSwapUnsignedTransaction(message: String)
    case invalidJson
    case userCancelledApproval
    case approveTransactionNotCompleted
    case tokenOrSwapQuoteNotFound
    case inner(Error)
    case unknownError

    public var localizedDescription: String {
        switch self {
        case .unableToBuildSwapUnsignedTransaction(let message):
            return "Unable To Build Swap Unsigned Transaction: \(message)"
        case .unableToBuildSwapUnsignedTransactionFromSwapProvider:
            return "Unable To Build Swap Unsigned Transaction From Swap Provider"
        case .userCancelledApproval:
            return "User Cancelled Approval"
        case .approveTransactionNotCompleted:
            return "Approve Transaction Not Completed"
        case .unknownError:
            return "Unknown Error"
        case .tokenOrSwapQuoteNotFound:
            return "Unable To Build Swap Unsigned Transaction, Token Or Swap Quote Not Found"
        case .invalidJson:
            return "Invalid Json"
        case .inner(let error):
            return "\(error.localizedDescription)"
        }
    }
}

extension Error {
    public var isUserCancelledError: Bool {
        guard let swapError = self as? SwapError else { return false }
        switch swapError {
        case .userCancelledApproval:
            return true
        case .unableToBuildSwapUnsignedTransactionFromSwapProvider, .unableToBuildSwapUnsignedTransaction, .invalidJson, .approveTransactionNotCompleted, .tokenOrSwapQuoteNotFound, .unknownError, .inner:
            return false
        }
    }
}

