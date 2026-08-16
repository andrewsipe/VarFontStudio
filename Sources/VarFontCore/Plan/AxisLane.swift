import Foundation

/// UI / planning lane derived from axis role and fvar scale presence.
public enum AxisLane: String, Sendable, CaseIterable {
    case variation
    case pinned
    case registration
}

extension AxisDefinition {
    public var lane: AxisLane {
        switch role {
        case .instance:
            return .variation
        case .designRecordOnly:
            return .registration
        case .statOnly, .parametric:
            return hasFvarScale ? .pinned : .registration
        }
    }

    /// Coordinate pinned into every generated instance for non-grid axes; nil when not pinned.
    public var pinCoordinate: Double? {
        AxisPinPolicy.pinCoordinate(for: self)
    }

    /// Axis Tree Pin control: hidden for pure STAT naming axes, kept for fvar-backed ones
    /// (e.g. pinned `ital` at −12) so registration can be demoted back to instance/pinned.
    public var showsPinToggle: Bool {
        if isDesignRecordOnly { return hasFvarScale }
        return true
    }

    /// Leave `design_record_only` via Pin / instance-grid controls when an fvar scale remains.
    public var canDemoteFromRegistration: Bool {
        isDesignRecordOnly && hasFvarScale
    }

    /// Roles Pin may move a demotable registration axis into.
    public func canAcceptRoleAfterRegistrationDemote(_ role: AxisRole) -> Bool {
        canDemoteFromRegistration && (role == .instance || role == .statOnly)
    }
}
