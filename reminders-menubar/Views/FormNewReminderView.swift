import SwiftUI
import EventKit

struct FormNewReminderView: View {
    @EnvironmentObject var remindersData: RemindersData
    @ObservedObject var userPreferences = UserPreferences.shared
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    @State var rmbReminder = RmbReminder()
    @State var isShowingDueDateOptions = false
    
    var body: some View {
        Form {
            HStack(alignment: .top) {
                newReminderTextFieldView()
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .padding(.leading, 22)
                .background(Color.rmbColor(for: .textFieldBackground, and: colorSchemeContrast))
                .cornerRadius(8)
                .textFieldStyle(PlainTextFieldStyle())
                .modifier(ContrastBorderOverlay())
                .overlay(
                    Image(systemName: "plus.circle.fill")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .foregroundColor(.gray)
                        .padding([.top, .leading], 8)
                )
                
                Menu {
                    ForEach(remindersData.calendars, id: \.calendarIdentifier) { calendar in
                        Button(action: { remindersData.calendarForSaving = calendar }) {
                            let isSelected =
                                remindersData.calendarForSaving?.calendarIdentifier == calendar.calendarIdentifier
                            SelectableView(title: calendar.title, isSelected: isSelected, color: Color(calendar.color))
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        userPreferences.autoSuggestToday.toggle()
                        if rmbReminder.title.isEmpty {
                            rmbReminder = newRmbReminder()
                        }
                    }) {
                        let isSelected = userPreferences.autoSuggestToday
                        SelectableView(title: rmbLocalized(.newReminderAutoSuggestTodayOption),
                                       isSelected: isSelected)
                    }
                    
                    Button(action: { userPreferences.removeParsedDateFromTitle.toggle() }) {
                        let isSelected = userPreferences.removeParsedDateFromTitle
                        SelectableView(title: rmbLocalized(.newReminderRemoveParsedDateOption),
                                       isSelected: isSelected)
                    }
                } label: {
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .frame(width: 14, height: 16)
                .padding(8)
                .padding(.trailing, 2)
                .background(Color(remindersData.calendarForSaving?.color ?? .white))
                .cornerRadius(8)
                .modifier(ContrastBorderOverlay())
                .help(rmbLocalized(.newReminderCalendarSelectionToSaveHelp))
            }
        }
        .padding(10)
        .onChange(of: rmbReminder.title) { [oldValue = rmbReminder.title] newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                isShowingDueDateOptions = !newValue.isEmpty
            }

            // NOTE: When the first character is typed we re-instantiate RmbReminder to ensure the date is as expected.
            if oldValue.isEmpty && newValue.count == 1 {
                rmbReminder = newRmbReminder(withTitle: newValue)
            }
        }
        .onAppear {
            rmbReminder = newRmbReminder()
        }
    }
    
    @ViewBuilder
    func newReminderTextFieldView() -> some View {
        VStack(alignment: .leading) {
            RmbHighlightedTextField(placeholder: rmbLocalized(.newReminderTextFielPlaceholder),
                                    text: $rmbReminder.title,
                                    highlightedTextRange: rmbReminder.textDateResult.range,
                                    onSubmit: createNewReminder)
            .modifier(FocusOnReceive(userPreferences.$remindersMenuBarOpeningEvent))

            if isShowingDueDateOptions {
                reminderDueDateOptionsView(date: $rmbReminder.date,
                                           hasDueDate: $rmbReminder.hasDueDate,
                                           hasTime: $rmbReminder.hasTime)
            }
        }
    }
    
    func newRmbReminder(withTitle title: String = "") -> RmbReminder {
        var rmbReminder = RmbReminder(hasDueDate: userPreferences.autoSuggestToday)
        rmbReminder.title = title
        return rmbReminder
    }
    
    func createNewReminder() {
        guard !rmbReminder.title.trimmingCharacters(in: .whitespaces).isEmpty,
              let calendarForSaving = remindersData.calendarForSaving else {
            return
        }
        
        rmbReminder.prepareToSave()
        if userPreferences.removeParsedDateFromTitle {
            rmbReminder.title = rmbReminder.title.replacingOccurrences(of: rmbReminder.textDateResult.string, with: "")
        }
        
        RemindersService.shared.createNew(with: rmbReminder, in: calendarForSaving)
        rmbReminder = newRmbReminder()
    }
}

@ViewBuilder
func reminderDueDateOptionsView(date: Binding<Date>, hasDueDate: Binding<Bool>, hasTime: Binding<Bool>) -> some View {
    HStack {
        reminderRemindDateTimeOptionView(date: date, components: .date, hasComponent: hasDueDate)
            .modifier(RemindDateTimeCapsuleStyle())
        if hasDueDate.wrappedValue {
            reminderRemindDateTimeOptionView(date: date, components: .time, hasComponent: hasTime)
                .modifier(RemindDateTimeCapsuleStyle())
        }
    }
}

@ViewBuilder
func reminderRemindDateTimeOptionView(date: Binding<Date>,
                                      components: RmbDatePicker.DatePickerComponents,
                                      hasComponent: Binding<Bool>) -> some View {
    let pickerIcon = components == .time ? "clock" : "calendar"
    
    let addTimeButtonText = rmbLocalized(.newReminderAddTimeButton)
    let addDateButtonText = rmbLocalized(.newReminderAddDateButton)
    let pickerAddComponentText = components == .time ? addTimeButtonText : addDateButtonText
    
    if hasComponent.wrappedValue {
        HStack {
            Image(systemName: pickerIcon)
                .font(.system(size: 12))
            RmbDatePicker(selection: date, components: components)
                .font(.systemFont(ofSize: 12, weight: .light))
                .fixedSize(horizontal: true, vertical: true)
                .padding(.top, 2)
            Button {
                hasComponent.wrappedValue = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .frame(width: 5, height: 5, alignment: .center)
        }
    } else {
        Button {
            hasComponent.wrappedValue = true
        } label: {
            Label(pickerAddComponentText, systemImage: pickerIcon)
                .font(.system(size: 12))
        }
        .buttonStyle(.borderless)
    }
}

struct ContrastBorderOverlay: ViewModifier {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    private var isEnabled: Bool { colorSchemeContrast == .increased }
    
    func body(content: Content) -> some View {
        return content
            .overlay(
                isEnabled
                ? RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1))
                    .foregroundColor(Color.rmbColor(for: .borderContrast, and: colorSchemeContrast))
                : nil
            )
    }
}

struct RemindDateTimeCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        return content
            .frame(height: 20)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.2))
            .clipShape(Capsule())
    }
}

struct FormNewReminderView_Previews: PreviewProvider {
    static var reminder: EKReminder {
        let calendar = EKCalendar(for: .reminder, eventStore: .init())
        calendar.color = .systemTeal
        
        let reminder = EKReminder(eventStore: .init())
        reminder.title = "Look for awesome projects on GitHub"
        reminder.isCompleted = false
        reminder.calendar = calendar
        
        let dateComponents = Date().dateComponents(withTime: true)
        reminder.dueDateComponents = dateComponents
        
        return reminder
    }
    
    static var previews: some View {
        Group {
            ForEach(ColorScheme.allCases, id: \.self) { color in
                FormNewReminderView(rmbReminder: RmbReminder(reminder: reminder), isShowingDueDateOptions: true)
                    .environmentObject(RemindersData())
                    .colorScheme(color)
                    .previewDisplayName("\(color) mode")
            }
        }
    }
}
