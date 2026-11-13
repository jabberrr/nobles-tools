import CloudKit
import NoblesKit

/// Every student's longest cafe streak, shared through CloudKit's public database so a recap can
/// say where its streak stands. A record holds only a semester and a length: one per iCloud user
/// per semester, named after the two, so saving again overwrites it.
///
/// Reading needs no iCloud account; saving does, and without one the streak is compared but not
/// shared. Anything going wrong (no network, or the schema not deployed yet) just means no standing.
enum StreakBoard {
    private static let containerIdentifier = "iCloud.app.dabora.noblestools"
    private static let recordType: CKRecord.RecordType = "SemesterStreak"
    /// Records read at most, should the public database ever fill with junk.
    private static let recordLimit = 2_000

    private enum Field {
        /// The recap's period name, "Fall 2026".
        static let semester: CKRecord.FieldKey = "semester"
        /// Purchase days in a row, as an `Int64`.
        static let length: CKRecord.FieldKey = "length"
    }

    /// Shares a streak of `length` days in `semester` (the recap's period name, "Fall 2026") as this
    /// iCloud user's, then says where it stands among the other students' that semester. `nil` when
    /// it shouldn't show (see `StreakStanding.init(length:among:)`) or CloudKit can't be reached.
    static func standing(of length: Int, in semester: String) async -> StreakStanding? {
        let container = CKContainer(identifier: containerIdentifier)
        let database = container.publicCloudDatabase
        let ownRecordID = await recordID(in: semester, for: container)
        if let ownRecordID {
            let record = CKRecord(recordType: recordType, recordID: ownRecordID)
            record[Field.semester] = semester
            record[Field.length] = Int64(length)
            // A failed save still leaves the others to compare with.
            _ = try? await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        }
        guard let others = try? await lengths(in: semester, excluding: ownRecordID, from: database) else { return nil }
        return StreakStanding(length: length, among: others)
    }

    /// This iCloud user's record for `semester`; `nil` without an iCloud account.
    private static func recordID(in semester: String, for container: CKContainer) async -> CKRecord.ID? {
        guard let user = try? await container.userRecordID() else { return nil }
        let semesterName = semester.replacingOccurrences(of: " ", with: "-")
        return CKRecord.ID(recordName: "\(semesterName)-\(user.recordName)")
    }

    /// The lengths of every record for `semester` but `ownRecordID`, page by page.
    private static func lengths(
        in semester: String, excluding ownRecordID: CKRecord.ID?, from database: CKDatabase
    ) async throws -> [Int] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "%K == %@", Field.semester, semester))
        var page = try await database.records(matching: query, desiredKeys: [Field.length])
        var lengths: [Int] = []
        while true {
            lengths += page.matchResults.compactMap { id, result in
                guard id != ownRecordID, let length = (try? result.get())?[Field.length] as? Int64 else { return nil }
                return Int(length)
            }
            guard let cursor = page.queryCursor, lengths.count < recordLimit else { return lengths }
            page = try await database.records(continuingMatchFrom: cursor, desiredKeys: [Field.length])
        }
    }
}
