import Foundation
import SwiftUI

typealias MemberID = String

struct Member: Identifiable, Hashable {
    let id: MemberID
    let displayName: String
    let color: Color
    var initial: String { String(displayName.prefix(1)).uppercased() }
}

enum Attendance: String, Codable, CaseIterable {
    case eating, away, unknown
    var label: String {
        switch self {
        case .eating: return "Eating"
        case .away: return "Away"
        case .unknown: return "Not answered"
        }
    }
}

struct Dinner: Identifiable, Hashable {
    let id: UUID
    let date: LocalDate
    var dish: String?
    var cookID: MemberID?
    var time: String?
    var revision: Int
}

struct ChoreTemplate: Identifiable, Hashable {
    let id: UUID
    let name: String
    let instructions: String
    /// Foundation weekday (1 = Sunday ... 7 = Saturday)
    let weekday: Int
}

struct ChoreOccurrence: Identifiable, Hashable {
    let id: UUID
    let templateID: UUID
    let name: String
    let date: LocalDate
    var assigneeID: MemberID?
    var completedByID: MemberID?
    var revision: Int
    var isCompleted: Bool { completedByID != nil }
}

struct HouseEvent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let date: LocalDate
    var time: String?
    let creatorID: MemberID
}

enum Sender: Hashable {
    case member(MemberID)
    case house
}

struct Message: Identifiable, Hashable {
    let id: UUID
    let sender: Sender
    let body: String
    let mentionsHouse: Bool
    let sentAt: Date
    var taskID: UUID?
}

enum TaskState: Hashable {
    case working
    case needsInput(String)
    case waitingForVolunteer
    case completed
    case failed(String)

    var label: String {
        switch self {
        case .needsInput: return "Waiting for your answer"
        case .working: return "Working"
        case .waitingForVolunteer: return "Waiting for a volunteer"
        case .completed: return "Completed"
        case .failed: return "House couldn't finish this"
        }
    }
}

struct AgentTask: Identifiable, Hashable {
    let id: UUID
    let initiatorID: MemberID
    let sourceMessageID: UUID
    var state: TaskState
    var proposalID: UUID?
    var attempts: Int
}

enum ProposalState: Hashable {
    case awaitingVolunteer
    case applied
    case cancelled
    var label: String {
        switch self {
        case .awaitingVolunteer: return "Waiting for a volunteer"
        case .applied: return "Applied"
        case .cancelled: return "Cancelled"
        }
    }
}

struct CoverProposal: Identifiable, Hashable {
    let id: UUID
    let taskID: UUID?
    let occurrenceID: UUID
    let initiatorID: MemberID
    let expectedOccurrenceRevision: Int
    var revision: Int
    var state: ProposalState
    var acceptedByID: MemberID?
    let createdAt: Date
}

enum DomainError: Error, Equatable, LocalizedError {
    case notAMember(MemberID)
    case notYourRecord
    case dateInPast(LocalDate)
    case noFutureDates
    case dinnerNotFound(LocalDate)
    case slotTaken(cook: String)
    case occurrenceNotFound
    case occurrenceCompleted
    case proposalNotFound
    case alreadyResolved
    case staleRevision
    case cannotAcceptOwnRequest
    case alreadyProposed

    var errorDescription: String? {
        switch self {
        case .notAMember(let id): return "\(id) is not a member of this house."
        case .notYourRecord: return "You can only change your own records."
        case .dateInPast(let d): return "\(d.longLabel) is in the past."
        case .noFutureDates: return "None of those dates are in the future."
        case .dinnerNotFound(let d): return "There is no dinner record for \(d.longLabel)."
        case .slotTaken(let cook): return "\(cook) is already cooking that day."
        case .occurrenceNotFound: return "That chore occurrence does not exist."
        case .occurrenceCompleted: return "That chore is already completed."
        case .proposalNotFound: return "That request no longer exists."
        case .alreadyResolved: return "Someone already took this one."
        case .staleRevision: return "This record changed. Please review the current state."
        case .cannotAcceptOwnRequest: return "You can't take your own cover request."
        case .alreadyProposed: return "There is already an open cover request for this chore."
        }
    }
}
