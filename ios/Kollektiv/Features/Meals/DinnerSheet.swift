import SwiftUI

struct DinnerSheet: View {
    @Environment(HouseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let date: LocalDate
    @State private var dishDraft = ""
    @State private var errorText: String?

    private var dinner: Dinner? { store.dinner(on: date) }
    private var split: AttendanceSplit { store.attendanceSplit(on: date) }
    private var me: Member { store.currentMember }
    private var myStatus: Attendance { store.attendance(on: date)[me.id] ?? .unknown }
    private var cookName: String? { dinner?.cookID.flatMap { store.member($0)?.displayName } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(date == store.today ? "Dinner tonight" : "Dinner \(date.longLabel)")
                        .font(Theme.heading(36)).foregroundStyle(.white)
                    Image("meals").resizable().scaledToFit().frame(height: 160).frame(maxWidth: .infinity)
                    VStack(spacing: 4) {
                        Text(dinner?.dish ?? "Not planned").font(Theme.title(26)).foregroundStyle(.white)
                        Text(cookLine).font(Theme.body).foregroundStyle(.white.opacity(0.85))
                    }.frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Are you eating, \(me.displayName)?").font(Theme.title())
                        HStack(spacing: 10) {
                            choice("Eating", .eating, Theme.cobalt)
                            choice("Away", .away, Theme.coral)
                        }
                        attendanceRow("Eating", split.eating)
                        attendanceRow("Away", split.away)
                        attendanceRow("Not answered", split.unknown)

                        Divider()
                        if dinner?.cookID == nil {
                            Text("No one is cooking yet").font(Theme.body)
                            TextField("What will you cook?", text: $dishDraft).textFieldStyle(.roundedBorder)
                            PrimaryButton(title: "I'll cook", systemImage: "frying.pan") {
                                do {
                                    try store.volunteerToCook(actor: me.id, date: date, dish: dishDraft.isEmpty ? "Something tasty" : dishDraft, time: nil)
                                    errorText = nil
                                } catch { errorText = error.localizedDescription }
                            }
                        } else if dinner?.cookID == me.id {
                            Label("You're cooking", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.teal).font(Theme.body.bold())
                        }
                        if let errorText { Text(errorText).font(Theme.caption).foregroundStyle(Theme.coral) }
                    }
                    .padding(20)
                    .background(Theme.cream, in: RoundedRectangle(cornerRadius: 24))
                }
                .padding(20)
            }
            .background(Theme.cobalt.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(.white) }
            }
        }
    }

    private var cookLine: String {
        if let cookName { return cookName == me.displayName ? "You're cooking" + (dinner?.time.map { " · \($0)" } ?? "") : "\(cookName) is cooking" + (dinner?.time.map { " · \($0)" } ?? "") }
        return "No cook yet"
    }

    private func choice(_ title: String, _ status: Attendance, _ color: Color) -> some View {
        Button {
            do { try store.setAttendance(actor: me.id, dates: [date], status: status); errorText = nil }
            catch { errorText = error.localizedDescription }
        } label: {
            Text(title).font(.system(.headline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(myStatus == status ? color : color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(myStatus == status ? .white : color)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(myStatus == status ? .isSelected : [])
    }

    private func attendanceRow(_ label: String, _ members: [Member]) -> some View {
        HStack {
            Text(label).font(Theme.body.bold()).frame(width: 110, alignment: .leading)
            if members.isEmpty { Text("—").foregroundStyle(.secondary) }
            ForEach(members) { MemberAvatar(member: $0, size: 28) }
            Spacer()
            Text("\(members.count)").font(Theme.body).foregroundStyle(.secondary)
        }
    }
}
